import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The Mac's volume, the AirPlay state and the extra controls in the
/// player model, on a scratch defaults suite and a scripted engine.
@MainActor
@Suite struct PlayerVolumeTests {
    let suite = "player-volume-tests-\(UUID().uuidString)"
    let defaults: UserDefaults
    let applied = Applied()

    @MainActor
    final class Applied {
        var levels: [Float] = []
        var mutes: [Bool] = []
    }

    init() {
        defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    private func player(airPlay: AsyncStream<Bool>? = nil) -> PlayerModel {
        let applied = applied
        var dependencies = PlayerModel.Dependencies(engine: PlayerTestEngine(), network: .online, log: PlayerLog { _ in })
        dependencies.volume = PlayerVolumeStore(defaults: defaults)
        dependencies.applyVolume = { level, muted in
            applied.levels.append(level)
            applied.mutes.append(muted)
        }
        if let airPlay {
            dependencies.airPlay = { airPlay }
        }
        return PlayerModel(dependencies)
    }

    @Test("player-controls-and-playback-errors/the-mac-remembers-its-volume the level comes back when the app opens again")
    func levelComesBack() {
        let first = player()
        #expect(first.volume == 1, "full the first time")
        first.setVolume(0.4)

        let second = player()

        #expect(second.volume == 0.4)
        #expect(applied.levels.last == 0.4, "the engines get the level at once")
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("player-controls-and-playback-errors/the-mac-remembers-its-volume muted at quit comes back unmuted at the same level")
    func mutedComesBackUnmuted() {
        let first = player()
        first.setVolume(0.6)
        first.toggleMute()
        #expect(first.muted)
        #expect(applied.mutes.last == true)

        let second = player()

        #expect(second.volume == 0.6)
        #expect(!second.muted)
        #expect(applied.mutes.last == false)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac Command-Up and Command-Down move the level a tenth")
    func steps() {
        let model = player()
        model.setVolume(0.5)
        model.stepVolume(up: true)
        #expect(abs(model.volume - 0.6) < 0.001)
        model.stepVolume(up: false)
        model.stepVolume(up: false)
        #expect(abs(model.volume - 0.4) < 0.001)
        model.setVolume(0.95)
        model.stepVolume(up: true)
        #expect(model.volume == 1, "never above full")
        model.toggleMute()
        model.stepVolume(up: false)
        #expect(!model.muted, "moving the level unmutes")
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac the player knows when the stream is on AirPlay")
    func airPlay() async {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let model = player(airPlay: stream)
        let task = Task { await model.observeAirPlay() }
        continuation.yield(true)
        #expect(await eventually { model.airPlayActive })
        continuation.yield(false)
        #expect(await eventually { !model.airPlayActive })
        task.cancel()
        continuation.finish()
    }
}
