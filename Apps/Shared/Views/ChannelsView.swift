import SwiftUI
import SwiftData
import AntennaCore

struct ChannelsView: View {
    @Query(sort: \SourceRecord.sortOrder) private var sources: [SourceRecord]
    @State private var model = ChannelListModel()

    var body: some View {
        NavigationStack {
            Group {
                if sources.isEmpty {
                    ContentUnavailableView(
                        "No sources yet",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Add an M3U playlist or Xtream login under Settings. It syncs to your other devices through iCloud.")
                    )
                } else if model.channels.isEmpty {
                    ProgressView("Loading channels…")
                        .task { await model.load(sources.compactMap(\.descriptor)) }
                } else {
                    List(model.channels) { channel in
                        NavigationLink(value: channel) {
                            ChannelRow(channel: channel)
                        }
                    }
                    .navigationDestination(for: Channel.self) { channel in
                        PlayerView(channel: channel)
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

@MainActor @Observable
final class ChannelListModel {
    var channels: [Channel] = []
    var error: String?

    func load(_ sources: [SourceDescriptor]) async {
        var all: [Channel] = []
        for source in sources {
            do {
                all += try await SourceLoader.load(source)
            } catch {
                self.error = error.localizedDescription
            }
        }
        channels = all
    }
}

/// Turns a stored source into channels. Lives in the app layer because it
/// needs the Keychain; the parsers themselves are in AntennaCore.
enum SourceLoader {
    static func load(_ source: SourceDescriptor) async throws -> [Channel] {
        switch source.kind {
        case .m3u:
            let (data, _) = try await URLSession.shared.data(from: source.url)
            let text = String(decoding: data, as: UTF8.self)
            return M3UParser().parse(text).channels
        case .xtream:
            guard let key = source.credentialKey,
                  let cred = try CredentialStore().load(for: key) else { return [] }
            let client = XtreamClient(credentials: .init(server: source.url, username: cred.username, password: cred.password))
            async let categories = client.liveCategories()
            async let streams = client.liveStreams()
            let names = Dictionary(uniqueKeysWithValues: try await categories.map { ($0.categoryID, $0.categoryName) })
            return try await streams.map { client.channel(from: $0, categoryName: $0.categoryID.flatMap { names[$0] }) }
        case .stalker:
            // TODO: Stalker/MAG portal handshake (handshake → get_profile → get_all_channels).
            return []
        }
    }
}
