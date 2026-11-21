import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// A series' episode list comes from its one info call, shared with the
/// banner, the preview and the page, and is let go with that answer unless
/// the series has saved progress.
@MainActor
@Suite struct ShelfEpisodesTests {
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AE01") ?? UUID()

    private func series(_ number: Int) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#\(number)", kind: .series, sourceID: source, name: "Series \(number)")
    }

    private func model(count: Int, calls: Counter, failing: Set<Int> = []) async -> ShelfModel {
        let titles = (0..<count).map(series)
        let dependencies = ShelfModel.Dependencies(
            load: { _, _ in ShelfCatalogue(titles: titles, categories: []) },
            hasLogin: { _ in true },
            info: { _, title in
                calls.value += 1
                let number = XtreamTitleID(parsing: title.id)?.rawID ?? 0
                if failing.contains(number) { throw URLError(.timedOut) }
                return .series(
                    SeriesInfo(episodes: [Episode(id: "\(title.id)-e1", episodeID: number, season: 1, number: 1, title: "E1")]))
            })
        let model = ShelfModel(kind: .series, dependencies)
        model.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        model.open()
        await model.settled()
        return model
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title a Continue watching card and the series' page ask once")
    func cardThenPage() async throws {
        let calls = Counter()
        let model = await model(count: 3, calls: calls)
        await model.prefetchEpisodes(series(1))
        #expect(model.episodes[series(1).id]?.count == 1)
        let info = try await model.info(series(1))
        guard case .series(let answer) = info else {
            Issue.record("a series answers with series info")
            return
        }
        #expect(answer.episodes.count == 1)
        #expect(calls.value == 1, "the page reads the answer the card's list came from")
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title a card whose list failed does not ask again on scrolling back")
    func failedCardWaitsForPlay() async {
        let calls = Counter()
        let model = await model(count: 3, calls: calls, failing: [2])
        await model.prefetchEpisodes(series(2))
        await model.prefetchEpisodes(series(2))
        #expect(calls.value == 1)
        _ = try? await model.loadEpisodes(series(2))
        #expect(calls.value == 2, "Play asks again")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive episode lists past the kept answers go, except for series with progress")
    func listsAreLetGo() async {
        let calls = Counter()
        let count = ShelfModel.keptLimit + 20
        let model = await model(count: count, calls: calls)
        model.keepsEpisodes = { $0 == "xtream#h#series#0" }
        for number in 0..<count { await model.loadDetails(series(number)) }
        #expect(model.episodes.count == ShelfModel.keptLimit + 1, "the latest 100 and the one with progress")
        #expect(model.episodes[series(0).id] != nil, "a series with progress keeps its list")
        #expect(model.episodes[series(1).id] == nil)
        #expect(model.episodes[series(count - 1).id] != nil)
    }
}
