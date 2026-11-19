import SwiftUI

extension Browse {
    /// One source in the loading list (`iPhone-Loading`, `iPad-Loading`).
    struct LoadingRow: Identifiable, Equatable, Sendable {
        enum Status: Equatable, Sendable {
            /// Still loading: a spinner.
            case loading
            /// Done: "412 channels", "No channels", "Could not load" or the like.
            case done(LocalizedStringResource)
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

    /// The banner over the channels naming the sources that failed, with
    /// Try again and a dismiss button (`iPhone-Banner`, `iPad-Banner`).
    struct FailureBanner: View {
        let text: LocalizedStringResource
        /// The banner's identifier, and the start of its parts' identifiers.
        var identifier = "browse.banner.failed"
        let retry: () -> Void
        let dismiss: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                Text(text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("\(identifier).text")
                Button("Try again", action: retry)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("\(identifier).retry")
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.boardStyle(13, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("\(identifier).dismiss")
            }
            .foregroundStyle(Palette.text)
            .padding(.leading, 14)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
        }
    }

    /// "Office · waiting for login": text only, no Try again and no dismiss.
    struct WaitingNote: View {
        let text: LocalizedStringResource

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

#Preview("Banners", traits: .fixedLayout(width: 390, height: 140)) {
    VStack(spacing: 8) {
        Browse.FailureBanner(text: "Could not load Cabin M3U", retry: {}, dismiss: {})
        Browse.WaitingNote(text: "Office · waiting for login")
    }
    .padding(16)
    .background(Palette.ground)
}
