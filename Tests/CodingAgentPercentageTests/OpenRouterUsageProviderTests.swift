import Foundation
import Testing
@testable import CodingAgentPercentage

private struct FixedHTTPClient: CopilotHTTPClient {
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

struct OpenRouterUsageProviderTests {
    @Test func requiresOptInBeforeReadingTheAPIKey() async {
        let provider = OpenRouterUsageProvider(
            isNetworkUsageEnabled: { false },
            apiKey: { Issue.record("API key should not be read when opted out"); return nil },
            httpClient: FixedHTTPClient(statusCode: 200, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected an opt-in error")
        } catch let error as UsageProviderError {
            #expect(error == .networkOptInRequired(CodingAgent.openRouter.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func reportsMissingAPIKeyWhenOptedIn() async {
        let provider = OpenRouterUsageProvider(
            isNetworkUsageEnabled: { true },
            apiKey: { nil },
            httpClient: FixedHTTPClient(statusCode: 200, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected a missing credentials error")
        } catch let error as UsageProviderError {
            #expect(error == .credentialsNotFound(CodingAgent.openRouter.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func parsesWeeklyUsageAsCostUSD() async throws {
        let json = #"{"data":{"usage_weekly":12.5}}"#
        let provider = OpenRouterUsageProvider(
            isNetworkUsageEnabled: { true },
            apiKey: { "sk-or-faketoken" },
            httpClient: FixedHTTPClient(statusCode: 200, body: Data(json.utf8))
        )

        let snapshot = try await provider.fetchUsage()

        #expect(snapshot.agentName == CodingAgent.openRouter.rawValue)
        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.weekly == nil)
        #expect(snapshot.costUSD == 12.5)
    }

    @Test func reportsRejectedCredentialsOnAuthFailure() async {
        let provider = OpenRouterUsageProvider(
            isNetworkUsageEnabled: { true },
            apiKey: { "sk-or-badtoken" },
            httpClient: FixedHTTPClient(statusCode: 401, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected a credentialsRejected error")
        } catch let error as UsageProviderError {
            #expect(error == .credentialsRejected(CodingAgent.openRouter.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func reportsFailedRequestsOnOtherErrorStatusCodes() async {
        let provider = OpenRouterUsageProvider(
            isNetworkUsageEnabled: { true },
            apiKey: { "sk-or-faketoken" },
            httpClient: FixedHTTPClient(statusCode: 500, body: Data())
        )

        do {
            _ = try await provider.fetchUsage()
            Issue.record("Expected a network failure error")
        } catch let error as UsageProviderError {
            #expect(error == .networkRequestFailed(CodingAgent.openRouter.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
