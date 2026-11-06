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
            // Runs on appearance and whenever a source is added, removed,
            // reordered or edited by sync. The model skips sources it already
            // loaded channels for.
            .task(id: sources.compactMap(\.descriptor)) {
                await model.load(sources.compactMap(\.descriptor), using: loader, guide: guideStore)
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

    /// The sources the current `channels` came from.
    private var loadedSources: [SourceDescriptor]?

    /// Replaces `channels` with those of `sources`, in order, and `error` with
    /// this load's last failure. An empty list clears both. When `sources` is
    /// what the current channels came from and there are channels, nothing is
    /// downloaded; with zero channels it tries again. A load cancelled by a
    /// newer one changes nothing.
    ///
    /// After a load, per source that loaded, tells `guide` its playlist's
    /// guide links and channels and asks it to refresh stale guides. A source
    /// that failed is skipped. The guide calls run in a task of their own, so
    /// the view task ending does not cut them short.
    func load(_ sources: [SourceDescriptor], using loader: SourceLoader, guide: AppGuideStore? = nil) async {
        if sources == loadedSources, !channels.isEmpty { return }
        var failure: String?
        var all: [Channel] = []
        var loaded: [(sourceID: UUID, playlist: Playlist)] = []
        for source in sources {
            do {
                let playlist = try await loader.load(source)
                let tagged = Channel.tagged(playlist.channels, sourceID: source.id)
                all += tagged
                loaded.append((source.id, Playlist(channels: tagged, epgURLs: playlist.epgURLs)))
            } catch {
                failure = error.localizedDescription
            }
        }
        guard !Task.isCancelled else { return }
        channels = all
        error = failure
        loadedSources = sources
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

    enum LoadError: LocalizedError, Equatable {
        /// The playlist URL answered with a status outside 200 to 299.
        case badStatus(Int)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): "The playlist server answered with status \(code)."
            }
        }
    }

    /// False when an Xtream or Stalker source has no Keychain item on this
    /// device yet. An item that cannot be read counts as present, so the load
    /// runs and reports the failure.
    func hasLogin(_ source: SourceDescriptor) -> Bool {
        guard source.kind != .m3u else { return true }
        guard let key = source.credentialKey else { return false }
        do {
            return try credentials.load(for: key) != nil
        } catch {
            return true
        }
    }

    /// The source's channels, and for a playlist the guide links its header names.
    func load(_ source: SourceDescriptor) async throws -> Playlist {
        switch source.kind {
        case .m3u:
            let (data, response) = try await session.data(from: source.url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LoadError.badStatus(http.statusCode)
            }
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
            // Providers sometimes repeat a category id; the first name wins.
            let names = Dictionary(
                try await categories.map { ($0.categoryID, $0.categoryName) }, uniquingKeysWith: { first, _ in first })
            return Playlist(
                channels: try await streams.map {
                    client.channel(from: $0, categoryName: $0.categoryID.flatMap { names[$0] })
                })
        case .stalker:
            // TODO: Stalker/MAG portal handshake (handshake → get_profile → get_all_channels).
            return Playlist(channels: [])
        }
    }
}
