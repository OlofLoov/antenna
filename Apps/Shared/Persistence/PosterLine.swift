import AntennaCore
import Foundation

/// The posters asked for ahead of the screen that wait their turn, and the
/// ones loading, at most `limit` at once
/// (movies-and-series-browsing/browsing-stays-responsive). The newest asks
/// go to the front, since they are nearest to where the viewer is now.
struct PosterLine {
    /// A poster asked for ahead.
    struct Pending {
        let url: URL
        let key: String
        let memoryKey: String
        let fit: PosterFit
        let origin: String
    }

    let limit: Int
    private(set) var waiting: [Pending] = []
    private(set) var loading: Set<String> = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// Puts `asks` at the front of the line in their order, moving up any
    /// that were already in it.
    mutating func putInFront(_ asks: [Pending]) {
        guard !asks.isEmpty else { return }
        let keys = Set(asks.map(\.memoryKey))
        waiting.removeAll { keys.contains($0.memoryKey) }
        waiting.insert(contentsOf: asks, at: 0)
    }

    /// Takes a poster out of the line for a card that asks for it now. It
    /// does not count against `limit`.
    mutating func take(_ memoryKey: String) -> Pending? {
        guard let index = waiting.firstIndex(where: { $0.memoryKey == memoryKey }) else { return nil }
        return waiting.remove(at: index)
    }

    /// The next poster to start while fewer than `limit` load, counted as
    /// loading from then on.
    mutating func next() -> Pending? {
        guard loading.count < limit, !waiting.isEmpty else { return nil }
        let next = waiting.removeFirst()
        loading.insert(next.memoryKey)
        return next
    }

    /// Forgets a poster in line or loading, once it finished or nobody wants it.
    mutating func remove(_ memoryKey: String) {
        waiting.removeAll { $0.memoryKey == memoryKey }
        loading.remove(memoryKey)
    }
}
