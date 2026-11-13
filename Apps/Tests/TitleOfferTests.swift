import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The one rule for which on-demand sections a device offers, and the counts
/// it remembers between launches.
@MainActor
@Suite struct TitleOfferTests {
    let xtream = UUID()
    let playlist = UUID()
    let file = UUID()

    @Test("m3u-playlists/movies-and-series-show-by-what-the-sources-offer: an Xtream source offers both before it answers")
    func xtreamOffersBoth() {
        let offer = TitleOffer([(xtream, .xtream)]) { _ in nil }
        #expect(offer == TitleOffer(movies: true, series: true))
    }

    @Test("m3u-playlists/movies-and-series-show-by-what-the-sources-offer: a playlist offers by what its last load had")
    func playlistByCounts() {
        let counts: [UUID: TitleCounts] = [playlist: TitleCounts(movies: 0, episodes: 3), file: TitleCounts(movies: 2, episodes: 0)]
        #expect(TitleOffer([(playlist, .m3u)]) { counts[$0] } == TitleOffer(movies: false, series: true))
        #expect(TitleOffer([(file, .m3uFile)]) { counts[$0] } == TitleOffer(movies: true, series: false))
        #expect(TitleOffer([(playlist, .m3u), (file, .m3uFile)]) { counts[$0] } == TitleOffer(movies: true, series: true))
    }

    @Test("m3u-playlists/playlist-titles-show-on-every-platform: a playlist without titles, or another kind, offers nothing")
    func nothingOffered() {
        let empty = TitleCounts(movies: 0, episodes: 0)
        #expect(!TitleOffer([(playlist, .m3u)]) { _ in empty }.any)
        #expect(!TitleOffer([(playlist, .m3u)]) { _ in nil }.any)
        #expect(!TitleOffer([(playlist, .stalker)]) { _ in TitleCounts(movies: 5, episodes: 5) }.any)
    }

    @Test("m3u-playlists/what-a-playlist-offered-is-remembered: a playlist's counts come back after a relaunch, and go with the source")
    func remembered() async throws {
        let defaults = try #require(UserDefaults(suiteName: "title-offer-\(UUID().uuidString)"))
        let source = SourceDescriptor(name: "P", kind: .m3u, url: URL(fileURLWithPath: "/p.m3u"))
        let entry = Channel(id: "e", name: "Show S01E01", streamURL: URL(fileURLWithPath: "/e.mkv"))
        var dependencies = SourceRefresher.Dependencies(
            load: { _ in Playlist(channels: [], movies: [], episodes: [entry, entry]) }, hasLogin: { _ in true })
        dependencies.lastLoads = LastLoadStore(defaults: defaults)
        _ = try await SourceRefresher(dependencies).load(source)

        let relaunched = SourceRefresher(dependencies)
        #expect(relaunched.status(of: source.id).titleCounts == TitleCounts(movies: 0, episodes: 2))
        let offer = TitleOffer([(source.id, .m3u)]) { relaunched.status(of: $0).titleCounts }
        #expect(offer == TitleOffer(movies: false, series: true))

        relaunched.forget(source.id)
        #expect(relaunched.status(of: source.id).titleCounts == nil)
    }

    @Test("m3u-playlists/what-a-playlist-offered-is-remembered: Movies or Series reopen only when offered")
    func restoredSection() {
        let series = TitleOffer(movies: false, series: true)
        #expect(LiveSection(LiveSession.Tab.series, offer: series) == .series)
        #expect(LiveSection(LiveSession.Tab.movies, offer: series) == .live)
        #expect(!LiveSection.movies.isOffered(by: series))
        #expect(LiveSection(LiveSession.Tab.series, offer: .none) == .live)
    }

    @Test("m3u-playlists/playlist-titles-show-on-every-platform: Open on launch Movies opens Series when only series are offered")
    func launchSection() {
        let series = TitleOffer(movies: false, series: true)
        #expect(LiveSection(AppPreferences.LaunchScreen.movies, offer: series) == .series)
        #expect(LiveSection(AppPreferences.LaunchScreen.movies, offer: TitleOffer(movies: true, series: true)) == .movies)
        #expect(LiveSection(AppPreferences.LaunchScreen.live, offer: series) == nil)
    }
}
