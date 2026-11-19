import Foundation

/// What the page with a title's or an episode's whole description shows
/// (title-detail-and-episode-picker/what-the-title-is-about,
/// title-detail-and-episode-picker/what-each-episode-shows). Empty fields
/// are left out.
public struct TitleAboutText: Sendable, Hashable, Identifiable {
    /// A block of text, with "Cast" or "Director" before it when it names people.
    public struct Paragraph: Sendable, Hashable {
        public var label: String?
        public var text: String

        public init(label: String? = nil, text: String) {
            self.label = label
            self.text = text
        }
    }

    /// The title's name, or "4. Low Water" for an episode.
    public var heading: String
    /// The page's details line, or "Season 1 · Episode 4 · 44 min".
    public var details: String?
    public var paragraphs: [Paragraph]

    public var id: String { heading + (details ?? "") + paragraphs.map(\.text).joined() }

    public init(heading: String, details: String?, paragraphs: [Paragraph]) {
        self.heading = heading
        self.details = details
        self.paragraphs = paragraphs
    }

    /// The description, then Cast and Director.
    public init(_ metadata: TitleMetadata, locale: Locale = .autoupdatingCurrent) {
        let words = Words(locale)
        let paragraphs: [Paragraph?] = [
            TitleMetadata.present(metadata.description).map { Paragraph(text: $0) },
            TitleMetadata.present(metadata.cast).map { Paragraph(label: words("Cast"), text: $0) },
            TitleMetadata.present(metadata.director).map { Paragraph(label: words("Director"), text: $0) },
        ]
        self.init(heading: metadata.name, details: metadata.detailsLine, paragraphs: paragraphs.compactMap(\.self))
    }

    /// The episode's number and title, its season, number and length, and
    /// its description.
    public init(_ episode: Episode, locale: Locale = .autoupdatingCurrent) {
        let words = Words(locale)
        let title = TitleMetadata.present(episode.title)
        let heading: String =
            switch (episode.number, title) {
            case (let number?, let title?) where title != "Episode \(number)": "\(number). \(title)"
            case (let number?, _): words("Episode \(String(number))")
            case (nil, let title?): title
            case (nil, nil): words("Episode")
            }
        let details = [
            episode.season.map { words("Season \(String($0))") }, episode.number.map { words("Episode \(String($0))") },
            ShelfText.length(episode.duration, locale: locale),
        ]
        .compactMap(\.self)
        self.init(
            heading: heading, details: details.isEmpty ? nil : details.joined(separator: " · "),
            paragraphs: TitleMetadata.present(episode.plot).map { [Paragraph(text: $0)] } ?? [])
    }
}
