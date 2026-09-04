import Foundation
import Testing
@testable import CodingAgentPercentage

private struct FixedUsageProvider: AgentUsageProvider {
    let agentName: String
    let fiveHourPercent: Double?
    let weeklyPercent: Double?

    func fetchUsage() async throws -> UsageSnapshot {
        let now = Date()
        return UsageSnapshot(
            agentName: agentName,
            fiveHour: fiveHourPercent.map {
                UsageWindow(usedPercent: $0, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600))
            },
            weekly: weeklyPercent.map {
                UsageWindow(usedPercent: $0, windowMinutes: 10_080, resetsAt: now.addingTimeInterval(86_400))
            },
            refreshedAt: now,
            sourceUpdatedAt: now
        )
    }
}

private struct FailingUsageProvider: AgentUsageProvider {
    let agentName: String

    func fetchUsage() async throws -> UsageSnapshot {
        throw UsageProviderError.unsupportedAgent(agentName)
    }
}

@MainActor
struct UsageStoreTests {
    @Test func recommendsSwitchAtNinetyPercent() async {
        let store = UsageStore(provider: FixedUsageProvider(
            agentName: CodingAgent.codex.rawValue,
            fiveHourPercent: 90,
            weeklyPercent: nil
        ))
        await store.refresh()

        #expect(store.shouldSwitch)
        #expect(store.switchReason(for: .codex)?.contains("90%") == true)
    }

    @Test func staysQuietBelowThreshold() async {
        let store = UsageStore(provider: FixedUsageProvider(
            agentName: CodingAgent.codex.rawValue,
            fiveHourPercent: 89,
            weeklyPercent: nil
        ))
        await store.refresh()

        #expect(!store.shouldSwitch)
        #expect(store.switchReason(for: .codex) == nil)
        #expect(store.menuBarTitle == "5h 89%")
        #expect(!store.menuBarTitle.contains("N/A"))
    }

    @Test func formatsOnlyAvailableWindows() async {
        let store = UsageStore(provider: FixedUsageProvider(
            agentName: CodingAgent.codex.rawValue,
            fiveHourPercent: nil,
            weeklyPercent: 41
        ))
        await store.refresh()

        #expect(store.menuBarTitle == "7d 41%")
    }

    @Test func keepsProviderResultsIndependent() async {
        let store = UsageStore(providers: [
            FixedUsageProvider(
                agentName: CodingAgent.codex.rawValue,
                fiveHourPercent: 10,
                weeklyPercent: 20
            ),
            FailingUsageProvider(agentName: CodingAgent.claudeCode.rawValue)
        ])
        await store.refresh()

        #expect(store.snapshot(for: .codex) != nil)
        #expect(store.errorMessage(for: .codex) == nil)
        #expect(store.snapshot(for: .claudeCode) == nil)
        #expect(store.errorMessage(for: .claudeCode)?.contains("not configured") == true)
    }

    @Test func weeklyWindowCanTriggerSwitchAlert() async {
        let store = UsageStore(provider: FixedUsageProvider(
            agentName: CodingAgent.codex.rawValue,
            fiveHourPercent: 25,
            weeklyPercent: 96
        ))
        await store.refresh()

        #expect(store.shouldSwitch)
        #expect(store.switchReason(for: .codex) == "7d usage is at 96%. Consider switching coding agent.")
    }

    @Test func exposesAllSupportedAgentTabs() {
        #expect(CodingAgent.allCases == [.codex, .claudeCode, .antigravity])
    }
}
