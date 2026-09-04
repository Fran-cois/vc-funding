import Foundation

enum CodingAgent: String, CaseIterable, Identifiable, Sendable {
    case codex = "Codex"
    case claudeCode = "Claude Code"

    var id: String { rawValue }
}

struct UnavailableAgentUsageProvider: AgentUsageProvider {
    let agentName: String

    func fetchUsage() async throws -> UsageSnapshot {
        throw UsageProviderError.unsupportedAgent(agentName)
    }
}
