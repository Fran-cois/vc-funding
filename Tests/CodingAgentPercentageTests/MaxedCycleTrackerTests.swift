import Foundation
import Testing
@testable import CodingAgentPercentage

@MainActor
struct MaxedCycleTrackerTests {
    @Test func countsAMaxedWindowOnce() {
        let defaults = UserDefaults(suiteName: "MaxedCycleTrackerTests.\(UUID().uuidString)")!
        let now = Date()
        let tracker = MaxedCycleTracker(defaults: defaults, now: now)
        let window = UsageWindow(usedPercent: 96, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600))

        tracker.recordObservation(agent: "Codex", window: window, now: now)
        tracker.recordObservation(agent: "Codex", window: window, now: now.addingTimeInterval(60))

        #expect(tracker.countsThisWeek(now: now)["Codex"] == 1)
    }

    @Test func ignoresWindowsBelowTheThreshold() {
        let defaults = UserDefaults(suiteName: "MaxedCycleTrackerTests.\(UUID().uuidString)")!
        let now = Date()
        let tracker = MaxedCycleTracker(defaults: defaults, now: now)
        let window = UsageWindow(usedPercent: 80, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600))

        tracker.recordObservation(agent: "Codex", window: window, now: now)

        #expect(tracker.countsThisWeek(now: now).isEmpty)
    }

    @Test func countsDifferentResetBoundariesSeparately() {
        let defaults = UserDefaults(suiteName: "MaxedCycleTrackerTests.\(UUID().uuidString)")!
        let now = Date()
        let tracker = MaxedCycleTracker(defaults: defaults, now: now)
        let first = UsageWindow(usedPercent: 100, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600))
        let second = UsageWindow(usedPercent: 100, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600 * 6))

        tracker.recordObservation(agent: "Codex", window: first, now: now)
        tracker.recordObservation(agent: "Codex", window: second, now: now.addingTimeInterval(3_600 * 5))

        #expect(tracker.countsThisWeek(now: now)["Codex"] == 2)
    }

    @Test func resetsCountsOnANewWeek() {
        let defaults = UserDefaults(suiteName: "MaxedCycleTrackerTests.\(UUID().uuidString)")!
        let now = Date()
        let tracker = MaxedCycleTracker(defaults: defaults, now: now)
        let window = UsageWindow(usedPercent: 100, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600))

        tracker.recordObservation(agent: "Codex", window: window, now: now)
        #expect(tracker.countsThisWeek(now: now)["Codex"] == 1)

        let nextWeek = now.addingTimeInterval(8 * 24 * 3_600)
        #expect(tracker.countsThisWeek(now: nextWeek).isEmpty)
    }

    @Test func tracksMultipleAgentsIndependently() {
        let defaults = UserDefaults(suiteName: "MaxedCycleTrackerTests.\(UUID().uuidString)")!
        let now = Date()
        let tracker = MaxedCycleTracker(defaults: defaults, now: now)
        let window = UsageWindow(usedPercent: 100, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600))

        tracker.recordObservation(agent: "Codex", window: window, now: now)
        tracker.recordObservation(agent: "GitHub Copilot", window: window, now: now)

        let counts = tracker.countsThisWeek(now: now)
        #expect(counts["Codex"] == 1)
        #expect(counts["GitHub Copilot"] == 1)
    }
}
