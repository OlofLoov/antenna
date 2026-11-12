import Foundation

/// Keeps a reminder with its programme as the guide changes
/// (programme-reminders/reminders-follow-a-programme-that-moves,
/// programme-reminders/reminders-survive-a-programme-leaving-the-guide).
public enum ReminderMatching {
    /// How far a programme may move and still take its reminder along.
    public static let reach: TimeInterval = 6 * 3600

    /// The window of programmes `match` needs for `reminder`.
    public static func window(for reminder: Reminder) -> DateInterval {
        DateInterval(start: reminder.start.addingTimeInterval(-reach), end: reminder.start.addingTimeInterval(reach + 1))
    }

    /// The reminder after a guide update, or nil when nothing changes.
    ///
    /// - A programme starting at the same time keeps it, and its title and stop follow.
    /// - Otherwise the same title, ignoring case and accents, starting
    ///   nearest within six hours moves it; on a tie the earlier wins. The
    ///   first original start is kept.
    /// - Otherwise, when the channel's schedule covers the start, it is
    ///   marked as no longer in the guide and keeps its time.
    /// - Otherwise nothing changes.
    ///
    /// - Parameters:
    ///   - programmes: the channel's programmes around the start, from `window(for:)`.
    ///   - coverage: the channel's whole schedule, nil when its guide has not loaded.
    public static func match(_ reminder: Reminder, programmes: [Programme], coverage: DateInterval?) -> Reminder? {
        var updated = reminder
        if let same = programmes.first(where: { $0.start == reminder.start }) {
            updated.title = GuidePanelText.title(same)
            updated.stop = same.stop
            updated.notListed = false
            if updated.movedFrom == same.start { updated.movedFrom = nil }
            return updated == reminder ? nil : updated
        }
        let title = fold(reminder.title)
        let moved =
            programmes
            .filter { fold(GuidePanelText.title($0)) == title && abs($0.start.timeIntervalSince(reminder.start)) <= reach }
            .min { lhs, rhs in
                let left = abs(lhs.start.timeIntervalSince(reminder.start))
                let right = abs(rhs.start.timeIntervalSince(reminder.start))
                return left != right ? left < right : lhs.start < rhs.start
            }
        if let moved {
            updated.movedFrom = reminder.movedFrom ?? reminder.start
            if updated.movedFrom == moved.start { updated.movedFrom = nil }
            updated.start = moved.start
            updated.stop = moved.stop
            updated.title = GuidePanelText.title(moved)
            updated.notListed = false
            return updated
        }
        guard let coverage, coverage.start <= reminder.start, reminder.start < coverage.end else { return nil }
        guard !reminder.notListed else { return nil }
        updated.notListed = true
        return updated
    }

    static func fold(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

extension GuideIndex {
    /// From the first programme's start to the last one's stop on the
    /// channel's schedule; nil before its source has loaded or when the
    /// channel has no programmes.
    public func span(for key: GuideKey) -> DateInterval? {
        guard let list = sources[key.sourceID]?.guide?.schedules[key.epgID], let first = list.first, let last = list.last else {
            return nil
        }
        return DateInterval(start: first.start, end: max(first.start, last.stop))
    }
}
