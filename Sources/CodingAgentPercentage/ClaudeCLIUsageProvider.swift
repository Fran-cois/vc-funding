import Foundation

/// Reads Claude Code's own local `/usage` computation via the CLI. Unlike Codex, this needs no
/// separate live/offline split: `/usage` is already a zero-cost, fully local command, so there's
/// nothing to fall back to.
struct ClaudeCLIUsageProvider: AgentUsageProvider {
    let agentName = CodingAgent.claudeCode.rawValue

    private let fetchUsageResultText: @Sendable () async throws -> String

    init(
        fetchUsageResultText: @escaping @Sendable () async throws -> String = {
            try await ClaudeCLIClient.fetchUsageResultText()
        }
    ) {
        self.fetchUsageResultText = fetchUsageResultText
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let text = try await fetchUsageResultText()
        guard let snapshot = ClaudeUsageParser.snapshot(fromResultText: text, agentName: agentName) else {
            throw UsageProviderError.commandOutputUnrecognized(agentName)
        }
        return snapshot
    }
}
