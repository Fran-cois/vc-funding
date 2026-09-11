import Foundation

/// Speaks the `codex app-server` stdio JSON-RPC protocol to read live account rate limits directly
/// from OpenAI's backend (the same call the Codex TUI itself makes), instead of parsing local
/// session logs which can be stale, incomplete, or missing during rate-limit fallbacks.
enum CodexAppServerClient {
    struct CommunicationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Returns the raw `account/rateLimits/read` result, including both the backward-compatible
    /// single-bucket `rateLimits` field and the per-limit `rateLimitsByLimitId` breakdown.
    static func fetchRateLimitsResult(timeout: TimeInterval = 8) async throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "app-server"]

        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        defer {
            try? stdin.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }

        let reader = JSONLineReader(fileHandle: stdout.fileHandleForReading)

        func send(id: Int?, method: String, params: [String: Any]? = nil) throws {
            var object: [String: Any] = ["method": method]
            if let id { object["id"] = id }
            if let params { object["params"] = params }
            let data = try JSONSerialization.data(withJSONObject: object)
            stdin.fileHandleForWriting.write(data)
            stdin.fileHandleForWriting.write(Data([0x0A]))
        }

        try send(id: 1, method: "initialize", params: ["clientInfo": ["name": "vc-funding", "version": "1.0"]])
        guard try await withTimeout(timeout, { try await reader.nextLine(matchingId: 1) }) != nil else {
            throw CommunicationError(message: "codex app-server did not respond to initialize")
        }

        try send(id: nil, method: "initialized")
        try send(id: 2, method: "account/rateLimits/read")
        guard let responseLine = try await withTimeout(timeout, { try await reader.nextLine(matchingId: 2) }),
              let response = try? JSONSerialization.jsonObject(with: responseLine) as? [String: Any] else {
            throw CommunicationError(message: "codex app-server did not respond to account/rateLimits/read")
        }

        if let rpcError = response["error"] as? [String: Any] {
            throw CommunicationError(message: (rpcError["message"] as? String) ?? "codex app-server returned an error")
        }
        guard let result = response["result"] as? [String: Any],
              result["rateLimits"] is [String: Any] else {
            throw CommunicationError(message: "codex app-server response was missing rateLimits")
        }
        return result
    }

    private static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CommunicationError(message: "codex app-server timed out")
            }
            guard let result = try await group.next() else {
                throw CommunicationError(message: "codex app-server produced no result")
            }
            group.cancelAll()
            return result
        }
    }
}

/// Buffers stdout and yields each newline-delimited JSON object whose `id` matches, ignoring
/// interleaved notifications the app server may emit unprompted (e.g. `remoteControl/status/changed`).
private actor JSONLineReader {
    private let fileHandle: FileHandle
    private var buffer = Data()

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    func nextLine(matchingId id: Int) throws -> Data? {
        while true {
            if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = Data(buffer[..<newlineIndex])
                buffer.removeSubrange(...newlineIndex)
                guard !lineData.isEmpty,
                      let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
                if let objectId = object["id"] as? Int, objectId == id {
                    return lineData
                }
                continue
            }
            let chunk = fileHandle.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
        }
    }
}
