import Foundation

/// Opt-in provider reading a user-supplied OpenRouter API key, gated by `OpenRouterSettings`.
struct OpenRouterUsageProvider: AgentUsageProvider {
    let agentName = CodingAgent.openRouter.rawValue

    private let isNetworkUsageEnabled: @Sendable () -> Bool
    private let apiKey: @Sendable () -> String?
    private let httpClient: any CopilotHTTPClient

    init(
        isNetworkUsageEnabled: @escaping @Sendable () -> Bool = {
            UserDefaults.standard.bool(forKey: OpenRouterSettings.enabledKey)
        },
        apiKey: @escaping @Sendable () -> String? = { OpenRouterSettings.readAPIKey() },
        httpClient: any CopilotHTTPClient = URLSession.shared
    ) {
        self.isNetworkUsageEnabled = isNetworkUsageEnabled
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard isNetworkUsageEnabled() else {
            throw UsageProviderError.networkOptInRequired(agentName)
        }
        guard let key = apiKey(), !key.isEmpty else {
            throw UsageProviderError.credentialsNotFound(agentName)
        }

        var request = URLRequest(url: Self.keyEndpoint)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("vc-funding", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await httpClient.data(for: request),
              let httpResponse = response as? HTTPURLResponse else {
            throw UsageProviderError.networkRequestFailed(agentName)
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw UsageProviderError.credentialsRejected(agentName)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UsageProviderError.networkRequestFailed(agentName)
        }
        guard let snapshot = Self.snapshot(from: data, agentName: agentName) else {
            throw UsageProviderError.noUsageData
        }
        return snapshot
    }

    static let keyEndpoint = URL(string: "https://openrouter.ai/api/v1/key")!

    static func snapshot(from data: Data, agentName: String, now: Date = Date()) -> UsageSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              // OpenRouter credits are already USD-denominated (1 credit = $1); usage_weekly is the
              // current UTC week (Monday-start), matching this app's weekly framing with no guesswork.
              let weeklyUsage = payload["usage_weekly"] as? Double else { return nil }
        return UsageSnapshot(agentName: agentName, fiveHour: nil, weekly: nil, refreshedAt: now, sourceUpdatedAt: now, costUSD: weeklyUsage)
    }
}
