import Foundation
import Testing
@testable import CodingAgentPercentage

private struct FixedUsageProvider: AgentUsageProvider {
    let agentName = CodingAgent.codex.rawValue
    let percent: Double

    func fetchUsage() async throws -> UsageSnapshot {
        let now = Date()
        return UsageSnapshot(
            agentName: agentName,
            fiveHour: UsageWindow(
                usedPercent: percent,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(3_600)
            ),
            weekly: nil,
            refreshedAt: now,
            sourceUpdatedAt: now
        )
    }
}

@MainActor
struct UsageStoreTests {
    @Test func recommendsSwitchAtNinetyPercent() async {
        let store = UsageStore(provider: FixedUsageProvider(percent: 90))
        await store.refresh()

        #expect(store.shouldSwitch)
        #expect(store.switchReason(for: .codex)?.contains("90%") == true)
    }

    @Test func staysQuietBelowThreshold() async {
        let store = UsageStore(provider: FixedUsageProvider(percent: 89))
        await store.refresh()

        #expect(!store.shouldSwitch)
        #expect(store.switchReason(for: .codex) == nil)
        #expect(store.menuBarTitle == "5h 89%")
        #expect(!store.menuBarTitle.contains("N/A"))
    }
}
