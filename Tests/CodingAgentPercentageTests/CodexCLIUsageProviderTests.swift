import Foundation
import Testing
@testable import CodingAgentPercentage

private struct StubFallbackProvider: AgentUsageProvider {
    let agentName = CodingAgent.codex.rawValue
    var result: Result<UsageSnapshot, Error>

    func fetchUsage() async throws -> UsageSnapshot {
        try result.get()
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set(_ newValue: Bool) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }

    func get() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

struct CodexCLIUsageProviderTests {
    @Test func usesLiveCLIDataWithoutTouchingFallback() async throws {
        let fallback = StubFallbackProvider(result: .failure(UsageProviderError.noUsageData))
        let provider = CodexCLIUsageProvider(
            fetchRateLimits: {
                ["primary": ["usedPercent": 12, "windowDurationMins": 300, "resetsAt": 2_000_001_000]]
            },
            fallback: fallback
        )

        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.fiveHour?.roundedPercent == 12)
    }

    @Test func fallsBackWhenTheCLICallThrows() async throws {
        let now = Date()
        let fallbackSnapshot = UsageSnapshot(
            agentName: CodingAgent.codex.rawValue,
            fiveHour: UsageWindow(usedPercent: 55, windowMinutes: 300, resetsAt: now),
            weekly: nil,
            refreshedAt: now,
            sourceUpdatedAt: now
        )
        let provider = CodexCLIUsageProvider(
            fetchRateLimits: { throw CodexAppServerClient.CommunicationError(message: "boom") },
            fallback: StubFallbackProvider(result: .success(fallbackSnapshot))
        )

        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.fiveHour?.roundedPercent == 55)
    }

    @Test func fallsBackWhenTheCLIResponseHasNoRecognizedWindows() async throws {
        let now = Date()
        let fallbackSnapshot = UsageSnapshot(
            agentName: CodingAgent.codex.rawValue,
            fiveHour: nil,
            weekly: UsageWindow(usedPercent: 70, windowMinutes: 10_080, resetsAt: now),
            refreshedAt: now,
            sourceUpdatedAt: now
        )
        let provider = CodexCLIUsageProvider(
            fetchRateLimits: { [:] },
            fallback: StubFallbackProvider(result: .success(fallbackSnapshot))
        )

        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.weekly?.roundedPercent == 70)
    }

    @Test func offlineModeSkipsTheCLICallEntirely() async throws {
        let now = Date()
        let fallbackSnapshot = UsageSnapshot(
            agentName: CodingAgent.codex.rawValue,
            fiveHour: UsageWindow(usedPercent: 33, windowMinutes: 300, resetsAt: now),
            weekly: nil,
            refreshedAt: now,
            sourceUpdatedAt: now
        )
        let cliWasCalled = LockedFlag()
        let provider = CodexCLIUsageProvider(
            isOfflineModeEnabled: { true },
            fetchRateLimits: {
                cliWasCalled.set(true)
                return ["primary": ["usedPercent": 12, "windowDurationMins": 300, "resetsAt": 2_000_001_000]]
            },
            fallback: StubFallbackProvider(result: .success(fallbackSnapshot))
        )

        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.fiveHour?.roundedPercent == 33)
        #expect(cliWasCalled.get() == false)
    }
}
