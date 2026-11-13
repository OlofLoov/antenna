import AntennaCore
import Foundation
import Observation

/// The audio and subtitle lists of the movie or episode on screen
/// (player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode).
/// The rows and the switch follow the same rules as Live's player model.
@MainActor @Observable
final class TitleTracks {
    /// The stream's audio and subtitle tracks, as last reported.
    private(set) var tracks = TrackList.empty
    /// The picture and sound format, nil until the first frame.
    private(set) var presentation: PresentationInfo?
    /// The path that plays the title.
    private(set) var route: EngineRouter.Route
    /// The list is open on iPhone, iPad or Mac.
    var pickerOpen = false
    /// The Apple TV panel's tab, nil while it is closed.
    var panel: PanelTab?

    @ObservationIgnored private let engine: any PlaybackEngine
    @ObservationIgnored private let address: URL

    init(engine: any PlaybackEngine, address: URL) {
        self.engine = engine
        self.address = address
        route = EngineRouter.route(for: address)
    }

    /// Follows the engine's tracks and picture format until the calling task ends.
    func follow() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.followTracks() }
            group.addTask { await self.followPresentation() }
        }
    }

    private func followTracks() async {
        for await list in await engine.tracks() {
            tracks = list
        }
    }

    private func followPresentation() async {
        for await info in await engine.presentation() {
            presentation = info
            route = await currentRoute()
        }
    }

    private func currentRoute() async -> EngineRouter.Route {
        if let routed = engine as? RoutedEngine, routed.system !== routed.demuxer, let active = await routed.activeEngine {
            return active === routed.system ? .system : .demuxer
        }
        return EngineRouter.route(for: address)
    }

    // MARK: What the lists show

    var audioRows: [TrackRow] { TrackMenu.audio(tracks, presentation: presentation) }

    /// Off and the subtitle rows, empty when the title has none.
    var subtitleRows: [TrackRow] { TrackMenu.subtitles(tracks) }

    /// False for one sound and no subtitles: the button is grayed out.
    var hasTrackChoices: Bool { TrackMenu.hasChoices(tracks) }

    /// True when full subtitles are on; forced ones alone read as off.
    var subtitlesOn: Bool { TrackChoice.fullSubtitlesOn(tracks) }

    /// False when the title has no full subtitles.
    var canSwitchSubtitles: Bool { tracks.subtitles.contains { !$0.isForced } }

    /// "MP4 · H.264 1080p · AAC 5.1 · Apple player", or that details are not available yet.
    var streamLine: String {
        let container = StreamLine.container(pathExtension: address.pathExtension, route: route)
        return StreamLine.text(container: container, presentation: presentation, route: route)
    }

    // MARK: Picking

    /// Plays the audio track `id`. The list stays open.
    func selectAudio(_ id: MediaTrack.ID) {
        guard tracks.audio.contains(where: { $0.id == id }) else { return }
        Task { await engine.selectAudio(id) }
    }

    /// Shows the subtitle track `id`, or none for `TrackMenu.offID`. The list stays open.
    func selectSubtitle(_ id: String) {
        let track = id == TrackMenu.offID ? nil : id
        if let track, !tracks.subtitles.contains(where: { $0.id == track }) { return }
        Task { await engine.selectSubtitle(track) }
    }

    /// Turns subtitles off, or on in the first of `languages` the title has, else its first full track.
    func switchSubtitles(languages: [String] = Locale.preferredLanguages) {
        guard canSwitchSubtitles else { return }
        let next = TrackChoice.switched(tracks, preferred: languages)
        Task { await engine.selectSubtitle(next) }
    }

    func openPicker() {
        guard hasTrackChoices else { return }
        pickerOpen = true
    }

    func closePicker() {
        pickerOpen = false
    }
}
