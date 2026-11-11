#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData
    import SwiftUI
    import Synchronization

    /// Scripted sources and a recording engine for the Apple TV shell's UI
    /// tests (tvos-shell capability), compiled into Debug builds only.
    ///
    /// `-ui-testing-shell <scenario>` starts the app on an in-memory store
    /// with two sources. Nothing reaches the network, iCloud or the Keychain.
    enum UITestingShell {
        static let argument = "-ui-testing-shell"

        enum Scenario: String {
            /// An M3U source with three channels and an Xtream source with one.
            case channels
            /// As `channels`, but every engine load fails.
            case failing
            /// Two sources whose loads never finish.
            case loading
            /// An M3U source with no channels and an Xtream source with no
            /// login. Later loads never finish, so Retry shows the loading screen.
            case empty
        }

        static let playlistID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
        static let xtreamID = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID()

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes channels, failing, loading or empty")
            }
            return scenario
        }

        /// The seeded store, or nil when the app was not launched for these tests.
        static func container() -> ModelContainer? {
            guard scenario() != nil else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                for (order, descriptor) in sources.enumerated() {
                    context.insert(SourceRecord(descriptor: descriptor, sortOrder: order))
                }
                UITestingProfiles.seed(context)
                try context.save()
                return container
            } catch {
                fatalError("Could not create the shell UI testing store: \(error)")
            }
        }

        private static var sources: [SourceDescriptor] {
            [
                SourceDescriptor(
                    id: playlistID, name: "Home playlist", kind: .m3u,
                    url: URL(fileURLWithPath: "/fixture/home.m3u")),
                SourceDescriptor(
                    id: xtreamID, name: "Cabin", kind: .xtream,
                    url: URL(fileURLWithPath: "/fixture/cabin"), credentialKey: "fixture"),
            ]
        }

        /// b1 offers seven days of catch-up; the others none.
        static func channel(_ id: String) -> Channel {
            Channel(
                id: "fixture/\(id)", name: "Channel \(id)", streamURL: URL(fileURLWithPath: "/fixture/\(id).ts"), epgID: id,
                hasCatchup: id == "b1", catchupDays: id == "b1" ? 7 : nil)
        }
    }

    #if os(tvOS)
        extension UITestingShell {
            /// When the app launched, so the scripted programmes are on now.
            @MainActor static let launched = Date.now

            /// A scripted guide for the shell's UI tests, or nil outside them:
            /// a1 and b1 have a programme on now, a1 four more after it, a2's
            /// guide is still loading and a3 has none, or failed to load with
            /// `-ui-testing-guide-failed`. The guide reaches from an hour
            /// before launch to three hours after.
            @MainActor
            static func guide() -> OverlayGuide? {
                guard scenario() != nil else { return nil }
                let a3Failed = ProcessInfo.processInfo.arguments.contains(failedGuideArgument)
                let current = scriptedCurrent
                let next = scriptedNext
                return OverlayGuide(
                    state: { channel in
                        switch channel.id {
                        case "fixture/a2": .loading
                        case "fixture/a3" where a3Failed: .failed(.timeout)
                        default: .loaded
                        }
                    },
                    current: current,
                    next: next,
                    programmes: { channel, interval in
                        ([current(channel, launched)].compactMap(\.self) + next(channel, launched, 4))
                            .filter { $0.stop > interval.start && $0.start < interval.end }
                    },
                    horizon: { DateInterval(start: launched.addingTimeInterval(-3600), end: launched.addingTimeInterval(3 * 3600)) })
            }

            /// Makes Channel a3's guide fail to load instead of loading empty.
            static let failedGuideArgument = "-ui-testing-guide-failed"

            /// Opens the Guide at b1's Evening Film once a channel plays, as
            /// picking it in Search will.
            static let guideRequestArgument = "-ui-testing-guide-request"

            /// With `-ui-testing-guide-request`, waits for the launch tune and
            /// sends the shell to the Guide at b1's programme on now.
            @MainActor
            static func requestGuide(from model: ShellModel) {
                guard scenario() != nil, ProcessInfo.processInfo.arguments.contains(guideRequestArgument) else { return }
                Task {
                    while model.tuned == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    let key = GuideKey(sourceID: xtreamID, epgID: "b1")
                    await model.show(.guide(programmeKey: ProgrammeKey(guideKey: key, start: launched.addingTimeInterval(-1800))))
                }
            }

            /// Morning News on a1 and Evening Film on b1, from half an hour
            /// before launch to half an hour after.
            @MainActor
            private static let scriptedCurrent: @MainActor (Channel, Date) -> Programme? = { channel, _ in
                let title: String? =
                    switch channel.id {
                    case "fixture/a1": "Morning News"
                    case "fixture/b1": "Evening Film"
                    default: nil
                    }
                return title.map {
                    Programme(
                        channelID: channel.id, start: launched.addingTimeInterval(-1800), stop: launched.addingTimeInterval(1800),
                        title: $0, summary: "Headlines and weather.", category: "News")
                }
            }

            /// Weather, Business, Sport Tonight and Late Film on a1 after
            /// Morning News, half an hour each.
            @MainActor
            private static let scriptedNext: @MainActor (Channel, Date, Int) -> [Programme] = { channel, _, count in
                guard channel.id == "fixture/a1" else { return [] }
                let titles = ["Weather", "Business", "Sport Tonight", "Late Film"]
                return zip(titles.indices, titles).prefix(count).map { index, title in
                    let start = launched.addingTimeInterval(1800 + Double(index) * 1800)
                    return Programme(channelID: channel.id, start: start, stop: start.addingTimeInterval(1800), title: title)
                }
            }
        }
    #endif

    #if os(tvOS)
        extension UITestingShell {
            /// The shell's dependencies for the launch scenario, or nil.
            @MainActor
            static func dependencies() -> ShellModel.Dependencies? {
                guard let scenario = scenario() else { return nil }
                let engine = Engine(failing: scenario == .failing)
                let script = Script(scenario: scenario)
                let store = UITestingRecents.store { $0.hasPrefix("b") ? xtreamID : playlistID }
                // `UITESTING_LAST_CHANNEL=b1` makes Cabin's channel the one the launch tunes.
                let cabinFirst = Channel.tagged([channel("b1")], sourceID: xtreamID).first.flatMap { LastChannelKey($0) }
                if ProcessInfo.processInfo.environment["UITESTING_LAST_CHANNEL"] == "b1", let cabinFirst {
                    store.write(cabinFirst)
                }
                let credentials = MemoryCredentials()
                var cabinLoaded = false
                return ShellModel.Dependencies(
                    engine: engine,
                    load: { try await script.load($0) },
                    hasLogin: { source in
                        guard source.id == xtreamID else { return true }
                        guard scenario != .empty else { return false }
                        guard UITestingPlayback.script == .fail(.loginNotOnDevice), cabinLoaded else {
                            cabinLoaded = true
                            return true
                        }
                        // Cabin's channels load, then its login is missing when a stream
                        // plays, until the sign-in step stores one.
                        return (try? credentials.load(for: source.credentialKey ?? "")) != nil
                    },
                    recents: store,
                    sleep: { try await Task.sleep(for: $0) },
                    guide: nil,
                    credentials: credentials,
                    network: UITestingPlayback.network,
                    slowDelay: UITestingPlayback.slowDelay,
                    watchSleep: UITestingRecents.sleep)
            }

            /// Logins the sign-in step stores, kept in memory, never in the Keychain.
            final class MemoryCredentials: CredentialStoring {
                private let items = Mutex<[String: CredentialStore.Credential]>([:])

                func save(_ credential: CredentialStore.Credential, for key: String) throws {
                    items.withLock { $0[key] = credential }
                }

                func load(for key: String) throws -> CredentialStore.Credential? {
                    items.withLock { $0[key] }
                }

                func delete(for key: String) throws {
                    items.withLock { _ = $0.removeValue(forKey: key) }
                }
            }

            /// What each scenario's sources answer.
            @MainActor
            final class Script {
                let scenario: Scenario
                private var calls = 0

                init(scenario: Scenario) {
                    self.scenario = scenario
                }

                func load(_ source: SourceDescriptor) async throws -> Playlist {
                    calls += 1
                    switch scenario {
                    case .channels, .failing:
                        return source.id == playlistID
                            ? Playlist(channels: ["a1", "a2", "a3"].map(channel))
                            : Playlist(channels: [channel("b1")])
                    case .loading:
                        try await Task.sleep(for: .seconds(3600))
                        return Playlist(channels: [])
                    case .empty:
                        if calls > 1 { try await Task.sleep(for: .seconds(3600)) }
                        return Playlist(channels: [])
                    }
                }
            }

            /// Records what the shell asks of the player, for the probe.
            @MainActor @Observable
            final class Engine: PlaybackEngine {
                private(set) var state: PlaybackState = .idle {
                    didSet { stateCast.send(state) }
                }
                @ObservationIgnored private let stateCast = Broadcast(PlaybackState.idle)
                @ObservationIgnored private let trackList = UITestingPlayback.Tracks()
                private(set) var loads = 0
                private(set) var lastFile = ""
                private let failing: Bool

                init(failing: Bool) {
                    self.failing = failing
                }

                var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

                func load(_ url: URL, options: PlaybackOptions) async throws {
                    loads += 1
                    lastFile = url.lastPathComponent
                    trackList.reset()
                    if failing {
                        state = .failed(.unreadable)
                        throw PlaybackFailure.unreadable
                    }
                    switch UITestingPlayback.afterLoad(url.lastPathComponent) {
                    case .success(let next):
                        state = next
                    case .failure(let reason):
                        state = .failed(reason)
                        throw reason
                    }
                }

                func play() async {
                    if case .failed = state { return }
                    guard UITestingPlayback.plays else { return }
                    state = .playing
                    guard UITestingPlayback.drops else { return }
                    let loaded = loads
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(1))
                        guard let self, loads == loaded, state == .playing else { return }
                        state = .reconnecting(attempt: 2, of: 3)
                    }
                }

                func pause() async {
                    state = .paused
                }

                func stop() async {
                    state = .idle
                }

                func seek(to time: Duration) async throws { throw SeekRefusal.live }
                func selectAudio(_ id: MediaTrack.ID) async { trackList.selectAudio(id) }
                func selectSubtitle(_ id: MediaTrack.ID?) async { trackList.selectSubtitle(id) }
                func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }

                /// Every scripted stream reports 1080p with 5.1 AAC sound.
                func presentation() async -> AsyncStream<PresentationInfo?> { trackList.format.stream() }
                func tracks() async -> AsyncStream<TrackList> { trackList.cast.stream() }
                func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
                func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }

                /// `"<state> loads=<n> file=<last file name>"`.
                var summary: String {
                    let name =
                        switch state {
                        case .idle: "idle"
                        case .loading: "loading"
                        case .playing: "playing"
                        case .paused: "paused"
                        case .buffering: "buffering"
                        case .reconnecting: "reconnecting"
                        case .ended: "ended"
                        case .failed: "failed"
                        }
                    return "\(name) loads=\(loads) file=\(lastFile)"
                }
            }

            /// A tiny text the UI tests read through `shell.debug.engine`.
            /// Draws nothing outside UI tests.
            struct Probe: View {
                let engine: any PlaybackEngine

                var body: some View {
                    if let engine = engine as? Engine {
                        Text(engine.summary)
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("shell.debug.engine")
                            .accessibilityValue(engine.summary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    #endif
#endif
