import SwiftUI
import SwiftData
import AntennaCore

struct ChannelsView: View {
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @Environment(\.sourceLoader) private var loader
    @Environment(\.guideStore) private var guideStore
    @State private var model = ChannelListModel()

    var body: some View {
        NavigationStack {
            Group {
                if sources.isEmpty {
                    ContentUnavailableView(
                        "No sources yet",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text(
                            "Add an M3U playlist or Xtream login under Settings. It syncs to your other devices through iCloud.")
                    )
                    .accessibilityIdentifier("channels.emptyState")
                } else if model.channels.isEmpty {
                    ProgressView("Loading channels…")
                        .task { await model.load(sources.compactMap(\.descriptor), using: loader, guide: guideStore) }
                } else {
                    List(model.channels) { channel in
                        NavigationLink(value: channel) {
                            ChannelRow(channel: channel)
                        }
                    }
                    .navigationDestination(for: Channel.self) { channel in
                        PlayerView(channel: channel)
                            .accessibilityIdentifier("player.view")
                    }
                }
            }
            .navigationTitle("Channels")
        }
    }
}

struct ChannelRow: View {
    let channel: Channel

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.logoURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading) {
                Text(channel.name)
                if let group = channel.group {
                    Text(group).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if channel.hasCatchup {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Channel row") {
    List {
        ChannelRow(
            channel: Channel(
                id: "1",
                name: "Sample One",
                streamURL: URL(filePath: "/sample/one.ts"),
                group: "News"
            ))
        ChannelRow(
            channel: Channel(
                id: "2",
                name: "Sample Two",
                streamURL: URL(filePath: "/sample/two.ts"),
                group: "Sport",
                hasCatchup: true
            ))
    }
}

@MainActor @Observable
final class ChannelListModel {
    var channels: [Channel] = []
    var error: String?

    /// Loads every source in order and shows the channels. Then, per source
    /// that loaded, tells `guide` its playlist's guide links and channels and
    /// asks it to refresh stale guides. A source that failed is skipped. The
    /// guide calls run in a task of their own, because showing the channels
    /// ends the view task that called this.
    func load(_ sources: [SourceDescriptor], using loader: SourceLoader, guide: (any GuideStore)? = nil) async {
        var all: [Channel] = []
        var loaded: [(sourceID: UUID, playlist: Playlist)] = []
        for source in sources {
            do {
                let playlist = try await loader.load(source)
                let tagged = Channel.tagged(playlist.channels, sourceID: source.id)
                all += tagged
                loaded.append((source.id, Playlist(channels: tagged, epgURLs: playlist.epgURLs)))
            } catch {
                self.error = error.localizedDescription
            }
        }
        channels = all
        guard let guide else { return }
        Task {
            for (sourceID, playlist) in loaded {
                await guide.register(epgURLs: playlist.epgURLs, for: sourceID)
                await guide.update(channels: playlist.channels)
                await guide.refreshIfStale(now: .now)
            }
        }
    }
}

extension EnvironmentValues {
    /// The loader `ChannelsView` uses. Tests replace it with one on a stubbed session.
    @Entry var sourceLoader = SourceLoader()
}

/// Turns a stored source into channels. Lives in the app layer because it
/// needs the Keychain; the parsers themselves are in AntennaCore.
struct SourceLoader: Sendable {
    var session: URLSession = .shared
    var credentials: any CredentialStoring = CredentialStore()

    /// The source's channels, and for a playlist the guide links its header names.
    func load(_ source: SourceDescriptor) async throws -> Playlist {
        switch source.kind {
        case .m3u:
            let (data, _) = try await session.data(from: source.url)
            let text = String(decoding: data, as: UTF8.self)
            return M3UParser().parse(text)
        case .xtream:
            guard let key = source.credentialKey,
                let cred = try credentials.load(for: key)
            else { return Playlist(channels: []) }
            let client = XtreamClient(
                credentials: .init(server: source.url, username: cred.username, password: cred.password),
                session: session)
            async let categories = client.liveCategories()
            async let streams = client.liveStreams()
            let names = Dictionary(uniqueKeysWithValues: try await categories.map { ($0.categoryID, $0.categoryName) })
            return Playlist(channels: try await streams.map { client.channel(from: $0, categoryName: $0.categoryID.flatMap { names[$0] }) })
        case .stalker:
            // TODO: Stalker/MAG portal handshake (handshake → get_profile → get_all_channels).
            return Playlist(channels: [])
        }
    }
}
