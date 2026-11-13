#if os(tvOS)
    import AntennaCore
    import Observation
    import SwiftUI

    /// Shelf links wait here, outside every gate, until the shell takes
    /// them. A link that arrives while the paywall or setup shows, or that
    /// is still waiting when one appears, is dropped, so buying or adding a
    /// source then launches normally (top-shelf/the-paywall-and-setup-come-first).
    @MainActor @Observable
    final class TopShelfInbox {
        /// The tile's item, until the shell takes it.
        private(set) var pending: UUID?
        @ObservationIgnored private var gates = 0

        /// Keeps a channel or title link. The add-favorites tile and a
        /// damaged link open Antenna as it was
        /// (top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was).
        func receive(_ url: URL) {
            guard gates == 0, case .item(let id) = TopShelfLink(url: url) else { return }
            pending = id
        }

        func take() -> UUID? {
            defer { pending = nil }
            return pending
        }

        /// The paywall or setup appeared.
        func gateShown() {
            gates += 1
            pending = nil
        }

        func gateHidden() {
            gates = max(gates - 1, 0)
        }
    }

    extension View {
        /// Marks a screen that comes before the app, the paywall or setup:
        /// shelf links that arrive while it shows are dropped.
        func dropsShelfLinks() -> some View {
            modifier(TopShelfGate())
        }
    }

    private struct TopShelfGate: ViewModifier {
        @Environment(TopShelfInbox.self) private var inbox: TopShelfInbox?

        func body(content: Content) -> some View {
            content
                .onAppear { inbox?.gateShown() }
                .onDisappear { inbox?.gateHidden() }
        }
    }

    /// Plays the channel or resumes the title a shelf link names, on any
    /// screen, holding a link that arrives before its source loads
    /// (tvos-shell/play-or-resume-from-a-shelf-link, top-shelf/select-a-tile-to-watch).
    struct TopShelfLinks: ViewModifier {
        let model: ShellModel
        let library: ShelfLibrary
        let playback: ShelfPlayback
        @Environment(TopShelfInbox.self) private var inbox: TopShelfInbox?
        @Environment(ShelfActivity.self) private var activity

        private struct Inputs: Equatable {
            var channels: Int
            var loading: Int
            var titles: Int
            var pending: Bool
        }

        private var titles: [ShelfTitle] { library.movies.titles + library.series.titles }

        /// True while a Movies or Series source can still add titles, a
        /// playlist's as an Xtream source's (m3u-playlists/playlist-titles-show-on-every-platform).
        private var titlesPending: Bool {
            guard model.titleOffer.any else { return false }
            return [library.movies, library.series].contains { shelf in
                !shelf.opened || shelf.sources.contains { $0.state == .loading }
            }
        }

        private var inputs: Inputs {
            Inputs(
                channels: model.channels.count, loading: model.sources.filter { $0.state == .loading }.count, titles: titles.count,
                pending: titlesPending)
        }

        func body(content: Content) -> some View {
            content
                .onChange(of: inbox?.pending, initial: true) {
                    if let id = inbox?.take() { model.holdShelfItem(id) }
                    guard model.shelfItem != nil else { return }
                    // Titles load only once Movies or Series opens.
                    library.open()
                    resolve()
                }
                .onChange(of: inputs) { resolve() }
        }

        private func resolve() {
            guard model.shelfItem != nil else { return }
            if case .resume(let title) = model.resolveShelfItem(titles: titles, titlesPending: titlesPending) {
                library.closePage()
                playback.play(title, library: library, activity: activity)
            }
        }
    }
#endif

#if os(tvOS)
    extension TopShelfInbox {
        /// The app's inbox. A Debug build launched with
        /// `-antenna.openURL <url>` receives that link at launch, as a tile
        /// selected while Antenna was not running delivers it. With
        /// `-ui-testing-open-url-running` as well, the link arrives once a
        /// channel plays instead (`UITestingShell`).
        static func launching(arguments: [String] = ProcessInfo.processInfo.arguments) -> TopShelfInbox {
            let inbox = TopShelfInbox()
            #if DEBUG
                if let url = UITestingShell.openURL(arguments: arguments), !arguments.contains(UITestingShell.openURLRunningArgument) {
                    inbox.receive(url)
                }
            #endif
            return inbox
        }
    }
#endif
