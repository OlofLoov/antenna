import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The loading checklist, the summary and what comes after, with stubbed
/// loading and a scripted guide.
@MainActor
@Suite struct OnboardingChecklistTests {
    let container: ModelContainer
    let held = HeldCredentialStore()
    let guide = ScriptedGuide()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    var context: ModelContext { container.mainContext }
    private let text = SetupText(locale: Locale(identifier: "en-US"), timeZone: TimeZone(identifier: "UTC") ?? .current)

    static let account = #"{"user_info":{"status":"Active","exp_date":"1773446400","max_connections":"2","auth":1}}"#

    static func channels(_ count: Int, groups: [String], host: String) -> Playlist {
        Playlist(
            channels: (0..<count).compactMap { index in
                URL(string: "http://\(host)/\(index).ts").map {
                    Channel(
                        id: "\(host)-\(index)", name: "\(host) \(index)", streamURL: $0, group: groups[index % groups.count],
                        number: 100 + index,
                        hasCatchup: index == 0, catchupDays: index == 0 ? 7 : nil)
                }
            })
    }

    func dependencies(
        channels: Playlist, library: SourceSetup.Library? = .init(movies: 5, series: 2), libraryWaits: Bool = false
    ) -> SourceSetup.Dependencies {
        SourceSetup.Dependencies(
            channels: { connection in
                if case .playlist(let playlist) = connection.reply { return playlist }
                return channels
            },
            library: { _ in
                if libraryWaits { try await Task.sleep(for: .seconds(600)) }
                guard let library else { throw URLError(.badServerResponse) }
                return library
            },
            guide: guide,
            libraryCutoff: .seconds(20),
            sleep: { duration in
                // The cutoff passes at once when the library waits, never otherwise.
                if !libraryWaits { try await Task.sleep(for: duration * 30) }
            })
    }

    func model(_ host: String, dependencies: SourceSetup.Dependencies) -> OnboardingModel {
        let model = OnboardingModel(
            connector: SourceConnector(session: StubURLProtocol.session(tag: host), credentials: held), clipboard: nil)
        model.setupDependencies = dependencies
        return model
    }

    private func connectXtream(_ model: OnboardingModel, host: String) async throws -> SourceSetup {
        StubURLProtocol.register(host: host, body: Self.account)
        model.fields = SourceFields(kind: .xtream, name: "Home provider", url: "http://\(host)", username: "anna", password: "pw")
        await model.connect(into: context)
        return try #require(model.setups.last)
    }

    @Test("first-run-onboarding/the-checklist-shows-real-progress: lines fill in with real numbers and the guide's progress")
    func linesFillIn() async throws {
        let host = "checklist-lines.test"
        let model = model(host, dependencies: dependencies(channels: Self.channels(3, groups: ["News", "Sport"], host: host)))
        let setup = try await connectXtream(model, host: host)
        await setup.finishedLoading()
        let progress = OnboardingProgress(setups: model.setups, text: text)
        var lines = progress.lines(for: setup, .television)
        #expect(lines.map(\.title).prefix(3) == ["Signed in", "3 live channels in 2 groups", "5 movies and 2 series"])
        #expect(lines[0].detail == "Account active until March 14, 2026 · 2 connections")
        #expect(lines[1].detail == "News, Sport")
        #expect(lines.last?.title == "Downloading the guide")

        guide.send(.downloading(sourceID: setup.id, bytesReceived: 2_400_000, expectedBytes: nil))
        await guide.drained()
        lines = progress.lines(for: setup, .television)
        #expect(lines.last?.title.hasPrefix("Downloading the guide · 2.4") == true)
        #expect(lines.last?.bar == .indeterminate)
        #expect(!model.allFinished)

        guide.send(.loaded(sourceID: setup.id, channelsWithGuide: 2, channelsTotal: 3, days: 7, unmatched: 0))
        await setup.finished()
        lines = progress.lines(for: setup, .television)
        #expect(lines.last?.title == "Guide for 7 days · 2 of 3 channels")
        #expect(lines.last?.state == .done)
        #expect(model.allFinished)
        #expect(guide.refreshes == 1)
    }

    @Test("first-run-onboarding/the-checklist-shows-real-progress: a playlist without a guide has no guide line")
    func noGuideLine() async throws {
        let host = "checklist-noguide.test"
        StubURLProtocol.register(host: host, body: "#EXTM3U\n#EXTINF:-1 group-title=\"News\",One\nhttp://\(host)/1.ts\n")
        let model = model(host, dependencies: dependencies(channels: Playlist(channels: [])))
        model.fields = SourceFields(kind: .m3u, url: "http://\(host)/tv.m3u")
        await model.connect(into: context)
        let setup = try #require(model.setups.first)
        await setup.finished()
        let lines = OnboardingProgress(setups: model.setups, text: text).lines(for: setup, .phone)
        #expect(lines.map(\.id) == ["playlist", "channels"])
        #expect(lines.map(\.title) == ["Playlist downloaded", "1 live channel"])
        #expect(lines[0].detail == host)
        #expect(model.allFinished)
    }

    @Test("first-run-onboarding/the-checklist-shows-real-progress: a slow movie list stops waiting without counts")
    func slowMovies() async throws {
        let host = "checklist-slow.test"
        let model = model(host, dependencies: dependencies(channels: Self.channels(2, groups: ["News"], host: host), libraryWaits: true))
        let setup = try await connectXtream(model, host: host)
        await setup.finishedLoading()
        let progress = OnboardingProgress(setups: model.setups, text: text)
        #expect(progress.lines(for: setup, .television).map(\.title).contains("Movies and series available"))
        guide.send(.failed(sourceID: setup.id, .offline))
        await setup.finished()
        #expect(progress.lines(for: setup, .television).last?.title == "Guide could not be loaded")
        // first-run-onboarding/a-summary-when-everything-has-loaded: no movie tile after the cutoff, no guide tile after a failure.
        #expect(progress.tiles.map(\.id) == ["channels", "catchUp"])
    }

    @Test("first-run-onboarding/a-summary-when-everything-has-loaded: tiles add up and the first channel plays")
    func summary() async throws {
        let host = "summary.test"
        let model = model(host, dependencies: dependencies(channels: Self.channels(4, groups: ["Sport", "News"], host: host)))
        let setup = try await connectXtream(model, host: host)
        await setup.finishedLoading()
        guide.send(.loaded(sourceID: setup.id, channelsWithGuide: 3, channelsTotal: 4, days: 7, unmatched: 0))
        await setup.finished()
        let progress = OnboardingProgress(setups: model.setups, text: text)
        #expect(progress.tiles.map(\.value) == ["4", "7 days", "7", "7 days"])
        #expect(
            progress.tiles.map(\.caption) == [
                "live channels · 2 groups", "of guide · 3 channels", "movies and series", "of catch-up on 1 channels",
            ])
        #expect(progress.eyebrow == "Home provider added")
        #expect(progress.firstChannel?.name == "summary.test 0")
        #expect(progress.liveCaption == "Live · 100 summary.test 0")
        #expect(progress.primary == .startWatching(enabled: true))
    }

    @Test("first-run-onboarding/a-provider-with-no-live-channels: movies but no channels offers Browse movies")
    func noLiveChannels() async throws {
        let host = "nolive.test"
        let model = model(host, dependencies: dependencies(channels: Playlist(channels: [])))
        let setup = try await connectXtream(model, host: host)
        await setup.finishedLoading()
        guide.send(.failed(sourceID: setup.id, .empty))
        await setup.finished()
        let progress = OnboardingProgress(setups: model.setups, text: text)
        #expect(progress.primary == .browseMovies)
        #expect(progress.lines(for: setup, .television)[1].title == "No live channels")
        #expect(progress.lines(for: setup, .television)[1].state == .muted)
        #expect(!progress.isEmpty)
    }

    @Test("first-run-onboarding/a-provider-with-no-live-channels: nothing at all goes back and removes what Connect saved")
    func nothingAtAll() async throws {
        let host = "nothing.test"
        let model = model(host, dependencies: dependencies(channels: Playlist(channels: []), library: .init(movies: 0, series: 0)))
        let setup = try await connectXtream(model, host: host)
        await setup.finishedLoading()
        #expect(OnboardingProgress(setups: model.setups).isEmpty)
        let progress = OnboardingProgress(setups: model.setups, text: text)
        #expect(progress.isEmpty)
        #expect(progress.primary == .startWatching(enabled: false))
        #expect(progress.lines(for: setup, .television)[1].title == "No channels found")
        let key = try #require(try context.fetch(FetchDescriptor<SourceRecord>()).first?.credentialKey)
        #expect(try held.load(for: key) != nil)

        model.discard(setup, in: context)
        #expect(try context.fetch(FetchDescriptor<SourceRecord>()).isEmpty)
        #expect(try held.load(for: key) == nil)
        #expect(!model.showsChecklist)
        #expect(model.holdsApp, "the form stays up while the store catches up")
        #expect(model.leaveForm())
        #expect(!model.holdsApp)
        #expect(model.fields.url == "http://\(host)")
        #expect(model.fields.username == "anna")
    }

    @Test(
        "first-run-onboarding/start-watching-without-waiting-for-the-guide: Start watching hands over the first channel"
    )
    func startWatching() async throws {
        let host = "start.test"
        let model = model(host, dependencies: dependencies(channels: Self.channels(2, groups: ["News"], host: host)))
        let setup = try await connectXtream(model, host: host)
        await setup.finishedLoading()
        let progress = OnboardingProgress(setups: model.setups, text: text)
        #expect(!setup.guide.isFinished)
        #expect(progress.primary == .startWatching(enabled: true))
        #expect(model.holdsApp)
        let first = try #require(progress.firstChannel)
        let handoff = OnboardingHandoff()
        handoff.hand(.watch(first))
        model.finish()
        #expect(!model.holdsApp)
        #expect(OnboardingRoute(sourceCount: 1, holding: model.holdsApp) == .app)
        #expect(handoff.takeChannel() == first)
        #expect(handoff.takeChannel() == nil)
    }

    @Test("first-run-onboarding/add-a-second-provider: both providers are named and their numbers add up")
    func secondProvider() async throws {
        let first = "second-a.test"
        let second = "second-b.test"
        let model = model(first, dependencies: dependencies(channels: Self.channels(3, groups: ["News", "Sport"], host: first)))
        let one = try await connectXtream(model, host: first)
        await one.finishedLoading()
        guide.send(.downloading(sourceID: one.id, bytesReceived: 1000, expectedBytes: nil))
        await guide.drained()

        model.addAnother()
        #expect(model.fields.url.isEmpty)
        #expect(!model.showsChecklist)
        model.setupDependencies = dependencies(channels: Self.channels(2, groups: ["Kids"], host: second))
        StubURLProtocol.register(host: second, body: Self.account)
        model.fields = SourceFields(kind: .xtream, name: "Holiday flat", url: "http://\(second)", username: "bo", password: "pw")
        await model.connect(into: context)
        let two = try #require(model.setups.last)
        await two.finishedLoading()
        guide.send(.loaded(sourceID: one.id, channelsWithGuide: 3, channelsTotal: 3, days: 7, unmatched: 0))
        guide.send(.loaded(sourceID: two.id, channelsWithGuide: 1, channelsTotal: 2, days: 3, unmatched: 0))
        await one.finished()
        await two.finished()

        let progress = OnboardingProgress(setups: model.setups, text: text)
        #expect(model.showsChecklist)
        #expect(progress.title == "2 sources added")
        #expect(progress.eyebrow == "Home provider · Holiday flat")
        #expect(progress.tiles.first?.value == "5")
        #expect(progress.tiles.first?.caption == "live channels · 3 groups")
        #expect(progress.tiles[1].value == "7 days")
        #expect(progress.tiles[1].caption == "of guide · 4 channels")
        #expect(progress.sections(.phone).map(\.title) == ["Home provider", "Holiday flat"])
        // The first guide download was never restarted.
        #expect(guide.restarts == 0)
    }
}

extension OnboardingChecklistTests {
    @Test("first-run-onboarding/sign-in-again-on-an-apple-tv: each Xtream source asks for its login in turn and adds no source")
    func signInOnAppleTV() async throws {
        let host = "sign-in-tv.test"
        StubURLProtocol.register(host: host, body: Self.account)
        let first = SourceDescriptor(name: "Home provider", kind: .xtream, url: try #require(URL(string: "http://\(host):8080")))
        let second = SourceDescriptor(
            name: "Holiday flat", kind: .xtream, url: try #require(URL(string: "http://\(host):9090")), credentialKey: "holiday-key")
        for (index, source) in [first, second].enumerated() {
            context.insert(SourceRecord(descriptor: source, sortOrder: index))
        }
        try context.save()
        let model = model(host, dependencies: dependencies(channels: Self.channels(2, groups: ["News"], host: host)))
        model.startSignIn([first, second])
        #expect(model.holdsApp)
        #expect(model.fields.url == "http://\(host):8080")
        #expect(model.fields.username.isEmpty)
        #expect(model.signInsAfterThis == ["Holiday flat"])
        #expect(OnboardingSignIn.Television.remaining(model.signInsAfterThis) == "1 more source to sign in after this one: Holiday flat")

        await model.signIn(into: context)
        #expect(model.error == "Enter the username.")
        model.fields.username = "anna"
        model.fields.password = "one"
        await model.signIn(into: context)
        #expect(model.error == nil)
        #expect(try held.load(for: first.id.uuidString) == .init(username: "anna", password: "one"))
        #expect(try context.fetch(FetchDescriptor<SourceRecord>()).first { $0.id == first.id }?.credentialKey == first.id.uuidString)
        #expect(model.fields.url == "http://\(host):9090")
        #expect(!model.showsChecklist)

        model.fields.username = "bo"
        model.fields.password = "two"
        await model.signIn(into: context)
        #expect(try held.load(for: "holiday-key") == .init(username: "bo", password: "two"))
        #expect(try context.fetchCount(FetchDescriptor<SourceRecord>()) == 2)
        #expect(model.setups.map(\.name) == ["Home provider", "Holiday flat"])
        #expect(model.showsChecklist)
        let progress = OnboardingProgress(setups: [try #require(model.setups.first)], signedIn: model.signedIn)
        #expect(progress.eyebrow == "Home provider signed in")
    }
}

/// A guide store whose progress the test sends.
@MainActor
final class ScriptedGuide: SetupGuide {
    private var continuations: [AsyncStream<GuideProgress>.Continuation] = []
    private(set) var refreshes = 0
    /// Stays 0: the checklist never restarts a running download.
    private(set) var restarts = 0

    func progressStream() -> AsyncStream<GuideProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: GuideProgress.self)
        continuations.append(continuation)
        return stream
    }

    func register(epgURLs: [URL], for sourceID: UUID) async {}
    func update(channels: [Channel]) async {}
    func refreshIfStale(now: Date) async { refreshes += 1 }

    func send(_ event: GuideProgress) {
        continuations.forEach { $0.yield(event) }
    }

    /// Lets every listener handle what was sent.
    func drained() async {
        for _ in 0..<20 { await Task.yield() }
    }
}

extension SourceSetup {
    /// Waits until the channels and the movies lines are finished. For tests.
    func finishedLoading() async {
        while !channels.isFinished || !(library?.isFinished ?? true) {
            await Task.yield()
        }
        for _ in 0..<20 { await Task.yield() }
    }
}
