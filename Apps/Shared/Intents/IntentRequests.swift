#if !os(tvOS)
    import AntennaCore
    import AppIntents
    import SwiftUI

    extension EnvironmentValues {
        /// The app's provider for Siri and Shortcuts. Nil in previews and tests.
        @Entry var intentHost: AppIntentHost?
    }

    /// Carries out what Siri and Shortcuts asked for once Antenna is
    /// forward: tunes a channel on Live, plays a movie or opens a series as
    /// a search result would, or opens Search
    /// (app-intents/tune-a-channel-by-voice-or-shortcut, app-intents/play-a-movie-or-series,
    /// app-intents/open-search). A request for an item whose source is still
    /// loading waits for it; one that cannot be met is dropped.
    struct IntentRequests: ViewModifier {
        let navigator: ShellNavigator
        @Environment(\.intentHost) private var host
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfPlayback.self) private var playback
        @Environment(SearchModel.self) private var search

        private struct Inputs: Equatable {
            var request: IntentRequest?
            var channels: Int
            var loadingChannels: Int
            var titles: Int
            var loadingTitles: Int
        }

        private var inputs: Inputs {
            Inputs(
                request: host?.inbox.pending, channels: live.channels.count,
                loadingChannels: live.sources.count { $0.state == .loading }, titles: titles.count,
                loadingTitles: (shelves.movies.sources + shelves.series.sources).count { $0.state == .loading })
        }

        private var titles: [ShelfTitle] { shelves.movies.titles + shelves.series.titles }

        func body(content: Content) -> some View {
            content
                .onChange(of: inputs, initial: true) { handle() }
                // Siri's phrases offer the channels and favorites as they are now
                // (app-intents/shortcuts-suggests-what-you-watch).
                .onChange(of: ShortcutInputs(channels: live.channels.count, favorites: live.catalogue.rows(in: .favorites))) {
                    AntennaShortcuts.updateAppShortcutParameters()
                }
        }

        private struct ShortcutInputs: Equatable {
            var channels: Int
            var favorites: [RowKey]
        }

        private func handle() {
            guard let host, let request = host.inbox.pending else { return }
            switch request {
            case .search(let text):
                host.inbox.take()
                search.start(.all, text: text ?? "")
                if text != nil { search.submit() }
                navigator.show(.search)
            case .tune(let key):
                tune(key, host: host)
            case .play(let reference):
                play(reference, host: host)
            }
        }

        private func tune(_ key: LastChannelKey, host: AppIntentHost) {
            if let row = live.catalogue.row(for: key), let channel = live.catalogue.channel(for: row) {
                host.inbox.take()
                guard !live.catalogue.isLocked(row) else { return }
                if !live.catalogue.rows(in: live.group).contains(row) { live.show(.all, picked: false) }
                live.pick(channel)
                navigator.showLive()
            } else if finished(live.sources.first { $0.id == key.sourceID }.map { $0.state == .loading }) {
                host.inbox.take()
            }
        }

        private func play(_ reference: TitleReference, host: AppIntentHost) {
            shelves.open()
            if let title = titles.first(where: reference.matches) {
                host.inbox.take()
                switch title.kind {
                case .movie: playback.play(title, library: shelves, activity: activity)
                case .series:
                    shelves.openPage(title, from: .search, in: .series)
                    navigator.show(.search)
                }
            } else if finished(shelves.model(reference.kind).sources.first { $0.id == reference.sourceID }.map { $0.state == .loading }) {
                host.inbox.take()
            }
        }

        /// True once the source finished loading, or once Live has its
        /// sources and this one is not among them. `loading` is nil for a
        /// source not listed.
        private func finished(_ loading: Bool?) -> Bool {
            guard let loading else { return live.launched }
            return !loading
        }
    }
#endif
