import Foundation
import Testing
@testable import CodingAgentPercentage

struct SwitchNotificationManagerTests {
    @Test func selectsMostUrgentWindowAtThreshold() throws {
        let snapshot = makeSnapshot(fiveHour: 90, weekly: 97)
        let candidate = try #require(SwitchNotificationManager.candidate(for: snapshot))

        #expect(candidate.label == "7d")
        #expect(candidate.window.roundedPercent == 97)
    }

    @Test func staysSilentBelowThreshold() {
        let snapshot = makeSnapshot(fiveHour: 89, weekly: 70)
        #expect(SwitchNotificationManager.candidate(for: snapshot) == nil)
    }

    private func makeSnapshot(fiveHour: Double, weekly: Double) -> UsageSnapshot {
        let now = Date()
        return UsageSnapshot(
            agentName: CodingAgent.codex.rawValue,
            fiveHour: UsageWindow(
                usedPercent: fiveHour,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(3_600)
            ),
            weekly: UsageWindow(
                usedPercent: weekly,
                windowMinutes: 10_080,
                resetsAt: now.addingTimeInterval(86_400)
            ),
            refreshedAt: now,
            sourceUpdatedAt: now
        )
    }
}
