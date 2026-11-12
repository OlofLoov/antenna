import Foundation

/// What the Guide on iPhone, iPad and Mac says about the channel playing in
/// Live (guide-on-iphone-ipad-and-mac/playback-carries-on-out-of-sight):
/// the channel, the programme on now, the time left and how far it has run.
public struct GuideNowPlaying: Sendable, Equatable {
    /// "104 Sport One".
    public let channel: String
    /// The programme title, or "Loading guide…" or "No programme information".
    public let title: String
    /// The iPhone bar's second line: "104 Sport One · 26 min left", or the
    /// channel alone with no programme on now.
    public let detail: String
    /// How far into the programme, 0 to 1; nil with no programme on now.
    public let progress: Double?

    public init(channel name: String, number: Int?, state: GuideLoadingState, current: Programme?, now: Date) {
        channel = [number.map(String.init), name].compactMap(\.self).joined(separator: " ")
        let line = GuideLine(state: state, current: current, now: now)
        title = line.text
        if case .programme(_, let fraction, let remaining) = line {
            detail = "\(channel) · \(remaining)"
            progress = fraction
        } else {
            detail = channel
            progress = nil
        }
    }
}
