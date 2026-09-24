import Foundation
import Testing
@testable import CodingAgentPercentage

struct ClaudeUsageParserTests {
    private static let sampleText = """
    You are currently using your subscription to power your Claude Code usage

    Current session: 25% used · resets Sep 24 at 12:29pm (Europe/Paris)
    Current week (all models): 6% used · resets Sep 28 at 4:59pm (Europe/Paris)

    What's contributing to your limits usage?
    """

    @Test func parsesBothWindows() throws {
        let now = ClaudeUsageParserTests.date(year: 2026, month: 9, day: 24, hour: 10, minute: 0, timeZone: "Europe/Paris")
        let snapshot = try #require(ClaudeUsageParser.snapshot(fromResultText: Self.sampleText, now: now))

        #expect(snapshot.agentName == CodingAgent.claudeCode.rawValue)
        #expect(snapshot.fiveHour?.roundedPercent == 25)
        #expect(snapshot.fiveHour?.windowMinutes == 300)
        #expect(snapshot.weekly?.roundedPercent == 6)
        #expect(snapshot.weekly?.windowMinutes == 10_080)

        let expectedReset = ClaudeUsageParserTests.date(year: 2026, month: 9, day: 24, hour: 12, minute: 29, timeZone: "Europe/Paris")
        #expect(snapshot.fiveHour?.resetsAt == expectedReset)
    }

    @Test func rollsOverToNextYearWhenTheDateHasAlreadyPassedThisYear() throws {
        // Late December, resetting into early January — must not parse as a date in the past.
        let now = ClaudeUsageParserTests.date(year: 2026, month: 12, day: 31, hour: 23, minute: 0, timeZone: "UTC")
        let text = "Current session: 10% used · resets Jan 1 at 2:00am (UTC)"

        let snapshot = try #require(ClaudeUsageParser.snapshot(fromResultText: text, now: now))
        let resetYear = Calendar(identifier: .gregorian).component(
            .year,
            from: try #require(snapshot.fiveHour?.resetsAt)
        )
        #expect(resetYear == 2027)
    }

    @Test func returnsNilWhenNoRecognizedLinesArePresent() {
        let snapshot = ClaudeUsageParser.snapshot(fromResultText: "Nothing usage-shaped here.")
        #expect(snapshot == nil)
    }

    @Test func fallsBackToUnknownTimeZoneGracefully() throws {
        let text = "Current session: 50% used · resets Sep 24 at 12:29pm (Not/AZone)"
        let snapshot = try #require(ClaudeUsageParser.snapshot(fromResultText: text))
        #expect(snapshot.fiveHour?.roundedPercent == 50)
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, timeZone: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .current
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
}
