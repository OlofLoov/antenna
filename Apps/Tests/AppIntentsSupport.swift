import AntennaCore
import Foundation
import SwiftData

@testable import Antenna

#if os(iOS) || os(macOS)
    /// An in-memory store, stand-in loaders and the stand-in entitlement for
    /// running the Siri and Shortcuts actions in tests.
    @MainActor
    final class IntentHarness {
        let container: ModelContainer
        let host: AppIntentHost
        /// Each source's channels; a missing entry fails the load as offline.
        var playlists: [UUID: [Channel]] = [:]
        var titles: [UUID: [ShelfTitle]] = [:]
        var logins: Set<UUID>
        private(set) var loads: [UUID] = []
        private(set) var forwardRequests = 0
        /// True when the system refuses to bring Antenna forward.
        var refuseForeground = false
        /// Holds every load until released, to test the deadline and shared
        /// loads. While set the deadline passes at once; otherwise it is a
        /// minute, so an unheld load always answers first.
        var holdLoads = false {
            didSet { expiry.now = holdLoads }
        }
        private let expiry: Expiry

        private final class Expiry: @unchecked Sendable {
            var now = false
        }
        private var held: [CheckedContinuation<Void, Never>] = []

        init(unlocked: Bool = true, sources: [SourceDescriptor], protectedData: Bool = true) throws {
            let expiry = Expiry()
            self.expiry = expiry
            container = try ModelContainer(
                for: Schema(AntennaSchema.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            for (order, source) in zip(sources.indices, sources) {
                container.mainContext.insert(SourceRecord(descriptor: source, sortOrder: order))
            }
            try container.mainContext.save()
            logins = Set(sources.map(\.id))
            let grant = Grant(kind: .lifetime, verifiedAt: Date(timeIntervalSince1970: 1_800_000_000))
            let (unlock, _) = Unlock.fixed(unlocked ? .entitled(grant) : .notEntitled(.neverPurchased)) { ScriptedPaywallStore() }
            weak var weakSelf: IntentHarness?
            var dependencies = AppIntentHost.Dependencies(
                container: container, isUnlocked: { unlock.gate.applied.isUnlocked },
                loadPlaylist: { source in
                    try await weakSelf?.load(source.id)
                    guard let channels = weakSelf?.playlists[source.id] else { throw URLError(.notConnectedToInternet) }
                    return Playlist(channels: channels)
                },
                hasLogin: { weakSelf?.logins.contains($0.id) ?? false },
                loadTitles: { source, kind in
                    try await weakSelf?.load(source.id)
                    guard let titles = weakSelf?.titles[source.id] else { throw URLError(.badServerResponse) }
                    return titles.filter { $0.kind == kind }
                })
            dependencies.protectedDataAvailable = { protectedData }
            dependencies.profile = { Profile.mainID }
            dependencies.sleep = { _ in
                if expiry.now { await Task.yield() } else { try await Task.sleep(for: .seconds(60)) }
            }
            dependencies.favoritesChanged = {}
            dependencies.bringForward = {
                guard let harness = weakSelf else { return }
                harness.forwardRequests += 1
                if harness.refuseForeground { throw IntentFailure.notUnlocked }
            }
            host = AppIntentHost(dependencies)
            weakSelf = self
            IntentContext.provider = host
        }

        private func load(_ id: UUID) async throws {
            loads.append(id)
            if holdLoads { await withCheckedContinuation { held.append($0) } }
        }

        /// Lets every held load finish.
        func release() {
            holdLoads = false
            held.forEach { $0.resume() }
            held = []
        }

        var context: ModelContext { container.mainContext }

        func favorites() throws -> [FavoriteRecord] {
            try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
        }

        /// The entity Shortcuts would hand the action for a saved reference.
        func channel(_ source: UUID, _ id: String) async -> ChannelEntity? {
            await IntentQueries.channels([LastChannelKey(sourceID: source, channelID: id).string]).first
        }
    }

    enum IntentFixtures {
        static func source(_ name: String, kind: SourceKind = .m3u, id: UUID = UUID()) -> SourceDescriptor {
            SourceDescriptor(id: id, name: name, kind: kind, url: URL(filePath: "/sources/\(name.lowercased())"))
        }

        static func channel(_ id: String, _ name: String, number: Int? = nil, group: String? = nil) -> Channel {
            Channel(id: id, name: name, streamURL: URL(fileURLWithPath: "/\(id).ts"), group: group, number: number)
        }
    }
#endif
