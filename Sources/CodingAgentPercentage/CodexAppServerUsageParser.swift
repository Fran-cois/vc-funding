import Foundation

/// Parses the result of `codex app-server`'s `account/rateLimits/read` RPC into a `UsageSnapshot`,
/// mirroring `CodexUsageParser`'s window-minutes mapping (300 -> five-hour, 10_080 -> weekly) but
/// reading the live camelCase CLI fields instead of jsonl `rate_limits` events. Every metered limit
/// (e.g. "Codex", "GPT-5.3-Codex-Spark", "gpt-reserve") is exposed as its own line.
enum CodexAppServerUsageParser {
    static func snapshot(
        fromResult result: [String: Any],
        now: Date = Date(),
        agentName: String = "Codex"
    ) -> UsageSnapshot? {
        guard let primaryRateLimits = result["rateLimits"] as? [String: Any] else { return nil }

        let byLimitId = (result["rateLimitsByLimitId"] as? [String: Any]) ?? [:]
        let bucketsById: [(id: String, value: [String: Any])] = byLimitId.compactMap { key, value in
            (value as? [String: Any]).map { (key, $0) }
        }.sorted { lhs, rhs in
            // The "codex" bucket is the main/legacy limit, so it always leads; the rest follow alphabetically.
            if (lhs.id == "codex") != (rhs.id == "codex") { return lhs.id == "codex" }
            return lhs.id < rhs.id
        }

        let lines: [UsageLine] = bucketsById.isEmpty
            ? [line(named: "Codex", from: primaryRateLimits)].compactMap { $0 }
            : bucketsById.compactMap { id, bucket in
                line(named: (bucket["limitName"] as? String) ?? id, from: bucket)
            }

        guard !lines.isEmpty, let primaryWindows = windows(from: primaryRateLimits) else { return nil }
        return UsageSnapshot(
            agentName: agentName,
            fiveHour: primaryWindows[300],
            weekly: primaryWindows[10_080],
            refreshedAt: now,
            sourceUpdatedAt: now,
            lines: lines
        )
    }

    private static func line(named name: String, from rateLimits: [String: Any]) -> UsageLine? {
        guard let matched = windows(from: rateLimits) else { return nil }
        return UsageLine(name: name, fiveHour: matched[300], weekly: matched[10_080])
    }

    private static func windows(from rateLimits: [String: Any], now: Date = Date()) -> [Int: UsageWindow]? {
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
        return windows.isEmpty ? nil : windows
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

