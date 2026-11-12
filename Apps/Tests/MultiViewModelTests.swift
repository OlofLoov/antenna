import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The model behind both multi-view screens, on scripted engines.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct MultiViewModelTests {
    private let source = UUID()

    private final class World {
        var made: [PlayerTestEngine] = []
        var muted: [ObjectIdentifier: Bool] = [:]
        var lifecycles: [PlaybackLifecycle] = []
        var ended: [Channel?] = []
    }

    private func channels() -> [Channel] {
        (1...4).map {
            Channel(
                id: "c\($0)", name: "C\($0)", streamURL: URL(fileURLWithPath: "/c\($0).ts"), number: 100 + $0, sourceID: source,
                position: $0)
        }
    }

    /// A model whose single player plays the first channel on `playing`.
    private func makeModel(_ world: World, playing: PlayerTestEngine = PlayerTestEngine(), cap: Int = 4) async throws -> MultiViewModel {
        let list = channels()
        var dependencies = MultiViewModel.Dependencies()
        dependencies.cap = MultiViewCap(limit: cap)
        dependencies.device = .appleTV
        dependencies.sleep = { _ in try await Task.sleep(for: .seconds(3600)) }
        dependencies.tiles.make = {
            let engine = PlayerTestEngine()
            world.made.append(engine)
            return RoutedEngine(system: engine, demuxer: engine)
        }
        dependencies.tiles.mute = { engine, muted in
            world.muted[ObjectIdentifier((engine as? RoutedEngine)?.demuxer ?? engine)] = muted
        }
        dependencies.tiles.playback = { _, _ in }
        dependencies.tiles.refusalsFinal = { _, _ in }
        dependencies.tiles.lifecycle = { engine in
            let lifecycle = PlaybackLifecycle(engine: engine, pausesInBackground: true)
            world.lifecycles.append(lifecycle)
            return lifecycle
        }
        let single = RoutedEngine(system: playing, demuxer: playing)
        try await single.load(list[0].streamURL)
        await single.play()
        let made = MultiViewModel(
            playing: list[0], adding: list[1], single: single, dependencies: dependencies,
            channel: { key in list.first { RowKey($0) == key } }, sourceName: { _ in "Acme TV" })
        let model = try #require(made)
        model.ended = { world.ended.append($0) }
        return model
    }

    @Test("multi-view/leaving-the-app every tile pauses and resumes with the app, and the same tile is heard")
    func backgroundAndReturn() async throws {
        let world = World()
        let playing = PlayerTestEngine()
        let model = try await makeModel(world, playing: playing)
        await model.begin()
        await model.add(channels()[2])
        await model.add(channels()[3])
        await model.select(2)
        #expect(await eventually { world.made.count == 4 && world.made.dropFirst().allSatisfy { $0.state == .playing } })
        #expect(world.lifecycles.count == 4)
        for lifecycle in world.lifecycles { await lifecycle.enteredBackground() }
        #expect(playing.state == .paused)
        #expect(world.made[2].state == .paused)
        for lifecycle in world.lifecycles { await lifecycle.becameActive() }
        #expect(playing.state == .playing)
        #expect(world.made.dropFirst().allSatisfy { $0.state == .playing })
        let heard = world.muted.filter { !$0.value }.map(\.key)
        #expect(heard == [ObjectIdentifier(world.made[1])])
    }

    @Test("multi-view/each-tile-has-its-own-actions the actions VoiceOver offers enlarge, retry and remove the tile")
    func tileActions() async throws {
        let world = World()
        let model = try await makeModel(world)
        await model.begin()
        await model.add(channels()[2])
        await model.enlarge(2)
        #expect(model.session.enlarged == 2)
        #expect(model.badgeShown)
        model.shrink()
        #expect(model.session.enlarged == nil)
        world.made[1].failNextLoad = .notFound
        await model.retry(2)
        #expect(await eventually { model.status(2) == .failed(FailureMessage(.notFound, source: "Acme TV", device: .appleTV)) })
        await model.retry(2)
        #expect(await eventually { model.status(2) == .waiting || model.status(2) == .playing })
        await model.remove(2)
        #expect(model.session.tiles.map(\.id) == [1, 3])
        #expect(world.ended.isEmpty)
    }

    @Test("multi-view/a-tile-that-fails-says-why a tile refused while another plays from the same source says the provider refused")
    func providerRefused() async throws {
        let world = World()
        let model = try await makeModel(world)
        await model.begin()
        world.made.last?.failNextLoad = .serverError
        await model.retry(2)
        #expect(
            await eventually {
                if case .failed(let message) = model.status(2) { return message.title == "Your provider refused another stream" }
                return false
            })
        #expect(model.session.audible == nil, "the failed tile is silent")
    }

    @Test("multi-view/leave-multi-view leaving hands the selected tile's channel back to the single player")
    func leave() async throws {
        let world = World()
        let model = try await makeModel(world)
        await model.begin()
        await model.leave()
        #expect(world.ended == [channels()[1]])
        #expect(!model.isOpen)
    }

    @Test("multi-view/remove-a-tile a refresh that removes every tile's channel ends multi-view with everything stopped")
    func refreshRemovesAll() async throws {
        let world = World()
        let model = try await makeModel(world)
        await model.begin()
        await model.channelsChanged { _ in false }
        #expect(world.ended == [nil])
    }

    @Test("multi-view/start-multi-view-on-apple-tv the hint shows after entering")
    func hint() async throws {
        let world = World()
        let model = try await makeModel(world)
        await model.begin()
        #expect(model.hintShown)
        #expect(model.count == "2 of 4")
        #expect(model.spokenLabel(2) == "102, C2, sound on")
        #expect(model.spokenLabel(1) == "101, C1, muted")
    }
}
