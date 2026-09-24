import Foundation

/// Runs Claude Code's local `/usage` command, which computes rate-limit percentages entirely from
/// on-disk session data — no network call, no API cost, no offline-mode toggle needed — and returns
/// the same numbers the CLI itself shows the user.
enum ClaudeCLIClient {
    struct CommunicationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func fetchUsageResultText(timeout: TimeInterval = 8) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["claude", "-p", "/usage", "--output-format", "json"]
        process.environment = augmentedEnvironment()

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw CommunicationError(message: "claude CLI was not found. Make sure it's installed and on PATH.")
        }

        let data = try await withTimeout(timeout) {
            stdout.fileHandleForReading.readDataToEndOfFile()
        }
        if process.isRunning { process.terminate() }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["is_error"] as? Bool == false,
            let result = object["result"] as? String
        else {
            throw CommunicationError(message: "claude CLI did not return usage data")
        }
        return result
    }

    /// The native installer places `claude` under `~/.local/bin`, which a GUI app launched outside a
    /// login shell doesn't inherit in `PATH`; widen it so `/usr/bin/env claude` can still find it.
    private static func augmentedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        let existing = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = (extraPaths + [existing]).joined(separator: ":")
        return environment
    }

    private static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ operation: @escaping @Sendable () -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CommunicationError(message: "claude CLI timed out")
            }
            guard let result = try await group.next() else {
                throw CommunicationError(message: "claude CLI produced no result")
            }
            group.cancelAll()
            return result
        }
    }
}
