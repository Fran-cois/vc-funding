import Foundation
import Testing
@testable import CodingAgentPercentage

private actor RequestLog {
    private(set) var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }
}

private struct RecordingHTTPClient: CopilotHTTPClient {
    let statusCode: Int
    let body: Data
    let log: RequestLog

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        await log.record(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (body, response)
    }
}

struct LeaderboardClientTests {
    @Test func submitPostsHandleAndTotals() async throws {
        let log = RequestLog()
        let client = LeaderboardClient(
            baseURL: URL(string: "https://example.com")!,
            httpClient: RecordingHTTPClient(statusCode: 200, body: Data("{}".utf8), log: log)
        )

        try await client.submit(
            handle: "francois",
            maxedCounts: ["Codex": 2],
            costsUSD: ["GitHub Copilot": 19.5]
        )

        let requests = await log.requests
        #expect(requests.count == 1)
        #expect(requests[0].url?.path == "/submit")
        #expect(requests[0].httpMethod == "POST")
        let body = try #require(requests[0].httpBody)
        let decoded = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(decoded["handle"] as? String == "francois")
    }

    @Test func fetchStandingsParsesBothPrizeCategories() async throws {
        let json = #"""
        {
            "weekId": "2026-W37",
            "maxPlan": [{"handle": "francois", "total": 4, "breakdown": {}, "country": "FR"}],
            "reverseVcFunding": [{"handle": "francois", "totalUsd": 19.5, "breakdown": {}, "country": "FR"}]
        }
        """#
        let log = RequestLog()
        let client = LeaderboardClient(
            baseURL: URL(string: "https://example.com")!,
            httpClient: RecordingHTTPClient(statusCode: 200, body: Data(json.utf8), log: log)
        )

        let standings = try await client.fetchStandings()

        #expect(standings.weekId == "2026-W37")
        #expect(standings.maxPlan == [LeaderboardEntry(handle: "francois", value: 4, country: "FR")])
        #expect(standings.reverseVcFunding == [LeaderboardEntry(handle: "francois", value: 19.5, country: "FR")])
    }

    @Test func fetchStandingsThrowsOnServerError() async {
        let log = RequestLog()
        let client = LeaderboardClient(
            baseURL: URL(string: "https://example.com")!,
            httpClient: RecordingHTTPClient(statusCode: 500, body: Data(), log: log)
        )

        do {
            _ = try await client.fetchStandings()
            Issue.record("Expected a requestFailed error")
        } catch let error as LeaderboardError {
            #expect(error == .requestFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
