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
        case failed(waiting: [String])
        /// The sources loaded no channels, or wait for their logins.
        case empty(waiting: [String])
        /// The channels, with a banner naming the sources that added nothing
        /// and a note per source waiting for its login.
        case channels(banner: String?, waiting: [LiveSource])

        static let offlineTitle = "You're offline."
        static let offlineLine = "Connect to the internet and try again."
        static let failedTitle = "Could not load channels"
        static let emptyTitle = "No channels yet"

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
        private static func banner(failed: [LiveSource], empty: [LiveSource]) -> String {
            var parts: [String] = []
            if !failed.isEmpty { parts.append("Could not load " + list(failed.map(\.name))) }
            if !empty.isEmpty { parts.append(list(empty.map(\.name)) + (empty.count == 1 ? " has no channels" : " have no channels")) }
            return parts.joined(separator: ". ")
        }

        private static func list(_ names: [String]) -> String {
            guard names.count > 1, let last = names.last else { return names.first ?? "" }
            return names.dropLast().joined(separator: ", ") + " and " + last
        }

        /// What the loading list says about a source.
        static func detail(_ state: LiveSource.State) -> String? {
            switch state {
            case .loading: nil
            case .loaded(let count): count == 1 ? "1 channel" : "\(count) channels"
            case .offline: "Offline"
            case .failed: "Could not load"
            case .waitingForLogin: "Waiting for login"
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
    import SwiftUI

    /// The list's place while no channel can show: each source loading, or
    /// a message with Retry when no source loaded channels.
    struct LiveStatusMessage: View {
        let status: LiveStatus
        @Environment(LiveModel.self) private var live

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
                message(LiveStatus.offlineTitle, [LiveStatus.offlineLine], identifier: "browse.error")
            case .failed(let waiting):
                message(LiveStatus.failedTitle, waiting, identifier: "browse.error")
            case .empty(let waiting):
                message(LiveStatus.emptyTitle, waiting, identifier: "browse.empty")
            case .channels:
                EmptyView()
            }
        }

        private func message(_ title: String, _ lines: [String], identifier: String) -> some View {
            Browse.Message(title: title, lines: lines, retry: live.retry)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(identifier)
        }
    }

    /// The failure banner and a note per source waiting for its login,
    /// above the channels on iPhone (`iPhone-Banner`).
    struct LiveBanners: View {
        let banner: String?
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
