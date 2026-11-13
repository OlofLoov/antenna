import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The Apple TV tab bar with playlists that have movies, episodes or neither.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ShellTitleOfferTests {
    let loader = ScriptedLoader()
    let defaults: UserDefaults
    let playlist = SourceDescriptor(name: "Playlist", kind: .m3u, url: URL(fileURLWithPath: "/playlist.m3u"))

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "shell-offer-\(UUID().uuidString)"))
    }

    private func model(stored: TitleCounts? = nil) -> ShellModel {
        let loader = loader
        var dependencies = ShellModel.Dependencies(
            engine: RecordingEngine(), load: { try await loader.load($0) }, hasLogin: { _ in true },
            recents: RecentsStore(defaults: defaults), sleep: { _ in try await Task.sleep(for: .seconds(3600)) }, guide: nil)
        dependencies.storedTitles = { _ in stored }
        return ShellModel(dependencies)
    }

    private func loaded(_ model: ShellModel, movies: Int, episodes: Int) async {
        for _ in 0..<5000 where !loader.isWaiting(playlist.id) { await Task.yield() }
        let entry = Channel.fixture("vod")
        loader.finish(
            playlist.id,
            with: Playlist(
                channels: [Channel.fixture("1")], movies: Array(repeating: entry, count: movies),
                episodes: Array(repeating: entry, count: episodes)))
        for _ in 0..<5000 where model.sources.first?.state == .loading { await Task.yield() }
    }

    @Test("m3u-playlists/movies-and-series-show-by-what-the-sources-offer: a playlist of episodes shows Series and not Movies")
    func episodesOnly() async {
        let model = model()
        model.sourcesChanged([playlist])
        #expect(model.tabs == [.live, .guide, .search])
        await loaded(model, movies: 0, episodes: 3)
        #expect(model.tabs == [.live, .guide, .series, .search])
        #expect(ShellTab.titles(model.titleOffer) == .series)
    }

    @Test("m3u-playlists/movies-and-series-show-by-what-the-sources-offer: a playlist of movies shows Movies and not Series")
    func moviesOnly() async {
        let model = model()
        model.sourcesChanged([playlist])
        await loaded(model, movies: 2, episodes: 0)
        #expect(model.tabs == [.live, .guide, .movies, .search])
        #expect(ShellTab.titles(model.titleOffer) == .movies)
    }

    @Test("m3u-playlists/movies-and-series-show-by-what-the-sources-offer: an Xtream source shows both before it answers")
    func xtream() {
        let model = model()
        model.sourcesChanged([SourceDescriptor(name: "X", kind: .xtream, url: URL(fileURLWithPath: "/x"), credentialKey: "k")])
        #expect(model.tabs == [.live, .guide, .movies, .series, .search])
    }

    @Test("m3u-playlists/what-a-playlist-offered-is-remembered: the tabs show from the stored counts before the playlist loads")
    func remembered() {
        let model = model(stored: TitleCounts(movies: 0, episodes: 4))
        model.sourcesChanged([playlist])
        #expect(model.tabs == [.live, .guide, .series, .search])
    }

    @Test("m3u-playlists/movies-and-series-show-by-what-the-sources-offer: Series open when the playlist loses its episodes shows Live")
    func losesTitles() async {
        let model = model(stored: TitleCounts(movies: 0, episodes: 4))
        model.sourcesChanged([playlist])
        _ = await model.select(.series)
        await loaded(model, movies: 0, episodes: 0)
        for _ in 0..<5000 where model.tab != .live { await Task.yield() }
        #expect(model.tab == .live)
        #expect(!model.tabs.contains(.series))
    }
}
