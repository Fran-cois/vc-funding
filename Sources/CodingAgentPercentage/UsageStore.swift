import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [String: UsageSnapshot] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var availableAgents: [CodingAgent]

    private let providers: [any AgentUsageProvider]
    private let notifier: (any SwitchAlertNotifier)?
    private let detectAgents: @Sendable () -> [CodingAgent]
    private let maxedCycleTracker: MaxedCycleTracker?

    init(
        providers: [any AgentUsageProvider],
        notifier: (any SwitchAlertNotifier)? = nil,
        detectAgents: (@Sendable () -> [CodingAgent])? = nil,
        maxedCycleTracker: MaxedCycleTracker? = nil
    ) {
        self.providers = providers
        self.notifier = notifier
        let providerAgents = providers.compactMap { CodingAgent(rawValue: $0.agentName) }
        self.detectAgents = detectAgents ?? { providerAgents }
        self.maxedCycleTracker = maxedCycleTracker
        self.availableAgents = []
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

    var shouldBurnTokens: Bool {
        snapshot(for: .codex).flatMap { SwitchNotificationManager.burnCandidate(for: $0) } != nil
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

    func burnReason(for agent: CodingAgent, now: Date = Date()) -> String? {
        guard let snapshot = snapshot(for: agent),
              let candidate = SwitchNotificationManager.burnCandidate(for: snapshot, now: now) else { return nil }
        let remaining = max(0, 100 - candidate.window.roundedPercent)
        return "Time to burn tokens: \(remaining)% remains in the \(candidate.label) window before reset."
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let detectedAgents = detectAgents()
        let detectedNames = Set(detectedAgents.map(\.rawValue))
        snapshots = snapshots.filter { detectedNames.contains($0.key) }
        errors = errors.filter { detectedNames.contains($0.key) }
        var agentsWithUsage: [CodingAgent] = []

        for provider in providers where detectedNames.contains(provider.agentName) {
            do {
                let snapshot = try await provider.fetchUsage()
                snapshots[provider.agentName] = snapshot
                errors[provider.agentName] = nil
                maxedCycleTracker?.recordObservation(agent: provider.agentName, window: snapshot.fiveHour)
                maxedCycleTracker?.recordObservation(agent: provider.agentName, window: snapshot.weekly)
                if let agent = CodingAgent(rawValue: provider.agentName),
                   snapshot.fiveHour != nil || snapshot.weekly != nil || snapshot.creditsUsed != nil || snapshot.costUSD != nil {
                    agentsWithUsage.append(agent)
                }
                await notifier?.notifyIfNeeded(snapshot: snapshot)
            } catch {
                snapshots[provider.agentName] = nil
                errors[provider.agentName] = error.localizedDescription
            }
        }
        availableAgents = agentsWithUsage
    }

    private func percent(_ window: UsageWindow?) -> String {
        window.map { "\($0.roundedPercent)%" } ?? "N/A"
    }
}
