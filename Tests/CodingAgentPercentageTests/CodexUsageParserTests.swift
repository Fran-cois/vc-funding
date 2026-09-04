import Foundation
import Testing
@testable import CodingAgentPercentage

struct CodexUsageParserTests {
    @Test func parsesPrimaryAndSecondaryWindows() throws {
        let line = Data(#"{"timestamp":"2026-09-04T12:00:00.123Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":42.4,"window_minutes":300,"resets_at":1788530400},"secondary":{"used_percent":68,"window_minutes":10080,"resets_at":1789048800}}}}"#.utf8)
        let event = try #require(CodexUsageParser.parse(line: line))
        #expect(event.windows.count == 2)
        #expect(event.windows[0].roundedPercent == 42)
        #expect(event.windows[1].windowMinutes == 10_080)
    }

    @Test func ignoresUnrelatedAndMalformedLines() {
        #expect(CodexUsageParser.parse(line: Data("not json".utf8)) == nil)
        let unrelated = Data(#"{"timestamp":"2026-09-04T12:00:00Z","payload":{"type":"message"}}"#.utf8)
        #expect(CodexUsageParser.parse(line: unrelated) == nil)
    }

    @Test func mergesNewestWindowEventsAndDropsExpiredData() throws {
        let older = Data(#"{"timestamp":"2026-09-04T10:00:00Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":20,"window_minutes":300,"resets_at":2000001000},"secondary":{"used_percent":60,"window_minutes":10080,"resets_at":2000002000}}}}"#.utf8)
        let newerWeekly = Data(#"{"timestamp":"2026-09-04T11:00:00Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":65,"window_minutes":10080,"resets_at":2000002000}}}}"#.utf8)
        let snapshot = try #require(CodexUsageParser.snapshot(from: [older, newerWeekly], now: Date(timeIntervalSince1970: 2_000_000_000)))
        #expect(snapshot.fiveHour?.roundedPercent == 20)
        #expect(snapshot.weekly?.roundedPercent == 65)

        let expiredNow = Date(timeIntervalSince1970: 2_000_003_000)
        #expect(CodexUsageParser.snapshot(from: [older, newerWeekly], now: expiredNow) == nil)
    }

    @Test func clampsInvalidPercentages() throws {
        let line = Data(#"{"timestamp":"2026-09-04T12:00:00Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":125,"window_minutes":300,"resets_at":2000001000}}}}"#.utf8)
        let event = try #require(CodexUsageParser.parse(line: line))
        #expect(event.windows[0].usedPercent == 100)
    }
}
