import Foundation

/// Claude usage limits as shown in the notch.
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

    func current(at now: Date) -> UsageSnapshot {
        UsageSnapshot(savedAt: savedAt, session: session.current(at: now), weekly: weekly.current(at: now))
    }

    /// Combines the readings from every Claude Code session.
    ///
    /// Each session reports the limits from its own last request, so idle sessions carry older,
    /// lower numbers. Usage only rises within a window, so for each limit take the latest window
    /// (the latest reset time) and the highest percentage seen for it.
    static func merge(_ readings: [Reading]) -> UsageSnapshot? {
        func best(_ limits: [Limit]) -> Limit? {
            limits.max { a, b in
                let ra = a.resetsAt ?? .distantPast, rb = b.resetsAt ?? .distantPast
                return ra == rb ? a.percent < b.percent : ra < rb
            }
        }
        let session = best(readings.compactMap(\.session))
        let weekly = best(readings.compactMap(\.weekly))
        guard session != nil || weekly != nil, let savedAt = readings.map(\.savedAt).max() else { return nil }
        return UsageSnapshot(savedAt: savedAt,
                             session: session ?? Limit(percent: 0, resetsAt: nil),
                             weekly: weekly ?? Limit(percent: 0, resetsAt: nil))
    }
}

/// The limits from one Claude Code status line payload.
struct Reading: Equatable {
    var savedAt: Date
    var session: UsageSnapshot.Limit?
    var weekly: UsageSnapshot.Limit?

    /// Reads `rate_limits.five_hour` and `rate_limits.seven_day` from the JSON Claude Code
    /// sends to status line commands.
    init?(statusLine data: Data, savedAt: Date) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any] else { return nil }
        self.savedAt = savedAt
        session = Self.limit(limits["five_hour"])
        weekly = Self.limit(limits["seven_day"])
        if session == nil && weekly == nil { return nil }
    }

    init(savedAt: Date, session: UsageSnapshot.Limit?, weekly: UsageSnapshot.Limit?) {
        self.savedAt = savedAt
        self.session = session
        self.weekly = weekly
    }

    private static func limit(_ value: Any?) -> UsageSnapshot.Limit? {
        guard let dict = value as? [String: Any], let used = number(dict["used_percentage"]) else { return nil }
        return UsageSnapshot.Limit(percent: Int(min(max(used, 0), 100).rounded()), resetsAt: date(dict["resets_at"]))
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    /// Epoch seconds (number or string), or an ISO 8601 string.
    private static func date(_ value: Any?) -> Date? {
        if let seconds = number(value), seconds > 0 { return Date(timeIntervalSince1970: seconds) }
        guard let text = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: text)
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

    /// "Thu 8 PM" in the user's locale.
    static func weekdayHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEj")
        return formatter.string(from: date)
    }

    /// "just now", "4m ago", "2h ago".
    static func age(of date: Date, from now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        return countdown(to: now, from: date) + " ago"
    }
}
