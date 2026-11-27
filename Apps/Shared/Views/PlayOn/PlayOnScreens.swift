#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Routes every play on iPhone, iPad and Mac through Play on while the
    /// phone is connected to an Apple TV
    /// (play-on-apple-tv/play-goes-to-the-tv-while-connected): a channel
    /// picked in Live, the Guide, Search or a reminder, and a film or
    /// episode started from a title page or a shelf, go to the TV. The
    /// local engines stay shut behind the stream gate, so nothing opens here
    /// (play-on-apple-tv/the-phone-opens-no-stream-while-connected). It also
    /// plays here what the TV handed back (play-on-apple-tv/play-on-this-iphone).
    struct PlayOnWiring: ViewModifier {
        let live: LiveModel
        let library: ShelfLibrary
        let playback: ShelfPlayback
        @Environment(\.playDestination) private var destination
        @Environment(ShelfActivity.self) private var activity

        func body(content: Content) -> some View {
            content
                .onChange(of: destination.map(ObjectIdentifier.init), initial: true) { wire() }
        }

        private func wire() {
            guard let destination else {
                live.playsElsewhere = nil
                playback.playsElsewhere = nil
                return
            }
            let live = live
            let library = library
            live.playsElsewhere = { [weak destination] channel in
                guard let destination, let item = PlayOnItem.channel(channel, sourceName: live.sourceName(of: channel)) else {
                    return false
                }
                return destination.playOnTV(item)
            }
            playback.playsElsewhere = { [weak destination] target, position in
                guard let destination else { return false }
                switch target {
                case .movie(let title):
                    let name = library.movies.source(of: title)?.name ?? ""
                    let item = PlayOnItem(
                        item: .movie(key: PlayItemKeys.title(title)), source: title.sourceID, title: title.name, sourceName: name,
                        start: position > 0 ? position : nil)
                    return destination.playOnTV(item)
                case .episode(let episode, let series):
                    let name = library.series.source(of: series)?.name ?? ""
                    return destination.playOnTV(.episode(episode, of: series, from: position, sourceName: name))
                case .trailer:
                    return false
                }
            }
            destination.playHere = { status in playHere(status) }
        }

        /// Plays here what the TV stopped: the channel live, or the film or
        /// episode from the TV's place.
        private func playHere(_ status: PlayStatus) {
            guard let item = status.item, let source = status.source else { return }
            switch item {
            case .channel(let key), .programme(let key, _, _):
                if let channel = live.channels.first(where: { $0.sourceID == source && PlayItemKeys.channel($0) == key }) {
                    live.pick(channel)
                }
            case .movie(let key):
                if let title = library.movies.titles.first(where: { $0.sourceID == source && PlayItemKeys.title($0) == key }) {
                    playback.play(title, from: status.position, library: library, activity: activity)
                }
            case .episode(let seriesKey, let episodeKey):
                guard let series = library.series.titles.first(where: { $0.sourceID == source && PlayItemKeys.title($0) == seriesKey })
                else { return }
                Task {
                    guard let episodes = try? await library.series.loadEpisodes(series),
                        let episode = episodes.first(where: { PlayItemKeys.episode($0) == episodeKey })
                    else { return }
                    playback.play(episode, of: series, from: status.position ?? 0, library: library, activity: activity)
                }
            }
        }
    }

    extension LiveModel {
        /// The name of the source `channel` came from, empty when it is gone.
        func sourceName(of channel: Channel) -> String {
            sources.first { $0.id == channel.sourceID }?.name ?? ""
        }
    }

    /// What the bar, the connected picture and the sheet show for a connection.
    @MainActor
    enum PlayOnConnected {
        static func state(_ connection: PlayOnConnection, live: LiveModel, locale: Locale) -> PlayingOn.State {
            let status = connection.status
            let title = status?.title ?? ""
            var logo: URL?
            if let status, let source = status.source {
                switch status.item {
                case .channel(let key), .programme(let key, _, _):
                    logo = live.channels.first { $0.sourceID == source && PlayItemKeys.channel($0) == key }?.logoURL
                case .movie, .episode, nil:
                    break
                }
            }
            return PlayingOn.State(
                headline: connection.stopped
                    ? PlayOnText.stopped(on: connection.tv.name, locale: locale)
                    : PlayOnText.playing(on: connection.tv.name, locale: locale),
                line: status.map { PlayOnText.statusLine($0, locale: locale) } ?? "",
                playing: connection.stopped ? nil : status.map { $0.state == .playing },
                initials: Channel.initials(for: title), logoURL: logo)
        }

        @MainActor static var playHereKind: PlayDeviceInfo.Kind { PlayOnDevice.currentKind }
    }

    /// The "Playing on Living Room" bar and the sheet it opens, over every
    /// tab but Live (`playOn.bar`, play-on-apple-tv/connected-to-a-tv).
    struct PlayOnBarHost: View {
        @Environment(\.playDestination) private var destination
        @Environment(LiveModel.self) private var live
        @Environment(\.locale) private var locale
        @State private var sheetShown = false

        var body: some View {
            if let destination, let connection = destination.connection {
                PlayingOn.Bar(
                    state: PlayOnConnected.state(connection, live: live, locale: locale),
                    actions: PlayingOn.Actions(playPause: destination.playPause, open: { sheetShown = true })
                )
                .transition(.opacity)
                .modifier(PlayOnSheet(destination: destination, connection: connection, shown: $sheetShown))
            }
        }
    }

    /// Live's picture area while connected (`playOn.live`): the channel's
    /// logo and "Playing on Living Room" in place of video.
    struct PlayOnConnectedPicture: View {
        @Environment(\.playDestination) private var destination
        @Environment(LiveModel.self) private var live
        @Environment(\.locale) private var locale
        @State private var sheetShown = false

        var body: some View {
            if let destination, let connection = destination.connection {
                PlayingOn.Picture(
                    state: PlayOnConnected.state(connection, live: live, locale: locale),
                    actions: PlayingOn.Actions(playPause: destination.playPause, open: { sheetShown = true })
                )
                .modifier(PlayOnSheet(destination: destination, connection: connection, shown: $sheetShown))
            }
        }
    }

    /// The connected sheet (`playOn.sheet`, `iPhone-PlayOn-Sheet`).
    private struct PlayOnSheet: ViewModifier {
        let destination: PlayDestination
        let connection: PlayOnConnection
        @Binding var shown: Bool
        @Environment(LiveModel.self) private var live
        @Environment(\.locale) private var locale

        func body(content: Content) -> some View {
            content.sheet(isPresented: $shown) {
                PlayingOn.Sheet(
                    state: PlayOnConnected.state(connection, live: live, locale: locale),
                    playHere: PlayOnText.playHere(PlayOnConnected.playHereKind, locale: locale),
                    actions: PlayingOn.Actions(playPause: destination.playPause, open: {}),
                    moveHere: {
                        shown = false
                        Task { await destination.moveHere() }
                    },
                    disconnect: {
                        shown = false
                        destination.disconnect()
                    }
                )
                .presentationDetents([.medium])
                .presentationBackground(Palette.ground)
            }
        }
    }
#endif
