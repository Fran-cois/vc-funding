import Foundation
import Testing
@testable import CodingAgentPercentage

struct LocalAgentTraceDetectorTests {
    @Test func detectsOnlyAgentsWithLocalTraces() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }

        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex/sessions", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true),
            withIntermediateDirectories: true
        )

        let detector = LocalAgentTraceDetector(
            homeDirectory: home,
            applicationsDirectory: home.appendingPathComponent("Applications"),
            environment: [:],
            hasOpenRouterAPIKey: { false }
        )
        #expect(detector.detectedAgents() == [.codex, .antigravity])
    }

    @Test func returnsNoAgentsForAnEmptyHome() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let detector = LocalAgentTraceDetector(
            homeDirectory: home,
            applicationsDirectory: home.appendingPathComponent("Applications"),
            environment: [:],
            hasOpenRouterAPIKey: { false }
        )
        #expect(detector.detectedAgents().isEmpty)
    }

    @Test func detectsOpenRouterViaInjectedKeyCheckOnly() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let detector = LocalAgentTraceDetector(
            homeDirectory: home,
            applicationsDirectory: home.appendingPathComponent("Applications"),
            environment: [:],
            hasOpenRouterAPIKey: { true }
        )
        #expect(detector.detectedAgents() == [.openRouter])
    }
}
