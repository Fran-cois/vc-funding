import Foundation
import Testing
@testable import CodingAgentPercentage

struct ClaudeCLIUsageProviderTests {
    @Test func parsesUsageFromTheCLIResult() async throws {
        let provider = ClaudeCLIUsageProvider {
            "Current session: 25% used · resets Sep 24 at 12:29pm (Europe/Paris)\n" +
            "Current week (all models): 6% used · resets Sep 28 at 4:59pm (Europe/Paris)"
        }

        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.fiveHour?.roundedPercent == 25)
        #expect(snapshot.weekly?.roundedPercent == 6)
    }

    @Test func propagatesCLIFailures() async throws {
        let provider = ClaudeCLIUsageProvider {
            throw ClaudeCLIClient.CommunicationError(message: "claude CLI was not found. Make sure it's installed and on PATH.")
        }

        await #expect(throws: ClaudeCLIClient.CommunicationError.self) {
            _ = try await provider.fetchUsage()
        }
    }

    @Test func throwsADescriptiveErrorWhenOutputHasNoRecognizedWindows() async throws {
        let provider = ClaudeCLIUsageProvider { "not usage-shaped output" }

        await #expect(throws: UsageProviderError.commandOutputUnrecognized(CodingAgent.claudeCode.rawValue)) {
            _ = try await provider.fetchUsage()
        }
    }
}
