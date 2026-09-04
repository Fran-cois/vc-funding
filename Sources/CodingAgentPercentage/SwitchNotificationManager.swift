import Foundation
import UserNotifications

protocol SwitchAlertNotifier: Sendable {
    func notifyIfNeeded(snapshot: UsageSnapshot) async
}

struct SwitchAlertCandidate: Equatable, Sendable {
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
        guard let urgent = Self.candidate(for: snapshot) else { return }

        let resetID = Int(urgent.window.resetsAt.timeIntervalSince1970)
        let notificationID = "\(snapshot.agentName)-\(urgent.label)-\(resetID)"
        var notified = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
        guard !notified.contains(notificationID) else { return }

        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to switch coding agent"
        content.body = "\(snapshot.agentName) \(urgent.label) usage reached \(urgent.window.roundedPercent)%."
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
}
