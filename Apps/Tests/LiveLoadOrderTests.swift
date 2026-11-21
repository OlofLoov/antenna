import AntennaCore
import Foundation
import Observation
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// What a source load does before the last channel tunes, and what it
    /// leaves alone when the channels did not change.
    @MainActor
    @Suite struct LiveLoadOrderTests {
        let home = SourceDescriptor(name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))
        let suite = "live-load-order-\(UUID().uuidString)"

        /// Holds every seen-channel record until opened.
        actor Gate {
            private var open = false
            private var waiting: [CheckedContinuation<Void, Never>] = []

            func pass() async {
                guard !open else { return }
                await withCheckedContinuation { waiting.append($0) }
            }

            func release() {
                open = true
                waiting.forEach { $0.resume() }
                waiting = []
            }
        }

        @MainActor final class Sources {
            var channels: [Channel] = []
            var loads = 0
        }

        private func channel(_ id: String) -> Channel {
            Channel(id: id, name: id, streamURL: URL(fileURLWithPath: "/\(id).ts"), group: "News")
        }

        private var seenStore: SeenChannelsStore {
            SeenChannelsStore(directory: FileManager.default.temporaryDirectory.appending(path: suite))
        }

        private func model(_ sources: Sources, gate: Gate? = nil) -> LiveModel {
            var dependencies = LiveModel.Dependencies(
                engine: PlayerTestEngine(),
                load: { _ in
                    sources.loads += 1
                    return Playlist(channels: sources.channels)
                }, hasLogin: { _ in true }, guide: nil, programmes: UITestingLive.guide)
            dependencies.recents = RecentsStore(defaults: UserDefaults(suiteName: suite) ?? .standard)
            var seen = seenStore
            if let gate { seen.beforeRecord = { await gate.pass() } }
            dependencies.seen = seen
            return LiveModel(dependencies)
        }

        @Test(
            "session-restore-and-recently-watched/the-last-channel-does-not-wait-for-bookkeeping it tunes before the record"
        )
        func tunesBeforeRecord() async {
            let gate = Gate()
            let sources = Sources()
            sources.channels = [channel("a"), channel("film")]
            RecentsStore(defaults: UserDefaults(suiteName: suite) ?? .standard)
                .write(LastChannelKey(sourceID: home.id, channelID: "film"))
            let live = model(sources, gate: gate)
            live.appeared()
            live.sourcesChanged([home])
            while live.playing == nil { await Task.yield() }
            #expect(live.playing?.id == "film")
            #expect(live.seen[home.id] == nil, "the record waits behind the tune")

            await gate.release()
            await live.settled()
            #expect(live.seen[home.id] != nil)
        }

        @Test(
            "session-restore-and-recently-watched/the-last-channel-does-not-wait-for-bookkeeping New lists gained channels"
        )
        func newAfterRecord() async {
            _ = seenStore.record(home.id, channelIDs: ["a"], now: .now.addingTimeInterval(-86_400))
            let sources = Sources()
            sources.channels = [channel("a"), channel("b")]
            let live = model(sources)
            live.sourcesChanged([home])
            await live.settled()
            #expect(live.catalogue.rows(in: .new).map(\.id) == ["b"])
        }

        @Test(
            "live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive the same channels keep the catalogue"
        )
        func unchangedRefresh() async {
            let sources = Sources()
            sources.channels = (0..<50).map { channel("c\($0)") }
            let live = model(sources)
            live.sourcesChanged([home])
            await live.settled()
            let revision = live.catalogue.revision
            live.reload([home.id])
            await live.settled()
            #expect(sources.loads == 2)
            #expect(live.catalogue.revision == revision, "no new catalogue for the same channels")

            sources.channels.append(channel("extra"))
            live.reload([home.id])
            await live.settled()
            #expect(live.catalogue.count(of: .all) == 51, "a changed list still shows")
        }

        /// True when reading `rows` saw a change while `change` ran.
        private func rowsChanged(_ live: LiveModel, during change: () -> Void) -> Bool {
            let changed = Flag()
            withObservationTracking {
                _ = live.rows
            } onChange: {
                changed.set()
            }
            change()
            return changed.value
        }

        final class Flag: @unchecked Sendable {
            private(set) var value = false
            func set() { value = true }
        }

        @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive joining Recents leaves the open group's list alone")
        func recentsLeaveTheList() async {
            let sources = Sources()
            sources.channels = (0..<50).map { channel("c\($0)") }
            let live = model(sources)
            live.sourcesChanged([home])
            await live.settled()
            let key = LastChannelKey(sourceID: home.id, channelID: "c3")
            #expect(!rowsChanged(live) { live.recentsChanged([key]) }, "All channels did not change")
            #expect(live.catalogue.rows(in: .recents).map(\.id) == ["c3"])
            #expect(rowsChanged(live) { live.show(.recents) })
            #expect(live.rows.map(\.id) == ["c3"])
            #expect(!rowsChanged(live) { live.favoritesChanged([FavoriteSnapshot(channelID: "c1", sourceID: home.id, sortOrder: 0)]) })
        }
    }
#endif
