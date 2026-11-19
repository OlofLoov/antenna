import AntennaCore
import Foundation

/// `Caches/people/credits.json`: the cast and directors from info answers,
/// so person pages list those titles after a restart
/// (browse-by-person/names-the-provider-sent-are-kept). Names are provider
/// text, never a login or a stream link. Never synced; losing the file only
/// thins the person pages.
struct PeopleStore: Sendable {
    let file: URL

    static let live = PeopleStore(file: URL.cachesDirectory.appending(path: "people/credits.json"))

    /// What the file holds, without entries older than 30 days; empty when
    /// there is no file or it does not decode. Read off the main actor.
    @concurrent
    func load() async -> LearnedCredits {
        guard let data = try? Data(contentsOf: file) else { return LearnedCredits() }
        return LearnedCredits.decode(data, now: .now)
    }

    /// Replaces the file. A failed write is left for the next one.
    @concurrent
    func save(_ data: Data) async {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
