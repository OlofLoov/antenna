import AntennaCore
import Foundation
import Observation

/// Moving around in the movie or episode on screen, shared by every
/// platform (player-controls-and-playback-errors/move-around-in-a-movie-or-episode,
/// player-controls-and-playback-errors/the-movie-controls-show-and-hide):
/// the time the engine reports, skips, the target of a drag or a slide,
/// and when the controls show.
@MainActor @Observable
final class TitleTransport {
    struct Dependencies {
        var engine: any PlaybackEngine
        /// Moves the title to a time and returns false when its server cannot skip.
        var seek: @MainActor (Duration) async -> Bool
        /// How long the controls stay after an input while the title plays.
        var hold = TitleTransport.hold
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    }

    /// How long the controls stay after an input while playing: the Live
    /// player's 3 seconds, and 5 on Apple TV, where the bar is read from the couch.
    nonisolated static var hold: Duration {
        #if os(tvOS)
            .seconds(5)
        #else
            ControlsTimer.touchHold
        #endif
    }

    /// Said for a few seconds when the server cannot skip.
    nonisolated static let cannotSkip = "This stream can't skip"

    /// The last position the engine reported.
    private(set) var position = PlaybackPosition.zero
    private(set) var state = PlaybackState.loading
    /// Where a skip goes, until the engine is there.
    private(set) var pending: Duration?
    /// The time a drag or a slide points at, nil when none.
    private(set) var target: Duration?
    private(set) var controlsShown = true
    /// A line said for a few seconds after a refused skip.
    private var said: String?
    /// Keeps the controls up while a track list is open or VoiceOver runs.
    var held = false {
        didSet {
            if oldValue, !held, controlsShown { show(after: .touch) }
        }
    }

    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var hiding: Task<Void, Never>?
    @ObservationIgnored private var noticeTimer: Task<Void, Never>?
    @ObservationIgnored private var seeks = 0
    /// Where a slide on Apple TV started from.
    @ObservationIgnored private var slideBase: Duration?
    @ObservationIgnored private var lastInput = ControlsTimer.Input.touch

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// Follows the engine's position and state until the calling task ends.
    func follow() async {
        let engine = dependencies.engine
        show(after: .touch)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await position in await engine.position() {
                    await self.positionChanged(position)
                }
            }
            group.addTask {
                for await state in await engine.states() {
                    await self.stateChanged(state)
                }
            }
        }
    }

    func positionChanged(_ value: PlaybackPosition) {
        position = value
    }

    func stateChanged(_ value: PlaybackState) {
        let wasPaused = isPaused
        state = value
        if controlsShown, wasPaused != isPaused { show(after: lastInput) }
    }

    // MARK: Reading

    /// The time on screen and the title's length; a skip on its way counts as there.
    var timeline: TitleTimeline {
        TitleTimeline(time: pending ?? position.time, length: position.duration)
    }

    /// The time the controls show: the target of a drag or slide, or the timeline's.
    var shownTime: Duration {
        target ?? timeline.time
    }

    /// "This stream can't skip" whenever the controls show for a title
    /// whose server cannot skip, and for a few seconds after a refused
    /// skip; nil otherwise.
    var notice: String? {
        if let said { return said }
        return controlsShown && !position.canSkip ? Self.cannotSkip : nil
    }

    /// False once the engine said the title's server cannot skip.
    var canSkip: Bool {
        position.canSkip
    }

    /// True once the engine reported where the title is.
    var hasStarted: Bool {
        position.duration != nil || position.time > .zero
    }

    var isPaused: Bool {
        switch state {
        case .paused, .ended: true
        default: false
        }
    }

    /// True while a slide on Apple TV or a drag holds a target time.
    var isScrubbing: Bool {
        target != nil
    }

    // MARK: Moving

    /// Back or forward 10 seconds from what is on screen.
    func skip(forward: Bool) {
        move(to: timeline.skipped(forward: forward))
    }

    /// A finger or pointer at `fraction` of the scrubber: the shown time follows it.
    func drag(to fraction: Double) {
        guard canSkip, let time = timeline.time(at: fraction) else { return }
        target = time
    }

    /// The drag ended: one seek to where it stopped, keeping play or pause.
    func endDrag() {
        guard let target else { return }
        self.target = nil
        move(to: target)
    }

    /// A finger came down on the Apple TV touch surface. While paused it
    /// starts moving a target from the one on screen; while playing it only
    /// shows the bar.
    func beginSlide() {
        show(after: .touch)
        guard isPaused, canSkip, timeline.length != nil else { return slideBase = nil }
        slideBase = shownTime
        target = shownTime
    }

    /// The finger moved `slide` of the surface's width since it came down.
    func slide(by slide: Double) {
        show(after: .touch)
        guard let slideBase, let time = timeline.slid(from: slideBase, by: slide) else { return }
        target = time
    }

    /// The finger lifted; the target stays until select or Menu.
    func endSlide() {
        slideBase = nil
    }

    /// Left or right while a target shows on Apple TV: the target moves 10 seconds.
    func nudge(forward: Bool) {
        guard let target else { return }
        show(after: .touch)
        let offset = forward ? TitleTimeline.skip : .zero - TitleTimeline.skip
        self.target = timeline.clamped(target + offset)
    }

    /// Select or play/pause on Apple TV: plays from the target when one is
    /// set, otherwise plays or pauses.
    func select() {
        if isScrubbing {
            commit()
        } else {
            playPause()
        }
    }

    /// A click left or right on Apple TV: moves the target when one is set,
    /// otherwise skips.
    func click(forward: Bool) {
        if isScrubbing {
            nudge(forward: forward)
        } else {
            skip(forward: forward)
        }
    }

    /// Select or play/pause with a target: plays from it.
    func commit() {
        guard let target else { return }
        self.target = nil
        slideBase = nil
        move(to: target, thenPlay: true)
    }

    /// Menu with a target: it goes away and the title stays where it paused.
    func cancelScrub() {
        target = nil
        slideBase = nil
        show(after: .touch)
    }

    /// Asks the engine for `time`, then plays when `thenPlay`. Skips in a
    /// row count from the last one, and only the last one clears `pending`.
    private func move(to time: Duration, thenPlay: Bool = false) {
        show(after: .touch)
        guard canSkip else {
            if thenPlay { Task { await dependencies.engine.play() } }
            return say(Self.cannotSkip)
        }
        seeks += 1
        let mine = seeks
        pending = time
        let engine = dependencies.engine
        Task {
            let moved = await dependencies.seek(time)
            if thenPlay { await engine.play() }
            guard mine == seeks else { return }
            pending = nil
            if !moved { say(Self.cannotSkip) }
        }
    }

    /// Plays a paused title and pauses a playing one; the controls show.
    func playPause() {
        show(after: .touch)
        let engine = dependencies.engine
        let paused = isPaused
        Task { paused ? await engine.play() : await engine.pause() }
    }

    // MARK: Showing

    /// Shows the controls and hides them after the hold, unless paused, held
    /// or the pointer is over the picture.
    func show(after input: ControlsTimer.Input) {
        lastInput = input
        hiding?.cancel()
        if input != .pointerLeft { controlsShown = true }
        guard controlsShown, let delay = ControlsTimer.delay(after: input, isPaused: isPaused, touchHold: dependencies.hold) else {
            return
        }
        let sleep = dependencies.sleep
        hiding = Task { [weak self] in
            do { try await sleep(delay) } catch { return }
            guard let self, !Task.isCancelled, !held, !isScrubbing else { return }
            controlsShown = false
        }
    }

    /// A tap on the picture while the controls show.
    func hide() {
        hiding?.cancel()
        guard !held else { return }
        controlsShown = false
    }

    /// Shows the controls when hidden and hides them when shown.
    func toggle() {
        if controlsShown {
            hide()
        } else {
            show(after: .touch)
        }
    }

    private func say(_ text: String) {
        said = text
        noticeTimer?.cancel()
        let sleep = dependencies.sleep
        noticeTimer = Task { [weak self] in
            do { try await sleep(.seconds(3)) } catch { return }
            self?.said = nil
        }
    }
}
