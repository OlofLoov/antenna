import AntennaCore
import Foundation
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    @MainActor @Suite struct GuideBoardModelTests {
        let source = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        func defaults() -> UserDefaults {
            let name = "guide-board-tests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name) ?? .standard
            defaults.removePersistentDomain(forName: name)
            return defaults
        }

        var channel: Channel {
            Channel.tagged([Channel(id: "c1", name: "Sport One", streamURL: URL(fileURLWithPath: "/s.ts"), epgID: "s1")], sourceID: source)[
                0]
        }

        func cells(programme: Bool) -> (RowKey, DateInterval) -> [GuideCell] {
            { _, window in
                let segment = GuideSegment(
                    start: start, stop: start.addingTimeInterval(3600),
                    programme: programme
                        ? Programme(channelID: "s1", start: start, stop: start.addingTimeInterval(3600), title: "Match") : nil)
                return window.intersects(DateInterval(start: segment.start, end: segment.stop)) ? [GuideCell(segment: segment)] : []
            }
        }

        @Test("guide-on-iphone-ipad-and-mac/open-at-a-programme a found programme opens its day and details")
        func found() throws {
            let key = try #require(RowKey(channel))
            let request = ProgrammeKey(guideKey: GuideKey(sourceID: source, epgID: "s1"), start: start.addingTimeInterval(60))
            let target = GuideBoardModel.target(for: request, rows: [key], channel: { _ in channel }, cells: cells(programme: true))
            #expect(target == GuideTarget(key: key, start: start))
            let model = GuideBoardModel(store: GuideZoomStore(defaults: defaults()))
            model.filter = "spo"
            model.open(at: target, playing: nil)
            #expect(model.details == target)
            #expect(model.time == start)
            #expect(model.filter.isEmpty)
        }

        @Test("guide-on-iphone-ipad-and-mac/open-at-a-programme a programme that cannot be found opens at now")
        func notFound() throws {
            let key = try #require(RowKey(channel))
            let missing = ProgrammeKey(guideKey: GuideKey(sourceID: source, epgID: "other"), start: start)
            #expect(GuideBoardModel.target(for: missing, rows: [key], channel: { _ in channel }, cells: cells(programme: true)) == nil)
            let loading = ProgrammeKey(guideKey: GuideKey(sourceID: source, epgID: "s1"), start: start)
            #expect(GuideBoardModel.target(for: loading, rows: [key], channel: { _ in channel }, cells: cells(programme: false)) == nil)
            let model = GuideBoardModel(store: GuideZoomStore(defaults: defaults()))
            model.time = start
            model.open(at: nil, playing: nil)
            #expect(model.details == nil)
            #expect(model.time == nil)
            #expect(model.jump?.place == .now(row: nil))
        }

        @Test("guide-on-iphone-ipad-and-mac/zoom the step is kept per device")
        func zoomKept() {
            let store = GuideZoomStore(defaults: defaults())
            let model = GuideBoardModel(store: store)
            #expect(model.zoom == GuideZoom())
            model.zoomIn()
            #expect(store.load().scale.columnWidth == 270)
            #expect(GuideBoardModel(store: store).zoom.scale.columnWidth == 270)
            model.pinched(by: 0.3, at: 100)
            #expect(store.load().scale.columnWidth == 90)
            #expect(model.zoomAnchor == .point(100))
        }

        @Test("guide-on-iphone-ipad-and-mac/channels-with-gaps-or-no-guide a dismissed banner comes back on a new failure")
        func bannerReturns() {
            let model = GuideBoardModel(store: GuideZoomStore(defaults: defaults()))
            model.dismissBanner(source)
            model.failedSourcesChanged(to: [source])
            #expect(model.dismissedBanners.contains(source), "the same failure stays dismissed")
            model.failedSourcesChanged(to: [])
            model.failedSourcesChanged(to: [source])
            #expect(!model.dismissedBanners.contains(source))
        }

        @Test("guide-on-iphone-ipad-and-mac/filter-channels-by-typing the guide narrows by name or number as Live's list does")
        func filterMatchesLive() async throws {
            let channels = ["News One", "Sport One", "Sport Two"].enumerated().map { index, name in
                Channel(id: "c\(index)", name: name, streamURL: URL(filePath: "/\(index).ts"), group: "G", number: index + 1)
            }
            let live = LiveModel(
                .init(
                    engine: UITestingLive.Engine(log: nil), load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true },
                    guide: nil, programmes: UITestingLive.guide))
            live.sourcesChanged([SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(filePath: "/home.m3u"))])
            await live.settled()
            let model = GuideBoardModel(store: GuideZoomStore(defaults: defaults()))
            let reading = GuideBoardReading(live: live, model: model)
            func names(filtered: Bool = true) -> [String] {
                reading.data(at: start, filtered: filtered).rows.compactMap { live.catalogue.channel(for: $0)?.name }
            }
            model.filter = "SPORT"
            #expect(names() == ["Sport One", "Sport Two"])
            #expect(names(filtered: false) == ["News One", "Sport One", "Sport Two"])
            model.filter = "3"
            #expect(names() == ["Sport Two"])
            live.filter = "3"
            #expect(reading.data(at: start, filtered: true).rows == live.rows)
            let sport = try #require(live.channels.first { $0.name == "Sport One" })
            live.favoritesChanged([FavoriteSnapshot(channelID: sport.id, sourceID: source, sortOrder: 0)])
            live.show(.favorites)
            model.filter = "one"
            #expect(names() == ["Sport One"], "a favorite added after loading is found too")
        }
    }
#endif
