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
        channel: String, number: Int?, state: GuideLoadingState, current: Programme?, next: [Programme], now: Date,
        time: (Date) -> String
    ) {
        let line = GuideLine(state: state, current: current, now: now)
        let upcoming = Array(next.prefix(3))
        self.next = upcoming
        title = line.text
        let identity = [number.map(String.init), channel].compactMap(\.self).joined(separator: " ")
        var metaParts = [channel] + [number.map(String.init)].compactMap(\.self)
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
        if let first = upcoming.first { compactParts.append("Next: \(first.title)") }
        meta = metaParts.joined(separator: " · ")
        compact = compactParts.joined(separator: " · ")
    }
}
