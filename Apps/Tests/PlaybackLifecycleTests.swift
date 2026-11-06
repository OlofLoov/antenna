import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// An engine that records play and pause and lets the test set its state.
@MainActor
final class LifecycleEngine: PlaybackEngine {
    var current: PlaybackState = .idle
    private(set) var calls: [String] = []

    var state: PlaybackState { current }
    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: true) }

    func load(_ url: URL, options: PlaybackOptions) async throws {}

    func play() async {
        calls.append("play")
        current = .playing
    }

    func pause() async {
        calls.append("pause")
        current = .paused
    }

    func stop() async { current = .idle }
    func seek(to time: Duration) async throws {}
    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}
    func states() async -> AsyncStream<PlaybackState> { Broadcast(current).stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
    func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
    func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }
}

@MainActor
@Suite struct PlaybackLifecycleTests {
    let engine = LifecycleEngine()

    func lifecycle(pictureInPicture: Bool = false, pausesInBackground: Bool = true) -> PlaybackLifecycle {
        PlaybackLifecycle(engine: engine, continuesInBackground: { pictureInPicture }, pausesInBackground: pausesInBackground)
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture leaving the app pauses and returning plays")
    func leavingTheApp() async {
        let lifecycle = lifecycle()
        engine.current = .playing
        await lifecycle.enteredBackground()
        #expect(engine.state == .paused)
        await lifecycle.becameActive()
        #expect(engine.calls == ["pause", "play"])
    }

    @Test(
        "playback-engine/leaving-the-app-phone-calls-and-picture-in-picture loading or reconnecting stops trying in the background",
        arguments: [PlaybackState.loading, .reconnecting(attempt: 2, of: 8), .buffering])
    func stopsTryingInTheBackground(state: PlaybackState) async {
        let lifecycle = lifecycle()
        engine.current = state
        await lifecycle.enteredBackground()
        #expect(engine.calls == ["pause"])
        await lifecycle.becameActive()
        #expect(engine.calls == ["pause", "play"])
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture a pause the user made stands after returning")
    func userPauseStands() async {
        let lifecycle = lifecycle()
        engine.current = .paused
        await lifecycle.enteredBackground()
        await lifecycle.becameActive()
        #expect(engine.calls.isEmpty)
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture Picture in Picture keeps playing")
    func pictureInPictureKeepsPlaying() async {
        let lifecycle = lifecycle(pictureInPicture: true)
        engine.current = .playing
        await lifecycle.enteredBackground()
        await lifecycle.becameActive()
        #expect(engine.calls.isEmpty)
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture a Mac does not pause in the background")
    func macKeepsPlaying() async {
        let lifecycle = lifecycle(pausesInBackground: false)
        engine.current = .playing
        await lifecycle.enteredBackground()
        #expect(engine.calls.isEmpty)
        #if os(macOS)
            #expect(!PlaybackLifecycle.platformPausesInBackground)
        #else
            #expect(PlaybackLifecycle.platformPausesInBackground)
        #endif
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture a call pauses and its end plays again when allowed")
    func interruptions() async {
        let lifecycle = lifecycle()
        engine.current = .playing
        await lifecycle.handle(.began)
        #expect(engine.state == .paused)
        await lifecycle.handle(.ended(shouldResume: true))
        #expect(engine.calls == ["pause", "play"])
        await lifecycle.handle(.began)
        await lifecycle.handle(.ended(shouldResume: false))
        #expect(engine.calls == ["pause", "play", "pause"])
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture a call while paused by the user resumes nothing")
    func interruptionWhilePaused() async {
        let lifecycle = lifecycle()
        engine.current = .paused
        await lifecycle.handle(.began)
        await lifecycle.handle(.ended(shouldResume: true))
        #expect(engine.calls.isEmpty)
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture unplugging headphones pauses and nothing resumes it")
    func headphones() async {
        let lifecycle = lifecycle()
        engine.current = .playing
        await lifecycle.handle(.began)
        await lifecycle.headphonesUnplugged()
        await lifecycle.handle(.ended(shouldResume: true))
        await lifecycle.becameActive()
        #expect(engine.calls == ["pause"])
        engine.current = .playing
        await lifecycle.headphonesUnplugged()
        #expect(engine.calls == ["pause", "pause"])
    }
}
