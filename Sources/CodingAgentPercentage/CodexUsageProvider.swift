import Foundation

struct CodexUsageProvider: AgentUsageProvider {
    let agentName = "Codex"
    private let sessionsDirectory: URL
    private let maximumFiles = 100
    private let maximumBytesPerFile = 1_048_576

    init(codexHome: URL? = nil) {
        let home = codexHome
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        sessionsDirectory = home.appendingPathComponent("sessions", isDirectory: true)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sessionsDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw UsageProviderError.sessionsDirectoryMissing
        }

        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { throw UsageProviderError.noUsageData }

        let files = enumerator.compactMap { $0 as? URL }.filter { url in
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: keys) else { return false }
            return values.isRegularFile == true
        }.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }.prefix(maximumFiles)

        var lines: [Data] = []
        for file in files {
            guard let handle = try? FileHandle(forReadingFrom: file) else { continue }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            let offset = size > maximumBytesPerFile ? size - UInt64(maximumBytesPerFile) : 0
            try? handle.seek(toOffset: offset)
            let data: Data
            do { data = try handle.readToEnd() ?? Data() }
            catch { continue }
            var fileLines = data.split(whereSeparator: { $0 == UInt8(0x0A) }).map { Data($0) }
            if offset > 0, !fileLines.isEmpty { fileLines.removeFirst() }
            lines.append(contentsOf: fileLines)
        }

        guard let snapshot = CodexUsageParser.snapshot(from: lines, agentName: agentName) else {
            throw UsageProviderError.noUsageData
        }
        return snapshot
    }
}
