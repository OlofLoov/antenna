import SwiftUI

extension Browse {
    /// One source in the loading list (`iPhone-Loading`, `iPad-Loading`).
    struct LoadingRow: Identifiable, Equatable, Sendable {
        enum Status: Equatable, Sendable {
            /// Still loading: a spinner.
            case loading
            /// Done: "412 channels", "No channels", "Could not load" or the like.
            case done(String)
        }

        var id: UUID
        var name: String
        var status: Status
    }

    /// Each source with its channel count or a spinner, in place of the
    /// list while sources load.
    struct LoadingList: View {
        let rows: [LoadingRow]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack {
                        Text(row.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        switch row.status {
                        case .loading:
                            ProgressView()
                                .accessibilityLabel("Loading")
                        case .done(let text):
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 60)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("browse.loading.\(row.id.uuidString)")
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.text)
            .padding(.top, 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("browse.loading")
        }
    }

    /// A centered message in place of the list: a 17 pt title, 15 pt lines
    /// under it and a Retry button (`iPhone-Error`, `iPad-Error`, `iPad-Empty`).
    struct Message: View {
        let title: String
        let lines: [String]
        let retry: () -> Void

        var body: some View {
            VStack(spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(Browse.textSecondary)
                }
                Button(action: retry) {
                    Text("Retry")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .background(Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .accessibilityIdentifier("browse.retry")
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The banner over the channels naming the sources that failed, with
    /// Retry and a dismiss button (`iPhone-Banner`, `iPad-Banner`).
    struct FailureBanner: View {
        let text: String
        let retry: () -> Void
        let dismiss: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                Text(text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("browse.banner.failed.text")
                Button("Retry", action: retry)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("browse.banner.failed.retry")
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("browse.banner.failed.dismiss")
            }
            .foregroundStyle(Palette.text)
            .padding(.leading, 14)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("browse.banner.failed")
        }
    }

    /// "Office · waiting for login": text only, no Retry and no dismiss.
    struct WaitingNote: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Browse.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private let previewIDs = [
    UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
    UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
]

#Preview("Loading list", traits: .fixedLayout(width: 390, height: 200)) {
    Browse.LoadingList(rows: [
        .init(id: previewIDs[0], name: "Home server", status: .done("412 channels")),
        .init(id: previewIDs[1], name: "Cabin M3U", status: .loading),
    ])
    .background(Palette.ground)
}

#Preview("Offline", traits: .fixedLayout(width: 390, height: 300)) {
    Browse.Message(title: "You're offline.", lines: ["Connect to the internet and try again."]) {}
        .background(Palette.ground)
}

#Preview("Nothing loaded", traits: .fixedLayout(width: 352, height: 300)) {
    Browse.Message(title: "Could not load channels", lines: ["Cabin M3U: waiting for its login to sync from iCloud"]) {}
        .background(Palette.ground)
}

#Preview("Banners", traits: .fixedLayout(width: 390, height: 140)) {
    VStack(spacing: 8) {
        Browse.FailureBanner(text: "Could not load Cabin M3U", retry: {}, dismiss: {})
        Browse.WaitingNote(text: "Office · waiting for login")
    }
    .padding(16)
    .background(Palette.ground)
}
