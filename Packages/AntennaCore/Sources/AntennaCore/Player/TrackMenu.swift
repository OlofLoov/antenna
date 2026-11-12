import Foundation

/// One row of the audio or subtitle list.
public struct TrackRow: Sendable, Equatable, Identifiable {
    /// The track's id, or `TrackMenu.offID` for the subtitles' Off row.
    public var id: String
    /// "English", "English (Commentary)", "Track 4" or "Off".
    public var name: String
    /// The sound format, such as "AAC 5.1", when the engine reports it.
    public var detail: String?
    public var isSelected: Bool

    public init(id: String, name: String, detail: String?, isSelected: Bool) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isSelected = isSelected
    }
}

/// The audio and subtitle lists the player shows
/// (player-controls-and-playback-errors/choose-audio-and-subtitles).
public enum TrackMenu {
    public static let offID = "off"
    public static let off = "Off"
    public static let noSubtitles = "No subtitles in this stream"

    /// One row per audio track in stream order, the playing one ticked.
    /// Engines report the sound format of the playing track only, so only
    /// that row has a detail.
    public static func audio(_ tracks: TrackList, presentation: PresentationInfo?) -> [TrackRow] {
        let format = presentation?.audio.map { SoundFormat.display(codec: $0.codec, channels: $0.channels) }
        return zip(tracks.audio.indices, tracks.audio).map { index, track in
            let selected = track.id == tracks.selectedAudio
            return TrackRow(
                id: track.id, name: TrackName.display(track, position: index), detail: selected ? format : nil, isSelected: selected)
        }
    }

    /// Off first, then one row per subtitle track; empty when the stream
    /// has no subtitles, and the list then says `noSubtitles`.
    public static func subtitles(_ tracks: TrackList) -> [TrackRow] {
        guard !tracks.subtitles.isEmpty else { return [] }
        let offRow = TrackRow(id: offID, name: off, detail: nil, isSelected: tracks.selectedSubtitle == nil)
        return [offRow]
            + zip(tracks.subtitles.indices, tracks.subtitles).map { index, track in
                TrackRow(
                    id: track.id, name: TrackName.display(track, position: index, isForced: isForced(track)), detail: nil,
                    isSelected: track.id == tracks.selectedSubtitle)
            }
    }

    /// False for one audio track and no subtitles, when the button is grayed out.
    public static func hasChoices(_ tracks: TrackList) -> Bool {
        tracks.audio.count > 1 || !tracks.subtitles.isEmpty
    }

    /// Marked forced by the stream, or named so by the provider.
    static func isForced(_ track: MediaTrack) -> Bool {
        track.isForced || track.name?.localizedCaseInsensitiveContains("forced") == true
    }
}

extension StreamLine {
    /// The container as the stream line names it, from the address's file
    /// extension and the path that plays it: "MPEG-TS", "HLS", "MP4",
    /// "Matroska" or "AVI". Apple's player with no known extension means
    /// the bytes were HLS. Nil when it cannot tell.
    public static func container(pathExtension: String, route: EngineRouter.Route) -> String? {
        switch pathExtension.lowercased() {
        case "ts", "mts", "m2ts": "MPEG-TS"
        case "m3u8", "m3u": "HLS"
        case "mp4", "m4v", "mov": "MP4"
        case "mkv": "Matroska"
        case "avi": "AVI"
        default: route == .system ? "HLS" : nil
        }
    }
}
