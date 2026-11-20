#if os(iOS) || os(macOS)
    import Foundation

    /// What takes the channel list's place, or sits above it, while sources
    /// load, fail, come back empty or wait for a login
    /// (live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login).
    /// A source's own error text is never part of it.
    enum LiveStatus: Equatable {
        /// Each source with its count or a spinner, while any source loads.
        case loading([LiveSource])
        /// No source loaded a channel and every failure was the connection.
        case offline
        /// No source loaded a channel and at least one failed.
        case failed(waiting: [LocalizedStringResource])
        /// The sources loaded no channels, or wait for their logins.
        case empty(waiting: [LocalizedStringResource])
        /// The channels, with a banner naming the sources that added nothing
        /// and a note per source waiting for its login.
        case channels(banner: LocalizedStringResource?, waiting: [LiveSource])

        static let offlineTitle: LocalizedStringResource = "You're offline."
        static let offlineLine: LocalizedStringResource = "Connect to the internet and try again."
        static let failedTitle: LocalizedStringResource = "Could not load channels"
        static let emptyTitle: LocalizedStringResource = "No channels yet"
        static let emptySymbol = "antenna.radiowaves.left.and.right.slash"

        /// True for the states that take the whole Live screen's message:
        /// offline, failed and empty.
        var isMessage: Bool {
            switch self {
            case .offline, .failed, .empty: true
            case .loading, .channels: false
            }
        }

        /// `dismissed` is the set of sources whose banner the user closed;
        /// the banner comes back when another source fails.
        init(sources: [LiveSource], dismissed: Set<UUID>) {
            if sources.contains(where: { $0.state == .loading }) {
                self = .loading(sources)
                return
            }
            let waiting = sources.filter { $0.state == .waitingForLogin }
            guard sources.contains(where: \.state.isLoadedWithChannels) else {
                let lines = waiting.map(\.waitingLine)
                let failures = sources.filter { $0.state == .failed || $0.state == .offline }
                if !failures.isEmpty, failures.allSatisfy({ $0.state == .offline }) {
                    self = .offline
                } else if !failures.isEmpty {
                    self = .failed(waiting: lines)
                } else {
                    self = .empty(waiting: lines)
                }
                return
            }
            let failed = sources.filter { $0.state == .failed || $0.state == .offline }
            let empty = sources.filter { $0.state == .loaded(channels: 0) }
            let shown = (failed + empty).filter { !dismissed.contains($0.id) }
            self = .channels(banner: shown.isEmpty ? nil : Self.banner(failed: failed, empty: empty), waiting: waiting)
        }

        /// "Could not load Cabin M3U", and "Home has no channels" for a
        /// source that loaded empty.
        private static func banner(failed: [LiveSource], empty: [LiveSource]) -> LocalizedStringResource {
            let failedNames = list(failed.map(\.name))
            let emptyNames = list(empty.map(\.name))
            return switch (failed.isEmpty, empty.count) {
            case (_, 0): "Could not load \(failedNames)"
            case (true, 1): "\(emptyNames) has no channels"
            case (true, _): "\(emptyNames) have no channels"
            case (false, 1): "Could not load \(failedNames). \(emptyNames) has no channels"
            case (false, _): "Could not load \(failedNames). \(emptyNames) have no channels"
            }
        }

        private static func list(_ names: [String]) -> String {
            guard names.count > 1, let last = names.last else { return names.first ?? "" }
            return names.dropLast().joined(separator: ", ") + " and " + last
        }

        /// What the loading list says about a source.
        static func detail(_ state: LiveSource.State) -> LocalizedStringResource? {
            switch state {
            case .loading: return nil
            case .loaded(let count): return "\(count) channels"
            case .offline: return "Offline"
            case .failed: return "Could not load"
            case .waitingForLogin: return "Waiting for login"
            }
        }
    }
#endif

#if os(iOS) || os(macOS)
    extension LiveModel {
        /// What the list shows for the sources as they stand. Before the
        /// first sources arrive it is an empty loading list.
        var status: LiveStatus {
            launched ? LiveStatus(sources: sources, dismissed: dismissed) : .loading([])
        }
    }
#endif

#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The list's place while no channel can show: each source loading, or
    /// the shared status layout when no source loaded channels
    /// (design-system/empty-and-error-states-share-one-layout). Open
    /// Settings comes first when the sources answered and something in them
    /// needs changing; offline has Try again alone.
    struct LiveStatusMessage: View {
        let status: LiveStatus
        @Environment(LiveModel.self) private var live
        @Environment(\.shellNavigator) private var navigator

        var body: some View {
            switch status {
            case .loading(let sources):
                Browse.LoadingList(
                    rows: sources.map { source in
                        Browse.LoadingRow(
                            id: source.id, name: source.name,
                            status: LiveStatus.detail(source.state).map(Browse.LoadingRow.Status.done) ?? .loading)
                    })
            case .offline:
                StatusView(
                    symbol: "wifi.slash", title: LiveStatus.offlineTitle, lines: [LiveStatus.offlineLine], identifier: "browse.error"
                ) {
                    tryAgain
                }
            case .failed(let waiting):
                StatusView(symbol: "exclamationmark.circle", title: LiveStatus.failedTitle, lines: waiting, identifier: "browse.error") {
                    openSettings
                    tryAgain
                }
            case .empty(let waiting):
                StatusView(symbol: LiveStatus.emptySymbol, title: LiveStatus.emptyTitle, lines: waiting, identifier: "browse.empty") {
                    openSettings
                    tryAgain
                }
            case .channels:
                EmptyView()
            }
        }

        @ViewBuilder private var openSettings: some View {
            if let navigator {
                Button("Open Settings") { navigator.show(.settings) }
                    .accessibilityIdentifier("browse.settings")
            }
        }

        private var tryAgain: some View {
            Button("Try again", action: live.retry)
                .accessibilityIdentifier("browse.retry")
        }
    }

    /// The failure banner and a note per source waiting for its login,
    /// above the channels on iPhone (`iPhone-Banner`).
    struct LiveBanners: View {
        let banner: LocalizedStringResource?
        let waiting: [LiveSource]
        @Environment(LiveModel.self) private var live

        var body: some View {
            if banner != nil || !waiting.isEmpty {
                VStack(spacing: 8) {
                    if let banner {
                        Browse.FailureBanner(text: banner, retry: live.retry, dismiss: live.dismissBanner)
                    }
                    ForEach(waiting) { source in
                        Browse.WaitingNote(text: "\(source.name) · waiting for login")
                            .accessibilityIdentifier("browse.banner.waiting.\(source.id.uuidString)")
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))
            }
        }
    }
#endif
