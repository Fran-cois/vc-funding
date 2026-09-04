import Foundation

struct ParsedRateLimitEvent: Equatable, Sendable {
    let timestamp: Date
    let windows: [UsageWindow]
}

enum CodexUsageParser {
    static func parse(line: Data) -> ParsedRateLimitEvent? {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            let payload = object["payload"] as? [String: Any],
            payload["type"] as? String == "token_count",
            let rateLimits = payload["rate_limits"] as? [String: Any],
            let timestampString = object["timestamp"] as? String,
            let timestamp = parseDate(timestampString)
        else { return nil }

        let windows = ["primary", "secondary"].compactMap { key -> UsageWindow? in
            guard
                let value = rateLimits[key] as? [String: Any],
                let used = number(value["used_percent"]),
                let minutes = number(value["window_minutes"]),
                let reset = number(value["resets_at"])
            else { return nil }

            return UsageWindow(
                usedPercent: min(max(used, 0), 100),
                windowMinutes: Int(minutes),
                resetsAt: Date(timeIntervalSince1970: reset)
            )
        }

        return windows.isEmpty ? nil : ParsedRateLimitEvent(timestamp: timestamp, windows: windows)
    }

    static func snapshot(
        from lines: [Data],
        now: Date = Date(),
        agentName: String = "Codex"
    ) -> UsageSnapshot? {
        var latest: [Int: (Date, UsageWindow)] = [:]

        for line in lines {
            guard let event = parse(line: line) else { continue }
            for window in event.windows where window.resetsAt > now {
                if latest[window.windowMinutes]?.0 ?? .distantPast < event.timestamp {
                    latest[window.windowMinutes] = (event.timestamp, window)
                }
            }
        }

        guard !latest.isEmpty else { return nil }
        let sourceDate = latest.values.map(\.0).max() ?? now
        return UsageSnapshot(
            agentName: agentName,
            fiveHour: latest[300]?.1,
            weekly: latest[10_080]?.1,
            refreshedAt: now,
            sourceUpdatedAt: sourceDate
        )
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
