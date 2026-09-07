import Foundation

/// The only provider that opts into reading local credentials and calling the network, gated by `CopilotNetworkUsageSettings`.
struct GitHubCopilotUsageProvider: AgentUsageProvider {
    let agentName = CodingAgent.githubCopilot.rawValue

    private let isNetworkUsageEnabled: @Sendable () -> Bool
    private let tokenCandidates: @Sendable () -> [String]
    private let httpClient: any CopilotHTTPClient

    init(
        isNetworkUsageEnabled: @escaping @Sendable () -> Bool = {
            UserDefaults.standard.bool(forKey: CopilotNetworkUsageSettings.enabledKey)
        },
        tokenCandidates: @escaping @Sendable () -> [String] = { GitHubCopilotUsageProvider.candidateOAuthTokens() },
        httpClient: any CopilotHTTPClient = URLSession.shared
    ) {
        self.isNetworkUsageEnabled = isNetworkUsageEnabled
        self.tokenCandidates = tokenCandidates
        self.httpClient = httpClient
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard isNetworkUsageEnabled() else {
            throw UsageProviderError.networkOptInRequired(agentName)
        }
        let tokens = tokenCandidates()
        guard !tokens.isEmpty else {
            throw UsageProviderError.credentialsNotFound(agentName)
        }

        var sawAuthFailure = false
        for token in tokens {
            var request = URLRequest(url: Self.quotaEndpoint)
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("vc-funding", forHTTPHeaderField: "User-Agent")

            guard let (data, response) = try? await httpClient.data(for: request),
                  let httpResponse = response as? HTTPURLResponse else { continue }

            if (200..<300).contains(httpResponse.statusCode) {
                if let snapshot = Self.snapshot(from: data, agentName: agentName) {
                    return snapshot
                }
                throw Self.hasOnlyUnlimitedQuotas(data)
                    ? UsageProviderError.unlimitedQuota(agentName)
                    : UsageProviderError.noUsageData
            }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                sawAuthFailure = true
            }
        }
        throw sawAuthFailure
            ? UsageProviderError.credentialsRejected(agentName)
            : UsageProviderError.networkRequestFailed(agentName)
    }

    static let quotaEndpoint = URL(string: "https://api.github.com/copilot_internal/user")!

    /// Tries the `gh` CLI's own managed token first (proven to stay valid), then falls back to the
    /// long-lived tokens editor extensions store locally, which can go stale without being removed.
    static func candidateOAuthTokens(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [String] {
        var tokens: [String] = []
        if let ghToken = readGhCliToken() { tokens.append(ghToken) }

        let configDirectory = homeDirectory.appendingPathComponent(".config/github-copilot", isDirectory: true)
        for fileName in ["hosts.json", "apps.json"] {
            guard let data = try? Data(contentsOf: configDirectory.appendingPathComponent(fileName)),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            for key in root.keys.sorted() where key.hasPrefix("github.com") {
                guard let entry = root[key] as? [String: Any] else { continue }
                if let token = entry["oauth_token"] as? String {
                    tokens.append(token)
                } else if let token = entry["oauthToken"] as? String {
                    tokens.append(token)
                }
            }
        }

        var seen = Set<String>()
        return tokens.filter { seen.insert($0).inserted }
    }

    private static func readGhCliToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return token?.isEmpty == false ? token : nil
        } catch {
            return nil
        }
    }

    static func snapshot(from data: Data, agentName: String, now: Date = Date()) -> UsageSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotaSnapshots = root["quota_snapshots"] as? [String: Any] else { return nil }

        let relevantEntries = ["premium_interactions", "chat"].compactMap { quotaSnapshots[$0] as? [String: Any] }

        let resetsAt = (root["quota_reset_date"] as? String).flatMap(parseResetDate)
            ?? now.addingTimeInterval(30 * 24 * 3_600)
        let windowMinutes = max(1, Int(resetsAt.timeIntervalSince(now) / 60))

        if let window = relevantEntries.compactMap({ entry -> UsageWindow? in
            guard entry["unlimited"] as? Bool != true,
                  let percentRemaining = entry["percent_remaining"] as? Double else { return nil }
            let usedPercent = min(100, max(0, 100 - percentRemaining))
            return UsageWindow(usedPercent: usedPercent, windowMinutes: windowMinutes, resetsAt: resetsAt)
        }).first {
            return UsageSnapshot(agentName: agentName, fiveHour: nil, weekly: window, refreshedAt: now, sourceUpdatedAt: now)
        }

        // Unlimited plans have no cap to compute a percentage against; fall back to the raw credit count.
        if let credits = relevantEntries.compactMap(creditsUsed).first {
            return UsageSnapshot(
                agentName: agentName,
                fiveHour: nil,
                weekly: nil,
                refreshedAt: now,
                sourceUpdatedAt: now,
                creditsUsed: credits,
                // 1 GitHub AI credit = $0.01 USD, per GitHub's billing docs.
                costUSD: Double(credits) * 0.01
            )
        }

        return nil
    }

    private static func creditsUsed(in entry: [String: Any]) -> Int? {
        if let value = entry["credits_used"] as? Int { return value }
        if let value = entry["credits_used"] as? Double { return Int(value) }
        return nil
    }

    private static func hasOnlyUnlimitedQuotas(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotaSnapshots = root["quota_snapshots"] as? [String: Any] else { return false }
        let relevant = ["premium_interactions", "chat"].compactMap { quotaSnapshots[$0] as? [String: Any] }
        guard !relevant.isEmpty else { return false }
        return relevant.allSatisfy { ($0["unlimited"] as? Bool) == true }
    }

    private static func parseResetDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)
    }
}

protocol CopilotHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: CopilotHTTPClient {}

