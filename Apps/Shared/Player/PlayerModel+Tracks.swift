import AntennaCore
import Foundation

/// The tabs of the Apple TV info panel, in order.
enum PanelTab: Hashable, CaseIterable, Sendable {
    case info, audio, subtitles

    var title: String {
        switch self {
        case .info: "Info"
        case .audio: "Audio"
        case .subtitles: "Subtitles"
        }
    }

    /// `player.panel.segment.<identifier>`.
    var identifier: String {
        switch self {
        case .info: "info"
        case .audio: "audio"
        case .subtitles: "subtitles"
        }
    }
}

extension PlayerModel {
    /// Follows the engine's tracks and picture format until the calling
    /// task ends. `run()` does this too; Live calls it on its own because
    /// Live follows the engine's state itself.
    func observeDetails() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.observeTracks() }
            group.addTask { await self.observePresentation() }
        }
    }

    private func observeTracks() async {
        for await list in await engine.tracks() {
            tracksChanged(list)
        }
    }

    private func observePresentation() async {
        for await info in await engine.presentation() {
            await presentationChanged(info)
        }
    }

    /// The path that plays the stream on screen: the routed engine's active
    /// one, or the router's pick for the address when one engine takes both routes.
    func currentRoute() async -> EngineRouter.Route {
        if let routed = engine as? RoutedEngine, routed.system !== routed.demuxer, let active = await routed.activeEngine {
            return active === routed.system ? .system : .demuxer
        }
        return subject.map { EngineRouter.route(for: $0.channel.streamURL) } ?? .demuxer
    }

    // MARK: What the lists show

    /// The audio rows, the playing one ticked.
    var audioRows: [TrackRow] { TrackMenu.audio(tracks, presentation: presentation) }

    /// Off and the subtitle rows, empty when the stream has none.
    var subtitleRows: [TrackRow] { TrackMenu.subtitles(tracks) }

    /// False for one sound and no subtitles: the button is grayed out.
    var hasTrackChoices: Bool { TrackMenu.hasChoices(tracks) }

    /// True when full subtitles are on; forced ones alone read as off
    /// (player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step).
    var subtitlesOn: Bool { TrackChoice.fullSubtitlesOn(tracks) }

    /// False when the stream has no full subtitles, when the switch is
    /// grayed out or, on Apple TV, not shown.
    var canSwitchSubtitles: Bool { tracks.subtitles.contains { !$0.isForced } }

    /// "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player", or that details
    /// are not available yet.
    var streamLine: String {
        let container = subject.flatMap { StreamLine.container(pathExtension: $0.channel.streamURL.pathExtension, route: route) }
        return StreamLine.text(container: container, presentation: presentation, route: route)
    }

    // MARK: Picking

    /// Plays the audio track `id`. The list stays open.
    func selectAudio(_ id: MediaTrack.ID) {
        guard tracks.audio.contains(where: { $0.id == id }) else { return }
        Task { await engine.selectAudio(id) }
    }

    /// Shows the subtitle track `id`, or turns subtitles off for `TrackMenu.offID`. The list stays open.
    func selectSubtitle(_ id: String) {
        let track = id == TrackMenu.offID ? nil : id
        if let track, !tracks.subtitles.contains(where: { $0.id == track }) { return }
        Task { await engine.selectSubtitle(track) }
    }

    /// Turns subtitles off, or on in the first of `languages` the stream
    /// has, else its first full track
    /// (player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step).
    func switchSubtitles(languages: [String] = Locale.preferredLanguages) {
        guard canSwitchSubtitles else { return }
        let next = TrackChoice.switched(tracks, preferred: languages)
        Task { await engine.selectSubtitle(next) }
    }

    // MARK: Panel and picker

    /// Opens the Apple TV info panel on `tab`
    /// (player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv).
    /// Nothing opens over the error.
    func openPanel(_ tab: PanelTab = .info) {
        guard subject != nil, failure == nil else { return }
        panel = tab
    }

    func closePanel() {
        panel = nil
    }

    /// Opens the audio and subtitles list on iPhone, iPad and Mac.
    func openPicker() {
        guard subject != nil, failure == nil, hasTrackChoices else { return }
        pickerOpen = true
    }

    func closePicker() {
        pickerOpen = false
    }
}
