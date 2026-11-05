import SwiftUI
import SwiftData
import AntennaCore

struct ChannelsView: View {
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @Environment(\.sourceLoader) private var loader
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
            // Reloads on appearance and whenever a source is added, removed or
            // reordered, so deleted sources' channels do not linger.
            .task(id: sources.map(\.id)) {
                await model.load(sources.compactMap(\.descriptor), using: loader)
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

    /// Replaces `channels` with those of `sources`, in order. An empty list
    /// clears them. A load cancelled by a newer one changes nothing.
    func load(_ sources: [SourceDescriptor], using loader: SourceLoader) async {
        var all: [Channel] = []
        for source in sources {
            do {
                all += try await loader.load(source)
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
        guard !Task.isCancelled else { return }
        channels = all
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

    func load(_ source: SourceDescriptor) async throws -> [Channel] {
        switch source.kind {
        case .m3u:
            let (data, response) = try await session.data(from: source.url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LoadError.badStatus(http.statusCode)
            }
            let text = String(decoding: data, as: UTF8.self)
            return M3UParser().parse(text).channels
        case .xtream:
            guard let key = source.credentialKey,
                let cred = try credentials.load(for: key)
            else { return [] }
            let client = XtreamClient(
                credentials: .init(server: source.url, username: cred.username, password: cred.password),
                session: session)
            async let categories = client.liveCategories()
            async let streams = client.liveStreams()
            // Providers sometimes repeat a category id; the first name wins.
            let names = Dictionary(
                try await categories.map { ($0.categoryID, $0.categoryName) }, uniquingKeysWith: { first, _ in first })
            return try await streams.map { client.channel(from: $0, categoryName: $0.categoryID.flatMap { names[$0] }) }
        case .stalker:
            // TODO: Stalker/MAG portal handshake (handshake → get_profile → get_all_channels).
            return []
        }
    }
}
