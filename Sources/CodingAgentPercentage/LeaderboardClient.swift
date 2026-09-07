import Foundation

struct LeaderboardEntry: Equatable, Sendable {
    let handle: String
    let value: Double
    /// ISO 3166-1 Alpha-2 code Cloudflare derived from the submitter's IP; nil when unavailable.
    let country: String?
}

struct LeaderboardStandings: Equatable, Sendable {
    let weekId: String
    let maxPlan: [LeaderboardEntry]
    let reverseVcFunding: [LeaderboardEntry]
}

enum LeaderboardError: LocalizedError, Equatable {
    case invalidResponse
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The leaderboard sent back an unexpected response."
        case .requestFailed: "Could not reach the leaderboard. Check your connection and try again."
        }
    }
}

/// Talks to the vc-funding-leaderboard Cloudflare Worker (see leaderboard/ in this repo). Sharing is
/// entirely opt-in and voluntary: nothing is sent unless the user explicitly enables it and taps share.
struct LeaderboardClient: Sendable {
    static let defaultBaseURL = URL(string: "https://vc-funding-leaderboard.amat-francois.workers.dev")!

    private let baseURL: URL
    private let httpClient: any CopilotHTTPClient

    init(baseURL: URL = LeaderboardClient.defaultBaseURL, httpClient: any CopilotHTTPClient = URLSession.shared) {
        self.baseURL = baseURL
        self.httpClient = httpClient
    }

    func submit(handle: String, maxedCounts: [String: Int], costsUSD: [String: Double]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("submit"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "handle": handle,
            "maxedCounts": maxedCounts,
            "costsUSD": costsUSD
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        guard let (_, response) = try? await httpClient.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LeaderboardError.requestFailed
        }
    }

    func fetchStandings() async throws -> LeaderboardStandings {
        let request = URLRequest(url: baseURL.appendingPathComponent("leaderboard"))
        guard let (data, response) = try? await httpClient.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LeaderboardError.requestFailed
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let weekId = root["weekId"] as? String,
              let maxPlanRaw = root["maxPlan"] as? [[String: Any]],
              let reverseVcRaw = root["reverseVcFunding"] as? [[String: Any]] else {
            throw LeaderboardError.invalidResponse
        }
        let maxPlan = maxPlanRaw.compactMap { entry -> LeaderboardEntry? in
            guard let handle = entry["handle"] as? String, let total = entry["total"] as? Double else { return nil }
            return LeaderboardEntry(handle: handle, value: total, country: entry["country"] as? String)
        }
        let reverseVc = reverseVcRaw.compactMap { entry -> LeaderboardEntry? in
            guard let handle = entry["handle"] as? String, let totalUsd = entry["totalUsd"] as? Double else { return nil }
            return LeaderboardEntry(handle: handle, value: totalUsd, country: entry["country"] as? String)
        }
        return LeaderboardStandings(weekId: weekId, maxPlan: maxPlan, reverseVcFunding: reverseVc)
    }
}
