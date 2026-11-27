import Foundation
import Testing

@testable import AntennaCore

@Suite struct PlayRequestMatchTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let source = UUID()
    /// Stands in for the app's hash: any function both ends share works.
    static func key(_ id: String) -> String { "k-" + String(id.reversed()) }

    static let sport = Channel(
        id: "m3u#http://panel.example/live/u/p/1.ts#0", name: "Sport One", streamURL: URL(filePath: "/panel/1.ts"),
        hasCatchup: true, sourceID: source, position: 0)
    static let news = Channel(
        id: "xtream#panel.example#2", name: "News", streamURL: URL(filePath: "/panel/2.ts"), sourceID: source, position: 1)
    static let other = Channel(
        id: "xtream#panel.example#2", name: "News elsewhere", streamURL: URL(filePath: "/b/2.ts"), sourceID: UUID(),
        position: 0)
    static let film = ShelfTitle(id: "xtream#panel.example#vod#9", kind: .movie, sourceID: source, name: "Salt Road")
    static let show = ShelfTitle(id: "xtream#panel.example#series#4", kind: .series, sourceID: source, name: "Harbour")

    static func request(_ item: PlayRequest.Item) -> PlayRequest {
        PlayRequest(
            sender: UUID(), senderName: "Anna's iPhone", target: UUID(), source: source, item: item, displayTitle: "x", created: now)
    }

    static func resolve(
        _ item: PlayRequest.Item, source state: PlayRequestMatch.Source = .loaded, titles: [ShelfTitle]? = [film, show]
    ) -> PlayRequestMatch.Outcome {
        PlayRequestMatch.resolve(request(item), source: state, channels: [other, sport, news], titles: titles, now: now, key: key)
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: a channel, a film and an episode are found by key in their source")
    func finds() {
        #expect(Self.resolve(.channel(key: Self.key(Self.news.id))) == .play(.channel(Self.news)))
        #expect(Self.resolve(.movie(key: Self.key(Self.film.id))) == .play(.movie(Self.film)))
        #expect(
            Self.resolve(.episode(seriesKey: Self.key(Self.show.id), episodeKey: "e1")) == .play(.episode(Self.show, episodeKey: "e1")))
    }

    @Test("play-on-apple-tv/play-on-from-what-can-be-played: a programme on now plays live, an ended one plays catch-up from its start")
    func programmes() {
        let key = Self.key(Self.sport.id)
        let onNow = PlayRequest.Item.programme(
            channelKey: key, start: Self.now.addingTimeInterval(-60), end: Self.now.addingTimeInterval(60))
        #expect(Self.resolve(onNow) == .play(.channel(Self.sport)))
        let start = Self.now.addingTimeInterval(-7200), end = Self.now.addingTimeInterval(-3600)
        #expect(Self.resolve(.programme(channelKey: key, start: start, end: end)) == .play(.catchup(Self.sport, start: start, end: end)))
        // A channel without catch-up cannot play an ended programme.
        #expect(Self.resolve(.programme(channelKey: Self.key(Self.news.id), start: start, end: end)) == .refuse(.notFound))
    }

    @Test("play-on-apple-tv/the-phone-says-why-the-tv-cannot-play: each missing piece answers in its own words")
    func refusals() {
        let channel = PlayRequest.Item.channel(key: Self.key(Self.news.id))
        #expect(Self.resolve(channel, source: .missing) == .refuse(.noSource(source: Self.source)))
        #expect(Self.resolve(channel, source: .noLogin) == .refuse(.noLogin(source: Self.source)))
        #expect(Self.resolve(.channel(key: "gone")) == .refuse(.notFound))
        #expect(Self.resolve(.movie(key: "gone")) == .refuse(.notFound))
        // Another source's channel with the same id is not a match.
        #expect(Self.resolve(.channel(key: Self.key("xtream#panel.example#3"))) == .refuse(.notFound))
    }

    @Test("play-on-apple-tv/the-phone-says-why-the-tv-cannot-play: while the source loads, nothing found yet waits")
    func waits() {
        #expect(Self.resolve(.channel(key: "gone"), source: .loading) == .wait)
        #expect(Self.resolve(.movie(key: Self.key(Self.film.id)), titles: nil) == .wait)
        #expect(Self.resolve(.channel(key: Self.key(Self.news.id)), source: .loading) == .play(.channel(Self.news)))
    }
}
