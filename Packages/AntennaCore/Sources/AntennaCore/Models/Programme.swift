import Foundation

/// One EPG entry. `channelID` matches `Channel.epgID`.
public struct Programme: Identifiable, Hashable, Sendable, Codable {
    public var channelID: String
    public var start: Date
    public var stop: Date
    public var title: String
    public var subtitle: String?
    public var summary: String?
    public var category: String?
    public var iconURL: URL?

    public var id: String { "\(channelID)|\(start.timeIntervalSince1970)" }

    public init(
        channelID: String,
        start: Date,
        stop: Date,
        title: String,
        subtitle: String? = nil,
        summary: String? = nil,
        category: String? = nil,
        iconURL: URL? = nil
    ) {
        self.channelID = channelID
        self.start = start
        self.stop = stop
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.category = category
        self.iconURL = iconURL
    }

    public func isAiring(at date: Date = .now) -> Bool {
        start <= date && date < stop
    }
}
