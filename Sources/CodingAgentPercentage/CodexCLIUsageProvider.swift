import Foundation

/// Primary Codex usage source: reads live account rate limits via the `codex` CLI's app-server RPC,
/// falling back to local session-log parsing only if the CLI is unavailable or the call fails.
struct CodexCLIUsageProvider: AgentUsageProvider {
    let agentName = CodingAgent.codex.rawValue

    private let isOfflineModeEnabled: @Sendable () -> Bool
    private let fetchRateLimits: @Sendable () async throws -> [String: Any]
    private let fallback: any AgentUsageProvider

    init(
        isOfflineModeEnabled: @escaping @Sendable () -> Bool = {
            UserDefaults.standard.bool(forKey: CodexOfflineModeSettings.enabledKey)
        },
        fetchRateLimits: @escaping @Sendable () async throws -> [String: Any] = {
            try await CodexAppServerClient.fetchRateLimits()
        },
        fallback: any AgentUsageProvider = CodexUsageProvider()
    ) {
        self.isOfflineModeEnabled = isOfflineModeEnabled
        self.fetchRateLimits = fetchRateLimits
        self.fallback = fallback
    }

    func fetchUsage() async throws -> UsageSnapshot {
        if !isOfflineModeEnabled(),
           let rateLimits = try? await fetchRateLimits(),
           let snapshot = CodexAppServerUsageParser.snapshot(fromRateLimits: rateLimits, agentName: agentName) {
            return snapshot
        }
        return try await fallback.fetchUsage()
    }
}
