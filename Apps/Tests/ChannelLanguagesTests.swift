import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// An engine whose track list the test sets.
@MainActor
private final class TracksEngine: PlaybackEngine {
    let cast = Broadcast(TrackList.empty)

    var state: PlaybackState { .playing }
    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }
    func load(_ url: URL, options: PlaybackOptions) async throws {}
    func play() async {}
    func pause() async {}
    func stop() async {}
    func seek(to time: Duration) async throws {}
    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}
    func states() async -> AsyncStream<PlaybackState> { Broadcast(PlaybackState.playing).stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
    func tracks() async -> AsyncStream<TrackList> { cast.stream() }
    func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }
}

/// The language pick kept per channel under `player.languages`.
@MainActor
@Suite struct ChannelLanguagesTests {
    let defaults: UserDefaults
    let source = UUID()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "ChannelLanguagesTests-\(UUID().uuidString)"))
    }

    private func channel(_ id: String) throws -> Channel {
        let link = try #require(URL(string: "http://provider.example/live/user/secret/\(id).ts"))
        return Channel(id: id, name: id, streamURL: link, sourceID: source)
    }

    private func tracks(audio: String, subtitle: String?) -> TrackList {
        TrackList(
            audio: [
                MediaTrack(id: "audio-0", kind: .audio, languageCode: "eng", name: nil, isDefault: true),
                MediaTrack(id: "audio-1", kind: .audio, languageCode: "ger", name: nil, isDefault: false),
            ],
            subtitles: [MediaTrack(id: "subtitle-0", kind: .subtitle, languageCode: "swe", name: nil, isDefault: false)],
            selectedAudio: audio, selectedSubtitle: subtitle)
    }

    @Test("playback-engine/audio-and-subtitle-languages returning to a channel starts with the languages picked on it")
    func keepsPicksPerChannel() async throws {
        let store = ChannelLanguageStore(defaults: defaults)
        let languages = ChannelLanguages(store: store)
        let engine = TracksEngine()
        languages.watch(engine)
        let sport = try channel("sport")
        #expect(languages.options(for: sport).remembered == nil)
        engine.cast.send(tracks(audio: "audio-0", subtitle: nil))
        try await Task.sleep(for: .milliseconds(100))
        #expect(store.pick(for: sport) == nil, "the starting choice is not a pick")
        engine.cast.send(tracks(audio: "audio-1", subtitle: "subtitle-0"))
        #expect(await eventually { store.pick(for: sport) == LanguagePick(audio: "ger", subtitle: "swe") })

        let news = try channel("news")
        #expect(languages.options(for: news).remembered == nil, "the next channel chooses by preference again")
        engine.cast.send(.empty)
        engine.cast.send(tracks(audio: "audio-0", subtitle: nil))
        #expect(languages.options(for: sport).remembered == LanguagePick(audio: "ger", subtitle: "swe"))
        languages.stopWatching()

        let stored = try #require(defaults.data(forKey: ChannelLanguageStore.key))
        let text = try #require(String(data: stored, encoding: .utf8))
        #expect(!text.contains("provider.example") && !text.contains("secret"), "no stream link is stored")
    }

    @Test("playback-engine/audio-and-subtitle-languages channels whose id holds their link are not kept")
    func linkIDsAreNotKept() throws {
        let store = ChannelLanguageStore(defaults: defaults)
        let link = try #require(URL(string: "http://provider.example/live/a.ts"))
        let m3u = Channel(id: link.absoluteString, name: "A", streamURL: link, sourceID: source)
        store.remember(LanguagePick(audio: "ger", subtitle: nil), for: m3u)
        #expect(store.pick(for: m3u) == nil)
        #expect(defaults.data(forKey: ChannelLanguageStore.key) == nil)
        defaults.set(Data("not json".utf8), forKey: ChannelLanguageStore.key)
        #expect(store.memory == LanguageMemory(), "a value that fails to decode reads as absent")
    }
}
