import Foundation

/// Parses the `rateLimits` payload returned by `codex app-server`'s `account/rateLimits/read` RPC
/// into a `UsageSnapshot`, mirroring `CodexUsageParser`'s window-minutes mapping (300 -> five-hour,
/// 10_080 -> weekly) but reading the live camelCase CLI fields instead of jsonl `rate_limits` events.
enum CodexAppServerUsageParser {
    static func snapshot(
        fromRateLimits rateLimits: [String: Any],
        now: Date = Date(),
        agentName: String = "Codex"
    ) -> UsageSnapshot? {
        var windows: [Int: UsageWindow] = [:]

        for key in ["primary", "secondary"] {
            guard
                let value = rateLimits[key] as? [String: Any],
                let used = number(value["usedPercent"]),
                let minutes = number(value["windowDurationMins"])
            else { continue }

            let resets = number(value["resetsAt"]) ?? now.timeIntervalSince1970
            windows[Int(minutes)] = UsageWindow(
                usedPercent: min(max(used, 0), 100),
                windowMinutes: Int(minutes),
                resetsAt: Date(timeIntervalSince1970: resets)
            )
        }

        guard !windows.isEmpty else { return nil }
        return UsageSnapshot(
            agentName: agentName,
            fiveHour: windows[300],
            weekly: windows[10_080],
            refreshedAt: now,
            sourceUpdatedAt: now
        )
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}
