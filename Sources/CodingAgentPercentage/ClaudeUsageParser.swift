import Foundation

/// Parses the text `claude -p "/usage" --output-format json` prints, e.g.:
/// "Current session: 25% used · resets Sep 24 at 12:29pm (Europe/Paris)"
/// "Current week (all models): 6% used · resets Sep 28 at 4:59pm (Europe/Paris)"
enum ClaudeUsageParser {
    static func snapshot(
        fromResultText text: String,
        agentName: String = CodingAgent.claudeCode.rawValue,
        now: Date = Date()
    ) -> UsageSnapshot? {
        let fiveHour = window(in: text, label: "Current session", windowMinutes: 300, now: now)
        let weekly = window(in: text, label: "Current week", windowMinutes: 10_080, now: now)
        guard fiveHour != nil || weekly != nil else { return nil }

        return UsageSnapshot(
            agentName: agentName,
            fiveHour: fiveHour,
            weekly: weekly,
            refreshedAt: now,
            sourceUpdatedAt: now
        )
    }

    private static func window(in text: String, label: String, windowMinutes: Int, now: Date) -> UsageWindow? {
        guard let line = text.components(separatedBy: .newlines).first(where: { $0.hasPrefix(label) }),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 5,
              let percentRange = Range(match.range(at: 1), in: line),
              let percent = Double(line[percentRange]),
              let dateRange = Range(match.range(at: 2), in: line),
              let timeRange = Range(match.range(at: 3), in: line),
              let tzRange = Range(match.range(at: 4), in: line)
        else { return nil }

        let timeZone = TimeZone(identifier: String(line[tzRange])) ?? .current
        let resetsAt = resetDate(
            dateText: String(line[dateRange]),
            timeText: String(line[timeRange]),
            timeZone: timeZone,
            now: now
        ) ?? now.addingTimeInterval(Double(windowMinutes) * 60)

        return UsageWindow(usedPercent: min(max(percent, 0), 100), windowMinutes: windowMinutes, resetsAt: resetsAt)
    }

    private static let regex = try! NSRegularExpression(
        pattern: #"(\d+)% used · resets ([A-Za-z]{3} \d{1,2}) at (\d{1,2}:\d{2}(?:am|pm)) \(([^)]+)\)"#
    )

    /// The CLI omits the year, so try the current year and roll to next year if that lands in the
    /// past — resets are always imminent (within the window), never a year-old date.
    private static func resetDate(dateText: String, timeText: String, timeZone: TimeZone, now: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy MMM d h:mma"

        let currentYear = Calendar(identifier: .gregorian).component(.year, from: now)
        for year in [currentYear, currentYear + 1] {
            if let date = formatter.date(from: "\(year) \(dateText) \(timeText)"),
               date > now.addingTimeInterval(-86_400) {
                return date
            }
        }
        return nil
    }
}
