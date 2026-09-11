import Foundation
import Testing
@testable import CodingAgentPercentage

struct CodexAppServerUsageParserTests {
    @Test func parsesPrimaryAndSecondaryWindows() throws {
        let rateLimits: [String: Any] = [
            "primary": ["usedPercent": 37, "windowDurationMins": 300, "resetsAt": 2_000_001_000],
            "secondary": ["usedPercent": 58, "windowDurationMins": 10_080, "resetsAt": 2_000_002_000]
        ]
        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromRateLimits: rateLimits))
        #expect(snapshot.agentName == CodingAgent.codex.rawValue)
        #expect(snapshot.fiveHour?.roundedPercent == 37)
        #expect(snapshot.weekly?.roundedPercent == 58)
    }

    @Test func mapsWhicheverSlotCarriesTheWeeklyWindow() throws {
        // The live backend doesn't always put the weekly window in "secondary" (e.g. during a
        // rate-limit fallback only "primary" is present) -- mapping must key off windowDurationMins.
        let rateLimits: [String: Any] = [
            "primary": ["usedPercent": 17, "windowDurationMins": 10_080, "resetsAt": 2_000_001_000]
        ]
        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromRateLimits: rateLimits))
        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.weekly?.roundedPercent == 17)
    }

    @Test func clampsInvalidPercentages() throws {
        let rateLimits: [String: Any] = [
            "primary": ["usedPercent": 125, "windowDurationMins": 300, "resetsAt": 2_000_001_000]
        ]
        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromRateLimits: rateLimits))
        #expect(snapshot.fiveHour?.usedPercent == 100)
    }

    @Test func returnsNilWhenNoRecognizedWindowsArePresent() {
        #expect(CodexAppServerUsageParser.snapshot(fromRateLimits: [:]) == nil)
        #expect(CodexAppServerUsageParser.snapshot(fromRateLimits: ["primary": ["usedPercent": 10]]) == nil)
    }
}
