#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Plays what a phone sends while the shell shows
    /// (play-on-apple-tv/starts-at-once-on-the-same-network): multi-view
    /// ends first, a channel tunes full screen as the reminder's Watch does,
    /// a film or episode plays as the title page's Play does, and the "From
    /// Anna's iPhone" banner shows for four seconds without taking focus.
    /// The group locks, hidden adult content and the profile are this TV's
    /// own: a locked channel tunes behind the passcode prompt and the answer
    /// says so (play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile).
    /// A source that is still loading gets ten seconds to list the item.
    struct ShellPlayRequests: ViewModifier {
        let model: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let overlay: ChannelOverlayModel
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(PlayRequestInbox.self) private var inbox: PlayRequestInbox?
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfPlayback.self) private var playback
        @Environment(ShelfActivity.self) private var activity
        @Environment(\.locale) private var locale
        /// True after a phone took the item back, until the next request.
        @State private var handedOff = false

        /// How long a source that is still loading has to list the item.
        static let sourceWait = Duration.seconds(10)
        /// How long the banner stays.
        static let bannerTime = Duration.seconds(4)

        func body(content: Content) -> some View {
            content
                .overlay(alignment: .topTrailing) {
                    if let banner = inbox?.banner {
                        FromDeviceBanner(eyebrow: banner.eyebrow, line: banner.line)
                            .padding(.top, 60)
                            .padding(.trailing, 80)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .task(id: banner.id) {
                                try? await Task.sleep(for: Self.bannerTime)
                                if inbox?.banner?.id == banner.id { inbox?.banner = nil }
                            }
                    }
                }
                .onAppear { inbox?.attach() }
                .onDisappear { inbox?.detach() }
                .onChange(of: inbox?.delivery?.id, initial: true) {
                    guard let delivery = inbox?.take() else { return }
                    handedOff = false
                    Task { delivery.reply(await play(delivery.request)) }
                }
                .onChange(of: inbox?.controlRequest?.id) {
                    guard let control = inbox?.takeControl() else { return }
                    Task { await act(on: control) }
                }
                .task {
                    // What connected phones see, kept current twice a second
                    // (play-on-apple-tv/connected-to-a-tv).
                    while !Task.isCancelled {
                        inbox?.status = await currentStatus()
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
        }

        // MARK: Connected phones

        /// What the TV plays: the title on screen, else the tuned channel.
        /// After a hand-off it reads stopped until the next request.
        private func currentStatus() async -> PlayStatus {
            let requestID = inbox?.playingRequest
            if let target = playback.playing, let transport = playback.transport, !handedOff {
                let title = target.title
                var item: PlayRequest.Item = .movie(key: PlayItemKeys.title(title))
                var subtitle: String?
                if case .episode(let episode, let series) = target {
                    item = .episode(seriesKey: PlayItemKeys.title(series), episodeKey: PlayItemKeys.episode(episode))
                    subtitle = episode.title
                }
                let position = transport.position
                return PlayStatus(
                    state: Self.state(transport.state), requestID: requestID, source: title.sourceID, item: item, title: title.name,
                    subtitle: subtitle, position: Double(position.time.components.seconds),
                    duration: position.duration.map { Double($0.components.seconds) }, artworkKey: PlayItemKeys.title(title))
            }
            if let channel = model.tuned, !handedOff, model.tab.showsPicture {
                let state = Self.state(await model.engine.state)
                return PlayStatus(
                    state: state, requestID: requestID, source: channel.sourceID, item: .channel(key: PlayItemKeys.channel(channel)),
                    title: channel.name, artworkKey: PlayItemKeys.channel(channel))
            }
            return PlayStatus(state: .stopped, requestID: requestID, title: inbox?.status?.title ?? "")
        }

        private static func state(_ state: PlaybackState) -> PlayStatus.State {
            switch state {
            case .paused: .paused
            case .idle, .failed, .ended: .stopped
            case .loading, .playing, .buffering, .reconnecting: .playing
            }
        }

        /// Play, pause, or hand the item back to the phone: the TV says
        /// where it was, then stops and goes back to the page or the picture
        /// (play-on-apple-tv/play-on-this-iphone).
        private func act(on control: PlayControl) async {
            let engine = playback.playing != nil ? playback.engine : model.engine
            switch control {
            case .play:
                if await engine.state == .paused { await engine.play() }
            case .pause:
                if await engine.state != .paused { await engine.pause() }
            case .handOff:
                var status = await currentStatus()
                status.state = .stopped
                handedOff = true
                inbox?.status = status
                if playback.playing != nil { await playback.close() } else { await model.engine.stop() }
            case .disconnect:
                break
            }
        }

        private func play(_ request: PlayRequest) async -> PlayAnswer.Result {
            await model.multiView?.leave()
            let deadline = ContinuousClock.now + Self.sourceWait
            while true {
                let wantsTitles = request.wantsTitles
                if wantsTitles { library.open() }
                let outcome = PlayRequestMatch.resolve(
                    request, source: sourceState(request, titles: wantsTitles), channels: model.channels,
                    titles: wantsTitles ? library.movies.titles + library.series.titles : nil, now: .now, key: PlayItemKeys.key)
                switch outcome {
                case .play(let target):
                    return await start(target, for: request)
                case .refuse(let result):
                    return refuse(result, for: request)
                case .wait:
                    guard ContinuousClock.now < deadline else {
                        let known = model.sources.contains { $0.id == request.source }
                        return refuse(known ? .notFound : .noSource(source: request.source), for: request)
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
        }

        /// Where the request's source stands on this TV.
        private func sourceState(_ request: PlayRequest, titles: Bool) -> PlayRequestMatch.Source {
            guard let source = model.sources.first(where: { $0.id == request.source }) else {
                return model.launched ? .missing : .loading
            }
            switch source.state {
            case .waitingForLogin: return .noLogin
            case .loading: return .loading
            case .loaded, .offline, .failed: break
            }
            guard titles else { return .loaded }
            let pending = [library.movies, library.series].contains { shelf in
                !shelf.opened || shelf.sources.contains { $0.id == request.source && $0.state == .loading }
            }
            return pending ? .loading : .loaded
        }

        private func start(_ target: PlayRequestMatch.Target, for request: PlayRequest) async -> PlayAnswer.Result {
            switch target {
            case .channel(let channel):
                await tune(channel)
            case .catchup(let channel, let start, let end):
                await tune(channel)
                let programme = Programme(channelID: channel.epgID ?? channel.id, start: start, stop: end, title: request.displayTitle)
                model.player.timeshift.watchCatchup(programme, on: channel)
            case .movie(let title):
                library.closeAll()
                playback.play(title, from: request.startPosition, library: library, activity: activity)
            case .episode(let series, let episodeKey):
                guard let episodes = try? await library.series.loadEpisodes(series),
                    let episode = episodes.first(where: { PlayItemKeys.episode($0) == episodeKey })
                else { return refuse(.notFound, for: request) }
                let saved = ContinueWatching.episodeProgress(activity.progress, seriesID: series.id, sourceID: series.sourceID)[episode.id]
                let position = request.startPosition ?? (saved?.state == .inProgress ? saved?.resumePosition ?? 0 : 0)
                library.closeAll()
                playback.play(episode, of: series, from: position, library: library, activity: activity)
            }
            inbox?.announce(request, locale: locale)
            inbox?.playingRequest = request.id
            if case .channel(let channel) = target, isLocked(channel) { return .needsPasscode }
            if case .catchup(let channel, _, _) = target, isLocked(channel) { return .needsPasscode }
            return .started
        }

        /// Tunes `channel` full screen over any title playing, keeping the
        /// overlay's group when it holds the channel.
        private func tune(_ channel: Channel) async {
            library.closeAll()
            if playback.playing != nil { await playback.close() }
            if let row = RowKey(channel) {
                let group = overlay.lastTuned ?? model.tuned.flatMap(catalogue.sourceGroup(of:)) ?? .all
                overlay.tuned(from: catalogue.rows(in: group).contains(row) ? group : .all)
            }
            await model.pickFromOverlay(channel)
            focus.wrappedValue = .picture
        }

        private func isLocked(_ channel: Channel) -> Bool {
            guard let row = RowKey(channel) else { return false }
            return catalogue.isLocked(row) || catalogue.isAdultHidden(row)
        }

        /// Says on the TV why the request did not play; a missing login
        /// opens the sign-in this TV shows for the source today.
        private func refuse(_ result: PlayAnswer.Result, for request: PlayRequest) -> PlayAnswer.Result {
            let name = model.sources.first { $0.id == request.source }?.name ?? ""
            let tv = PlayOnDevice.currentName
            let reason = PlayOnText.line(for: result, tv: tv, item: request.displayTitle, sourceName: name, locale: locale)
            inbox?.announce(request, reason: reason, locale: locale)
            if case .noLogin(let source) = result { model.signIn(to: source) }
            return result
        }
    }

    extension PlayRequest {
        /// True for a film or an episode, which need Movies or Series loaded.
        fileprivate var wantsTitles: Bool {
            switch item {
            case .movie, .episode: true
            case .channel, .programme: false
            }
        }
    }
#endif
