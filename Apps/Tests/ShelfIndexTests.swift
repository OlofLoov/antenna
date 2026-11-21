import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The section's index is built off the main actor and shows together with
/// the source's loaded state (movies-and-series-browsing/browsing-stays-responsive).
@MainActor
@Suite struct ShelfIndexTests {
    let source = UUID()
    let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func model(count: Int) -> ShelfModel {
        let titles = (0..<count).map { index in
            ShelfTitle(
                id: "xtream#h#vod#\(index)", kind: .movie, sourceID: source, name: "Movie \(index)",
                added: base.addingTimeInterval(Double(index)), category: "C\(index % 20)")
        }
        let dependencies = ShelfModel.Dependencies(
            load: { _, _ in ShelfCatalogue(titles: titles, categories: (0..<20).map { "C\($0)" }) },
            hasLogin: { _ in true },
            info: { _, _ in .movie(VODInfo()) })
        let model = ShelfModel(kind: .movie, dependencies)
        model.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        return model
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the loaded state, rows and banner show together")
    func stateWaitsForTheIndex() async {
        let model = model(count: 20_000)
        model.open()
        var sawStateWithoutRows = false
        while model.sources.first?.state == .loading {
            await Task.yield()
        }
        if case .loaded = model.sources.first?.state, model.rows.isEmpty { sawStateWithoutRows = true }
        await model.settled()
        #expect(!sawStateWithoutRows)
        #expect(model.sources.first?.state == .loaded(titles: 20_000))
        #expect(model.titles.count == 20_000)
        #expect(model.banner.first?.name == "Movie 19999")
        #expect(model.rows.count == 21)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a grid's order is kept until the titles change")
    func gridOrderIsKept() async {
        let model = model(count: 500)
        model.open()
        await model.settled()
        let byTitle = model.titles(sortedBy: .title)
        #expect(byTitle == Shelf.sorted(model.titles, by: .title))
        #expect(model.titles(sortedBy: .recentlyAdded)?.first?.name == "Movie 499")
        #expect(model.titles(in: "C3", sortedBy: .recentlyAdded)?.allSatisfy { $0.category == "C3" } == true)
        #expect(model.title(ActivityKey(titleID: "xtream#h#vod#7", sourceID: source))?.name == "Movie 7")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a long list in Title or Year order sorts away from the main actor, once")
    func longListsSortAway() async {
        let model = model(count: 5_000)
        model.open()
        await model.settled()
        #expect(model.titles(sortedBy: .title) == nil, "the grid waits for the order")
        async let first: Void = model.sort(in: nil, by: .title)
        async let second: Void = model.sort(in: nil, by: .title)
        _ = await (first, second)
        #expect(model.titles(sortedBy: .title) == Shelf.sorted(model.titles, by: .title))
        #expect(model.sortedAway == 1, "two grids asking share one sort")
        await model.sort(in: nil, by: .title)
        #expect(model.sortedAway == 1, "a kept order is not sorted again")
        #expect(model.titles(sortedBy: .recentlyAdded)?.count == 5_000, "newest first needs no sort")
    }
}
