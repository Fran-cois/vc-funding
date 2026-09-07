import Foundation
import Testing
@testable import CodingAgentPercentage

private struct FixedCopilotHTTPClient: CopilotHTTPClient {
    let statusCode: Int
    let body: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (body, response)
    }
}

private actor CallLog {
    private(set) var authorizationHeaders: [String] = []

    func record(_ header: String) {
        authorizationHeaders.append(header)
    }
}

private struct PerTokenCopilotHTTPClient: CopilotHTTPClient {
    let statusCodes: [String: Int]
    let body: Data
    let log: CallLog

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let header = request.value(forHTTPHeaderField: "Authorization") ?? ""
        await log.record(header)
        let statusCode = statusCodes[header] ?? 404
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (statusCode == 200 ? body : Data(), response)
    }
}

struct GitHubCopilotUsageProviderTests {
    @Test func requiresOptInBeforeReadingAnythingLocal() async {
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { false },
            tokenCandidates: { Issue.record("tokens should not be read when opted out"); return [] },
            httpClient: FixedCopilotHTTPClient(statusCode: 200, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected an opt-in error")
        } catch let error as UsageProviderError {
            #expect(error == .networkOptInRequired(CodingAgent.githubCopilot.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func reportsMissingLocalCredentialsWhenOptedIn() async {
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { [] },
            httpClient: FixedCopilotHTTPClient(statusCode: 200, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected a missing credentials error")
        } catch let error as UsageProviderError {
            #expect(error == .credentialsNotFound(CodingAgent.githubCopilot.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func parsesPremiumInteractionsQuotaIntoTheWeeklyWindow() async throws {
        let json = #"""
        {
            "quota_reset_date": "2030-02-01",
            "quota_snapshots": {
                "premium_interactions": {
                    "unlimited": false,
                    "percent_remaining": 35.5
                }
            }
        }
        """#
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { ["gho_faketoken"] },
            httpClient: FixedCopilotHTTPClient(statusCode: 200, body: Data(json.utf8))
        )

        let snapshot = try await provider.fetchUsage()

        #expect(snapshot.agentName == CodingAgent.githubCopilot.rawValue)
        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.weekly?.roundedPercent == 65)
    }

    @Test func showsCreditsUsedWhenThePlanIsUnlimited() async throws {
        let json = #"""
        {
            "quota_reset_date": "2030-02-01",
            "quota_snapshots": {
                "premium_interactions": { "unlimited": true, "credits_used": 222157 },
                "chat": { "unlimited": true }
            }
        }
        """#
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { ["gho_faketoken"] },
            httpClient: FixedCopilotHTTPClient(statusCode: 200, body: Data(json.utf8))
        )

        let snapshot = try await provider.fetchUsage()

        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.weekly == nil)
        #expect(snapshot.creditsUsed == 222_157)
    }

    @Test func reportsUnlimitedQuotaWhenNoCreditsFigureIsAvailableEither() async {
        let json = #"""
        {
            "quota_reset_date": "2030-02-01",
            "quota_snapshots": {
                "premium_interactions": { "unlimited": true },
                "chat": { "unlimited": true }
            }
        }
        """#
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { ["gho_faketoken"] },
            httpClient: FixedCopilotHTTPClient(statusCode: 200, body: Data(json.utf8))
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected an unlimitedQuota error")
        } catch let error as UsageProviderError {
            #expect(error == .unlimitedQuota(CodingAgent.githubCopilot.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func fallsBackToTheNextTokenWhenTheFirstIsRejected() async throws {
        let json = #"""
        {
            "quota_reset_date": "2030-02-01",
            "quota_snapshots": { "premium_interactions": { "unlimited": false, "percent_remaining": 90 } }
        }
        """#
        let log = CallLog()
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { ["stale-value", "fresh-value"] },
            httpClient: PerTokenCopilotHTTPClient(
                statusCodes: ["token stale-value": 401, "token fresh-value": 200],
                body: Data(json.utf8),
                log: log
            )
        )

        let snapshot = try await provider.fetchUsage()

        #expect(snapshot.weekly?.roundedPercent == 10)
        let headers = await log.authorizationHeaders
        #expect(headers == ["token stale-value", "token fresh-value"])
    }

    @Test func reportsRejectedCredentialsWhenEveryTokenFailsAuth() async {
        let log = CallLog()
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { ["value-a", "value-b"] },
            httpClient: PerTokenCopilotHTTPClient(
                statusCodes: ["token value-a": 401, "token value-b": 403],
                body: Data(),
                log: log
            )
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected a credentialsRejected error")
        } catch let error as UsageProviderError {
            #expect(error == .credentialsRejected(CodingAgent.githubCopilot.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func reportsFailedRequestsOnNonAuthErrorStatusCodes() async {
        let provider = GitHubCopilotUsageProvider(
            isNetworkUsageEnabled: { true },
            tokenCandidates: { ["gho_faketoken"] },
            httpClient: FixedCopilotHTTPClient(statusCode: 500, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected a network failure error")
        } catch let error as UsageProviderError {
            #expect(error == .networkRequestFailed(CodingAgent.githubCopilot.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

