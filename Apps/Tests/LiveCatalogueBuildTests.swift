import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// Live builds its catalogue away from the main actor. A build that
    /// lands late never replaces a newer one, and a favorite or group rule
    /// changed while a build runs is in the catalogue it lands with.
    @MainActor
    @Suite struct LiveCatalogueBuildTests {
        let source = UUID()

        /// Holds the builds of catalogues with `held` channels until the test opens it.
        actor HeldBuild {
            let held: Int
            private var waiting: [CheckedContinuation<Void, Never>] = []
            private(set) var released = 0

            init(held: Int) { self.held = held }

            func pass(_ inputs: CatalogueInputs<PersistentIdentifier>) async {
                guard inputs.channels.count == held else { return }
                await withCheckedContinuation { waiting.append($0) }
                released += 1
            }

            func open() {
                waiting.forEach { $0.resume() }
                waiting = []
            }

            var isWaiting: Bool { !waiting.isEmpty }
        }

        @MainActor final class Loads {
            var count = 0
        }

        private func channels(_ count: Int) -> [Channel] {
            (0..<count).map { Channel(id: "c\($0)", name: "Channel \($0)", streamURL: URL(filePath: "/\($0).ts"), group: "News") }
        }

        private func live(gate: HeldBuild, sizes: [Int]) -> LiveModel {
            let loads = Loads()
            let all = sizes.map(channels)
            var dependencies = LiveModel.Dependencies(
                engine: UITestingLive.Engine(log: nil),
                load: { _ in
                    loads.count += 1
                    return Playlist(channels: all[min(loads.count, all.count) - 1])
                }, hasLogin: { _ in true }, guide: nil, programmes: UITestingLive.guide)
            // Stores of its own, so other suites running alongside cannot restore another group.
            let suite = "live-catalogue-\(UUID().uuidString)"
            dependencies.recents = RecentsStore(defaults: UserDefaults(suiteName: suite) ?? .standard)
            dependencies.seen = SeenChannelsStore(directory: FileManager.default.temporaryDirectory.appending(path: suite))
            dependencies.buildCatalogue = { inputs in
                await gate.pass(inputs)
                return await inputs.indexed()
            }
            return LiveModel(dependencies)
        }

        private var descriptor: SourceDescriptor {
            SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(filePath: "/home.m3u"))
        }

        @Test("live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list a catalogue built late never replaces a newer one")
        func lateBuild() async {
            let gate = HeldBuild(held: 2)
            let live = live(gate: gate, sizes: [2, 3])
            live.sourcesChanged([descriptor])
            while await !gate.isWaiting { await Task.yield() }
            live.reload([source])
            await live.settled()
            #expect(live.catalogue.count(of: .all) == 3)

            await gate.open()
            while await gate.released < 1 { await Task.yield() }
            for _ in 0..<20 { await Task.yield() }
            #expect(live.catalogue.count(of: .all) == 3, "the older build is dropped")
            #expect(live.group == .all, "group \(live.group)")
            #expect(live.rows.count == 3)
        }

        @Test("live-tv-on-iphone-ipad-mac/star-a-channel a star and a hidden group set while the catalogue builds are in it")
        func changesDuringBuild() async {
            let gate = HeldBuild(held: 2)
            let live = live(gate: gate, sizes: [2])
            live.sourcesChanged([descriptor])
            while await !gate.isWaiting { await Task.yield() }
            live.favoritesChanged([FavoriteSnapshot(channelID: "c1", sourceID: source, sortOrder: 0)])
            live.rulesChanged(GroupRules(hidden: [.all]))

            await gate.open()
            await live.settled()
            #expect(live.catalogue.rows(in: .favorites).map(\.id) == ["c1"])
            #expect(!live.catalogue.groups.contains(.all), "the hidden group stays hidden")
        }

        @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list the filter reads the name index built with the catalogue")
        func filterAfterBuild() async {
            let gate = HeldBuild(held: -1)
            let live = live(gate: gate, sizes: [12])
            live.sourcesChanged([descriptor])
            await live.settled()
            live.filter = "channel 1"
            #expect(live.rows.map(\.id) == ["c1", "c10", "c11"])
            live.filter = "channel 11"
            #expect(live.rows.map(\.id) == ["c11"])
            live.filter = "channel"
            #expect(live.rows.count == 12)
        }
    }
#endif
