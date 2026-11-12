import Foundation

/// A Channels DVR build number, `yyyy.MM.dd.HHmm`. Components compare as
/// numbers, so "2023.1.1" and "2023.01.01.0000" are equal.
public struct ChannelsDVRVersion: Sendable, Hashable, Comparable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var build: Int

    public init(year: Int, month: Int, day: Int, build: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.build = build
    }

    /// Reads the leading dot-separated number groups. Nil when fewer than
    /// three lead the text. Anything after them, such as "-dev", is ignored.
    public init?(parsing text: String) {
        var groups: [Int] = []
        for part in text.split(separator: ".", omittingEmptySubsequences: false) {
            let digits = part.prefix { $0.isASCII && $0.isNumber }
            guard !digits.isEmpty, let value = Int(digits) else { break }
            groups.append(value)
            if digits.count != part.count || groups.count == 4 { break }
        }
        guard groups.count >= 3 else { return nil }
        self.init(year: groups[0], month: groups[1], day: groups[2], build: groups.count > 3 ? groups[3] : 0)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day, lhs.build) < (rhs.year, rhs.month, rhs.day, rhs.build)
    }
}

/// What a Channels DVR server says about itself at `/status`.
public struct ChannelsDVRStatus: Sendable, Hashable {
    /// Nil when the version text does not parse; the server is still accepted.
    public var version: ChannelsDVRVersion?
    /// The version as the server wrote it, for the loading checklist.
    public var versionText: String
    public var prerelease: Bool?
    /// False while the server is still starting.
    public var booted: Bool?
    public var subscription: String?

    public init(versionText: String, prerelease: Bool? = nil, booted: Bool? = nil, subscription: String? = nil) {
        self.version = ChannelsDVRVersion(parsing: versionText)
        self.versionText = versionText
        self.prerelease = prerelease
        self.booted = booted
        self.subscription = subscription
    }
}
