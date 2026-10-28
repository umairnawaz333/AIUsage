import Foundation

/// One reading of Claude usage limits.
///
/// Source line format (written by the Claude Code status line):
/// `<saved_epoch> <5h_pct> <5h_reset_epoch> <weekly_pct> <weekly_reset_epoch>`
struct UsageSnapshot: Equatable {
    var savedAt: Date
    var session: Limit
    var weekly: Limit

    struct Limit: Equatable {
        var percent: Int
        var resetsAt: Date?

        /// Once the reset time has passed the old percentage no longer applies.
        func current(at now: Date) -> Limit {
            if let resetsAt, now >= resetsAt { return Limit(percent: 0, resetsAt: nil) }
            return self
        }
    }

    static func parse(_ text: String) -> UsageSnapshot? {
        let fields = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count >= 2, let saved = Double(fields[0]) else { return nil }

        func percent(_ i: Int) -> Int? {
            guard i < fields.count, let value = Double(fields[i]) else { return nil }
            return Int(min(max(value, 0), 100).rounded())
        }
        func date(_ i: Int) -> Date? {
            guard i < fields.count, let value = Double(fields[i]), value > 0 else { return nil }
            return Date(timeIntervalSince1970: value)
        }

        guard let sessionPercent = percent(1) else { return nil }
        return UsageSnapshot(
            savedAt: Date(timeIntervalSince1970: saved),
            session: Limit(percent: sessionPercent, resetsAt: date(2)),
            weekly: Limit(percent: percent(3) ?? 0, resetsAt: date(4))
        )
    }

    func current(at now: Date) -> UsageSnapshot {
        UsageSnapshot(savedAt: savedAt, session: session.current(at: now), weekly: weekly.current(at: now))
    }
}

enum UsageFormat {
    /// "1h 36m", "12m", "2d 4h", or "now".
    static func countdown(to date: Date, from now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds >= 60 else { return "now" }
        let minutes = seconds / 60, hours = minutes / 60, days = hours / 24
        if days > 0 { return "\(days)d \(hours % 24)h" }
        if hours > 0 { return "\(hours)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    /// "Thu 8:00 PM" in the user's locale.
    static func weekdayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEjmm")
        return formatter.string(from: date)
    }

    /// "just now", "4m ago", "2h ago".
    static func age(of date: Date, from now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        return countdown(to: now, from: date) + " ago"
    }
}
