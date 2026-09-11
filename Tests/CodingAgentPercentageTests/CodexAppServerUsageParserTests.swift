import Foundation
import Testing
@testable import CodingAgentPercentage

struct CodexAppServerUsageParserTests {
    @Test func parsesPrimaryAndSecondaryWindowsWithoutABreakdown() throws {
        let result: [String: Any] = [
            "rateLimits": [
                "primary": ["usedPercent": 37, "windowDurationMins": 300, "resetsAt": 2_000_001_000],
                "secondary": ["usedPercent": 58, "windowDurationMins": 10_080, "resetsAt": 2_000_002_000]
            ]
        ]
        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromResult: result))
        #expect(snapshot.agentName == CodingAgent.codex.rawValue)
        #expect(snapshot.fiveHour?.roundedPercent == 37)
        #expect(snapshot.weekly?.roundedPercent == 58)
        #expect(snapshot.lines == [UsageLine(name: "Codex", fiveHour: snapshot.fiveHour, weekly: snapshot.weekly)])
    }

    @Test func mapsWhicheverSlotCarriesTheWeeklyWindow() throws {
        // The live backend doesn't always put the weekly window in "secondary" (e.g. during a
        // rate-limit fallback only "primary" is present) -- mapping must key off windowDurationMins.
        let result: [String: Any] = [
            "rateLimits": ["primary": ["usedPercent": 17, "windowDurationMins": 10_080, "resetsAt": 2_000_001_000]]
        ]
        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromResult: result))
        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.weekly?.roundedPercent == 17)
    }

    @Test func clampsInvalidPercentages() throws {
        let result: [String: Any] = [
            "rateLimits": ["primary": ["usedPercent": 125, "windowDurationMins": 300, "resetsAt": 2_000_001_000]]
        ]
        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromResult: result))
        #expect(snapshot.fiveHour?.usedPercent == 100)
    }

    @Test func returnsNilWhenNoRecognizedWindowsArePresent() {
        #expect(CodexAppServerUsageParser.snapshot(fromResult: [:]) == nil)
        #expect(CodexAppServerUsageParser.snapshot(fromResult: ["rateLimits": ["primary": ["usedPercent": 10]]]) == nil)
    }

    @Test func exposesEveryMeteredLimitAsItsOwnLine() throws {
        let result: [String: Any] = [
            "rateLimits": [
                "primary": ["usedPercent": 100, "windowDurationMins": 10_080, "resetsAt": 2_000_001_000]
            ],
            "rateLimitsByLimitId": [
                "codex": [
                    "limitName": NSNull(),
                    "primary": ["usedPercent": 100, "windowDurationMins": 10_080, "resetsAt": 2_000_001_000]
                ],
                "codex_bengalfox": [
                    "limitName": "GPT-5.3-Codex-Spark",
                    "primary": ["usedPercent": 0, "windowDurationMins": 300, "resetsAt": 2_000_002_000],
                    "secondary": ["usedPercent": 13, "windowDurationMins": 10_080, "resetsAt": 2_000_003_000]
                ],
                "base_model_inference": [
                    "limitName": "gpt-reserve",
                    "primary": ["usedPercent": 17, "windowDurationMins": 10_080, "resetsAt": 2_000_004_000]
                ]
            ]
        ]

        let snapshot = try #require(CodexAppServerUsageParser.snapshot(fromResult: result))
        // The top-level "rateLimits" mirror stays the canonical menu-bar/notification figure.
        #expect(snapshot.weekly?.roundedPercent == 100)

        #expect(snapshot.lines.map(\.name) == ["codex", "gpt-reserve", "GPT-5.3-Codex-Spark"])
        let spark = try #require(snapshot.lines.first { $0.name == "GPT-5.3-Codex-Spark" })
        #expect(spark.fiveHour?.roundedPercent == 0)
        #expect(spark.weekly?.roundedPercent == 13)
        let reserve = try #require(snapshot.lines.first { $0.name == "gpt-reserve" })
        #expect(reserve.fiveHour == nil)
        #expect(reserve.weekly?.roundedPercent == 17)
    }
}

