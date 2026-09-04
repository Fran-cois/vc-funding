import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [String: UsageSnapshot] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var isRefreshing = false

    private let providers: [any AgentUsageProvider]

    init(providers: [any AgentUsageProvider]) {
        self.providers = providers
    }

    convenience init(provider: any AgentUsageProvider) {
        self.init(providers: [provider])
    }

    var menuBarTitle: String {
        let snapshot = snapshot(for: .codex)
        guard let snapshot else { return "" }
        return [("5h", snapshot.fiveHour), ("7d", snapshot.weekly)]
            .compactMap { label, window in window.map { "\(label) \(percent($0))" } }
            .joined(separator: " · ")
    }

    var shouldSwitch: Bool {
        guard let snapshot = snapshot(for: .codex) else { return false }
        return [snapshot.fiveHour, snapshot.weekly]
            .compactMap { $0?.usedPercent }
            .contains { $0 >= 90 }
    }

    func snapshot(for agent: CodingAgent) -> UsageSnapshot? {
        snapshots[agent.rawValue]
    }

    func errorMessage(for agent: CodingAgent) -> String? {
        errors[agent.rawValue]
    }

    func switchReason(for agent: CodingAgent) -> String? {
        guard let snapshot = snapshot(for: agent) else { return nil }
        let candidates = [("5h", snapshot.fiveHour), ("7d", snapshot.weekly)]
        guard let urgent = candidates
            .compactMap({ label, window in window.map { (label, $0.usedPercent) } })
            .filter({ $0.1 >= 90 })
            .max(by: { $0.1 < $1.1 }) else { return nil }
        return "\(urgent.0) usage is at \(Int(urgent.1.rounded()))%. Consider switching coding agent."
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for provider in providers {
            do {
                let snapshot = try await provider.fetchUsage()
                snapshots[provider.agentName] = snapshot
                errors[provider.agentName] = nil
            } catch {
                errors[provider.agentName] = error.localizedDescription
            }
        }
    }

    private func percent(_ window: UsageWindow?) -> String {
        window.map { "\($0.roundedPercent)%" } ?? "N/A"
    }
}
