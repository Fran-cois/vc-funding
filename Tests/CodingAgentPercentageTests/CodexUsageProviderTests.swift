import Foundation
import Testing
@testable import CodingAgentPercentage

struct CodexUsageProviderTests {
    @Test func discoversUsageInNestedSessionDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionDirectory = root
            .appendingPathComponent("sessions/2030/01/02", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let session = sessionDirectory.appendingPathComponent("rollout.jsonl")
        let event = #"{"timestamp":"2030-01-02T12:00:00Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":37,"window_minutes":300,"resets_at":2000001000},"secondary":{"used_percent":58,"window_minutes":10080,"resets_at":2000002000}}}}"#
        try Data((event + "\n").utf8).write(to: session)

        let snapshot = try await CodexUsageProvider(codexHome: root).fetchUsage()

        #expect(snapshot.agentName == CodingAgent.codex.rawValue)
        #expect(snapshot.fiveHour?.roundedPercent == 37)
        #expect(snapshot.weekly?.roundedPercent == 58)
    }

    @Test func reportsMissingSessionsDirectory() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            _ = try await CodexUsageProvider(codexHome: root).fetchUsage()
            Issue.record("Expected the provider to reject a missing sessions directory")
        } catch let error as UsageProviderError {
            #expect(error == .sessionsDirectoryMissing)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
