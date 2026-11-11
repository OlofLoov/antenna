import Foundation

/// Words and badges on the banner and posters (movies-and-series-browsing).
public enum ShelfText {
    /// A film's length, "2 h 08 min" or "47 min". Nil when unknown.
    public static func length(_ seconds: Double?) -> String? {
        guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
        let minutes = max(1, Int((seconds / 60).rounded()))
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = minutes % 60
        return "\(minutes / 60) h \(rest < 10 ? "0" : "")\(rest) min"
    }

    /// Whole minutes left, rounded up, for a title with a known length.
    public static func minutesLeft(_ progress: WatchProgress) -> Int? {
        guard let length = progress.knownDuration else { return nil }
        return max(1, Int(((length - progress.position) / 60).rounded(.up)))
    }

    /// "47 min left", or nil when the length is unknown.
    public static func left(_ progress: WatchProgress) -> String? {
        minutesLeft(progress).map { "\($0) min left" }
    }

    /// "1 season" or "3 seasons", shown for a series instead of a length.
    public static func seasons(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 season" : "\(count) seasons"
    }

    /// True when a movie's name marks it 4K: "2160p", "4K" or "UHD" in any case.
    public static func is4K(_ name: String) -> Bool {
        let folded = name.lowercased()
        return ["2160p", "4k", "uhd"].contains { folded.contains($0) }
    }

    private static let ratings: Set<String> = [
        "U", "PG", "12A", "G", "PG-13", "R", "R18", "NC-17", "TV-Y", "TV-Y7", "TV-G", "TV-PG", "TV-14", "TV-MA",
    ]

    /// The age badge for a provider's rating, or nil for any value outside
    /// the known set: the ages 0 to 21 and the common rating names.
    public static func ageBadge(_ rating: String?) -> String? {
        guard let rating = rating?.trimmingCharacters(in: .whitespaces), !rating.isEmpty else { return nil }
        if rating.allSatisfy(\.isASCII), let age = Int(rating), (0...21).contains(age), String(age) == rating { return rating }
        return ratings.contains(rating) ? rating : nil
    }
}
