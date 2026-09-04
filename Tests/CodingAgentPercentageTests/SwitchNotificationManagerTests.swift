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

    @Test func recommendsBurningUnusedQuotaNearReset() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let snapshot = makeSnapshot(
            fiveHour: 35,
            weekly: 45,
            fiveHourReset: now.addingTimeInterval(1_800),
            weeklyReset: now.addingTimeInterval(172_800)
        )
        let candidate = try #require(SwitchNotificationManager.burnCandidate(for: snapshot, now: now))

        #expect(candidate.label == "5h")
        #expect(candidate.window.roundedPercent == 35)
    }

    @Test func doesNotRecommendBurningTooEarlyOrWhenNearlySpent() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let tooEarly = makeSnapshot(
            fiveHour: 35,
            weekly: 45,
            fiveHourReset: now.addingTimeInterval(7_200),
            weeklyReset: now.addingTimeInterval(172_800)
        )
        let nearlySpent = makeSnapshot(
            fiveHour: 81,
            weekly: 81,
            fiveHourReset: now.addingTimeInterval(1_800),
            weeklyReset: now.addingTimeInterval(3_600)
        )

        #expect(SwitchNotificationManager.burnCandidate(for: tooEarly, now: now) == nil)
        #expect(SwitchNotificationManager.burnCandidate(for: nearlySpent, now: now) == nil)
    }

    private func makeSnapshot(
        fiveHour: Double,
        weekly: Double,
        fiveHourReset: Date? = nil,
        weeklyReset: Date? = nil
    ) -> UsageSnapshot {
        let now = Date()
        return UsageSnapshot(
            agentName: CodingAgent.codex.rawValue,
            fiveHour: UsageWindow(
                usedPercent: fiveHour,
                windowMinutes: 300,
                resetsAt: fiveHourReset ?? now.addingTimeInterval(3_600)
            ),
            weekly: UsageWindow(
                usedPercent: weekly,
                windowMinutes: 10_080,
                resetsAt: weeklyReset ?? now.addingTimeInterval(86_400)
            ),
            refreshedAt: now,
            sourceUpdatedAt: now
        )
    }
}
