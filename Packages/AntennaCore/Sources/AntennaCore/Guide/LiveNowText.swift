import Foundation

/// What Live on iPhone, iPad and Mac says about the playing channel
/// (live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next): the programme
/// on now with its times and how far it has run, and what follows.
public struct LiveNowText: Sendable, Equatable {
    /// The programme title, or "No programme information" or "Loading guide…".
    public let title: String
    /// Start and end, "20:00 – 22:00"; nil without a programme on now.
    public let times: String?
    /// How far into the programme, 0 to 1; nil without a programme on now.
    public let progress: Double?
    /// The programme's description; nil without a programme on now.
    public let summary: String?
    /// The details' line on iPad and Mac: "Sport One · 104 · 26 min left".
    public let meta: String
    /// The iPhone line under the title: "104 Sport One · 20:00 – 22:00 ·
    /// Next: Match of the Day", with the parts the guide does not know left out.
    public let compact: String
    /// Up to three programmes that follow, in order.
    public let next: [Programme]

    /// - Parameters:
    ///   - current: the programme the guide has at `now`, if any. One that
    ///     does not cover `now` counts as none.
    ///   - next: programmes starting at or after the current one's end, or
    ///     after `now` without one, in order. Only the first three are kept.
    ///   - time: formats a start or end time for the user's locale.
    public init(
        channel: String, number: ChannelNumber?, state: GuideLoadingState, current: Programme?, next: [Programme], now: Date,
        time: (Date) -> String, locale: Locale = .autoupdatingCurrent
    ) {
        let words = Words(locale)
        let line = GuideLine(state: state, current: current, now: now, locale: locale)
        let upcoming = Array(next.prefix(3))
        self.next = upcoming
        title = line.text
        let name = words.source(channel)
        let identity = ChannelIdentityText.parts(number: number, name: channel, locale: locale)
        var metaParts = [name] + [number.map { $0.text(locale) }].compactMap(\.self)
        var compactParts = [identity]
        if case .programme(_, let fraction, let remaining) = line, let current {
            let span = "\(time(current.start)) – \(time(current.stop))"
            times = span
            progress = fraction
            summary = current.summary
            metaParts.append(remaining)
            compactParts.append(span)
        } else {
            times = nil
            progress = nil
            summary = nil
        }
        if let first = upcoming.first { compactParts.append(words("Next: \(words.source(first.title))")) }
        meta = words.line(metaParts)
        compact = words.line(compactParts)
    }
}

/// A channel's number and name on one line, "104 Sport One", as the iPhone
/// now-playing line and the Apple TV guide's picture caption show it. The
/// number is in the locale's digits and the name keeps its own direction
/// (localization/mixed-scripts-keep-their-own-direction).
public enum ChannelIdentityText {
    public static func text(number: ChannelNumber?, name: String, locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale).line([parts(number: number, name: name, locale: locale)])
    }

    static func parts(number: ChannelNumber?, name: String, locale: Locale) -> String {
        [number.map { $0.text(locale) }, Words(locale).source(name)].compactMap(\.self).joined(separator: " ")
    }
}
