import Foundation
import UserNotifications

protocol SwitchAlertNotifier: Sendable {
    func notifyIfNeeded(snapshot: UsageSnapshot) async
}

struct SwitchAlertCandidate: Equatable, Sendable {
    let label: String
    let window: UsageWindow
}

struct BurnAlertCandidate: Equatable, Sendable {
    let label: String
    let window: UsageWindow
}

final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

actor SwitchNotificationManager: SwitchAlertNotifier {
    private let center = UNUserNotificationCenter.current()
    private let presentationDelegate = NotificationPresentationDelegate()
    private let defaultsKey = "notifiedSwitchWindows"

    init() {
        center.delegate = presentationDelegate
    }

    func notifyIfNeeded(snapshot: UsageSnapshot) async {
        if let urgent = Self.candidate(for: snapshot) {
            await deliver(
                id: "switch-\(snapshot.agentName)-\(urgent.label)-\(Int(urgent.window.resetsAt.timeIntervalSince1970))",
                title: "Time to switch coding agent",
                body: "\(snapshot.agentName) \(urgent.label) usage reached \(urgent.window.roundedPercent)%."
            )
        } else if let burn = Self.burnCandidate(for: snapshot) {
            let remaining = max(0, 100 - burn.window.roundedPercent)
            await deliver(
                id: "burn-\(snapshot.agentName)-\(burn.label)-\(Int(burn.window.resetsAt.timeIntervalSince1970))",
                title: "Time to burn tokens 🔥",
                body: "\(remaining)% of \(snapshot.agentName)'s \(burn.label) window is still available before reset."
            )
        }
    }

    private func deliver(id notificationID: String, title: String, body: String) async {
        var notified = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
        guard !notified.contains(notificationID) else { return }

        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        do {
            try await center.add(UNNotificationRequest(
                identifier: notificationID,
                content: content,
                trigger: nil
            ))
            notified.insert(notificationID)
            UserDefaults.standard.set(Array(notified.suffix(20)), forKey: defaultsKey)
        } catch {
            // Notifications are best-effort; usage refresh must keep working.
        }
    }

    nonisolated static func candidate(for snapshot: UsageSnapshot) -> SwitchAlertCandidate? {
        [("5h", snapshot.fiveHour), ("7d", snapshot.weekly)]
            .compactMap { label, window in window.map { SwitchAlertCandidate(label: label, window: $0) } }
            .filter { $0.window.usedPercent >= 90 }
            .max { $0.window.usedPercent < $1.window.usedPercent }
    }

    nonisolated static func burnCandidate(
        for snapshot: UsageSnapshot,
        now: Date = Date()
    ) -> BurnAlertCandidate? {
        [("5h", snapshot.fiveHour, 3_600.0), ("7d", snapshot.weekly, 86_400.0)]
            .compactMap { label, window, warningInterval -> BurnAlertCandidate? in
                guard let window,
                      window.usedPercent <= 80,
                      window.resetsAt > now,
                      window.resetsAt.timeIntervalSince(now) <= warningInterval else { return nil }
                return BurnAlertCandidate(label: label, window: window)
            }
            .min { $0.window.resetsAt < $1.window.resetsAt }
    }
}
