import AntennaCore
import Foundation
import Observation
import SwiftUI

/// The movie or series the profile watched last on this device, from
/// launch until its page opens or it gives way
/// (session-restore-and-recently-watched/reopen-on-the-title-watched-last,
/// session-restore-and-recently-watched/a-title-that-cannot-open-gives-way).
@MainActor @Observable
final class LaunchTitle {
    /// How long the title waits for its section to list it.
    static let deadline = Duration.seconds(10)

    /// The title while its section has not listed it.
    private(set) var waiting: LastWatched.Title?
    /// True from launch until the page opened or the title gave way. Apple
    /// TV's launch tune waits while it is true.
    private(set) var holds = false
    /// Runs when the title gives way, so the launch goes on without it.
    @ObservationIgnored var dropped: @MainActor () -> Void = {}
    @ObservationIgnored private var timer: Task<Void, Never>?

    init(_ title: LastWatched.Title? = nil) {
        waiting = title
        holds = title != nil
    }

    /// Starts waiting for `title`.
    func wait(for title: LastWatched.Title) {
        waiting = title
        holds = true
    }

    /// Gives the title up `deadline` after this call unless its section
    /// lists it first. `sleep` waits as the caller's clock does.
    func start(sleep: @escaping @MainActor (Duration) async throws -> Void) {
        guard waiting != nil, timer == nil else { return }
        timer = Task { [weak self] in
            do {
                try await sleep(Self.deadline)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, waiting != nil else { return }
            drop()
        }
    }

    /// The listed title once its section has it. The title gives way when
    /// its section has loaded its source without it, or the source failed,
    /// is offline or waits for its login. Until the section has opened and
    /// knows the source, it waits.
    func resolve(in library: ShelfLibrary) -> ShelfTitle? {
        guard let key = waiting else { return nil }
        let shelf = library.model(key.shelfKind)
        if let title = shelf.title(key.activityKey) {
            waiting = nil
            timer?.cancel()
            timer = nil
            return title
        }
        guard shelf.opened, let row = shelf.sources.first(where: { $0.id == key.sourceID }), row.state != .loading else { return nil }
        drop()
        return nil
    }

    /// The page opened; nothing waits on the title any more.
    func opened() {
        waiting = nil
        holds = false
    }

    /// The title gives way, if it still holds.
    func drop() {
        guard holds else { return }
        waiting = nil
        holds = false
        timer?.cancel()
        timer = nil
        dropped()
    }
}

extension LastWatched.Title {
    /// The iPhone, iPad and Mac tab the title's page shows over.
    var tab: LiveSession.Tab {
        kind == .movie ? .movies : .series
    }
}

extension ShelfLibrary {
    /// Opens `title`'s page over its section as More info on the banner
    /// would, so Back shows the section's rows. A series shows the season of
    /// `episode` once its episodes are known.
    func reopen(_ title: ShelfTitle, episode: String?) {
        openPage(title, from: .banner, in: title.kind)
        if let episode { page?.model.reopen(at: episode) }
    }
}

extension ShelfPlayback {
    /// Writes each movie or episode that starts to `store`, the current
    /// profile's, as what was watched last
    /// (session-restore-and-recently-watched/what-was-watched-last).
    func recordsWatched(in store: RecentsStore) {
        watched = { target in
            guard let title = target.lastWatched else { return }
            store.write(LastWatched(title: title))
        }
    }
}

extension ShelfPlayback.Target {
    /// The movie, or the series with the episode; nil for a trailer.
    var lastWatched: LastWatched.Title? {
        switch self {
        case .movie(let movie): LastWatched.Title(movie: movie)
        case .episode(let episode, let series): LastWatched.Title(episode: episode, of: series)
        case .trailer: nil
        }
    }
}

/// Opens the title the profile watched last once its section lists it.
/// While it waits, both sections load and every change to their sources
/// or titles is checked. `open` gets the title and what was stored of it,
/// and calls `opened()` or `drop()` on `launch`.
struct LaunchTitleRestore: ViewModifier {
    let launch: LaunchTitle
    let library: ShelfLibrary
    let open: @MainActor (ShelfTitle, LastWatched.Title) -> Void

    private struct Inputs: Equatable {
        var revisions: [Int] = []
        var states: [ShelfSourceState] = []
        var opened: [Bool] = []
    }

    /// Read only while a title waits, so a launch without one observes nothing.
    private var inputs: Inputs {
        guard launch.waiting != nil else { return Inputs() }
        let shelves = [library.movies, library.series]
        return Inputs(
            revisions: shelves.map(\.indexRevision), states: shelves.flatMap { $0.sources.map(\.state) }, opened: shelves.map(\.opened))
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: launch.waiting, initial: true) {
                guard launch.waiting != nil else { return }
                library.open()
                resolve()
            }
            .onChange(of: inputs) { resolve() }
    }

    private func resolve() {
        guard let key = launch.waiting, let title = launch.resolve(in: library) else { return }
        open(title, key)
    }
}
