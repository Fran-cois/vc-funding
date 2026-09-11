import Foundation

/// Primary Codex usage source: reads live account rate limits via the `codex` CLI's app-server RPC,
/// falling back to local session-log parsing only if the CLI is unavailable or the call fails.
struct CodexCLIUsageProvider: AgentUsageProvider {
    let agentName = CodingAgent.codex.rawValue

    private let isOfflineModeEnabled: @Sendable () -> Bool
    private let fetchRateLimitsResult: @Sendable () async throws -> [String: Any]
    private let fallback: any AgentUsageProvider

    init(
        isOfflineModeEnabled: @escaping @Sendable () -> Bool = {
            UserDefaults.standard.bool(forKey: CodexOfflineModeSettings.enabledKey)
        },
        fetchRateLimitsResult: @escaping @Sendable () async throws -> [String: Any] = {
            try await CodexAppServerClient.fetchRateLimitsResult()
        },
        fallback: any AgentUsageProvider = CodexUsageProvider()
    ) {
        self.isOfflineModeEnabled = isOfflineModeEnabled
        self.fetchRateLimitsResult = fetchRateLimitsResult
        self.fallback = fallback
    }

    func fetchUsage() async throws -> UsageSnapshot {
        if !isOfflineModeEnabled(),
           let result = try? await fetchRateLimitsResult(),
           let snapshot = CodexAppServerUsageParser.snapshot(fromResult: result, agentName: agentName) {
            return snapshot
        }
        return try await fallback.fetchUsage()
    }
}
