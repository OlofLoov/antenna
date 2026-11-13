import AntennaCore
import SwiftUI

/// One source in the Sources list (`iPhone-Settings`, `iPad-Settings`,
/// `TV-Settings`): the name, the type badge and the status lines. Never a link.
/// Text and badge take their colors from the row, so a focused row on Apple
/// TV draws them dark on its light platter (design-system/focus-is-the-lifted-white-card).
struct SourceRowLabel: View {
    let name: String
    let kind: SourceKind
    let lines: [SourceStatusText.Line]

    static func badge(_ kind: SourceKind) -> String {
        switch kind {
        case .m3u: "M3U"
        case .xtream: "XTREAM"
        case .stalker: "STALKER"
        case .jellyfin: "JELLYFIN"
        case .channelsDVR: "CHANNELS DVR"
        case .m3uFile: "FILE"
        }
    }

    /// The type as the add-source kinds name it, for a lead column.
    static func kindName(_ kind: SourceKind) -> String {
        switch kind {
        case .m3u: "M3U playlist"
        case .xtream: "Xtream login"
        case .stalker: "Stalker portal"
        case .jellyfin: "Jellyfin"
        case .channelsDVR: "Channels DVR"
        case .m3uFile: "Playlist file"
        }
    }

    /// The status lines: footnote on iPhone, iPad and Mac, caption 1 (25 pt) on Apple TV.
    private static var lineFont: Font {
        #if os(tvOS)
            .caption
        #else
            .footnote
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxSmall) {
            HStack(spacing: Metrics.Spacing.xSmall) {
                Text(name).font(.body.weight(.semibold))
                Text(Self.badge(kind))
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .padding(.horizontal, Metrics.Spacing.xSmall)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Metrics.Corner.small.shape())
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: Metrics.Spacing.xSmall) {
                    if line.busy { ProgressView().controlSize(.mini) }
                    Text(line.text)
                        .font(Self.lineFont)
                        .foregroundStyle(style(line.style))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func style(_ style: SourceStatusText.Line.Style) -> AnyShapeStyle {
        switch style {
        case .normal: AnyShapeStyle(.secondary)
        case .muted: AnyShapeStyle(.tertiary)
        case .error: AnyShapeStyle(OnboardingForm.errorColor)
        }
    }
}

#Preview("Source rows") {
    List {
        SourceRowLabel(name: "Home provider", kind: .xtream, lines: [.init("412 channels · Guide 7 days · 12 minutes ago")])
        SourceRowLabel(name: "Family login", kind: .xtream, lines: [.init("Waiting for login from iCloud", style: .muted)])
        SourceRowLabel(
            name: "Playlist (old)", kind: .m3u,
            lines: [
                .init("1 240 channels · Guide 3 days · yesterday"),
                .init("Could not refresh: You're offline. Connect to the internet and try again.", style: .error),
            ])
        SourceRowLabel(name: "Cabin", kind: .m3u, lines: [.init("Loading…", busy: true)])
    }
    .preferredColorScheme(.dark)
}

#Preview("Source rows, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    List {
        SourceRowLabel(name: "Home provider", kind: .xtream, lines: [.init("412 channels · Guide 7 days · 12 minutes ago")])
        SourceRowLabel(name: "Family login", kind: .xtream, lines: [.init("Not signed in on this Apple TV", style: .muted)])
    }
    .padding(Metrics.televisionSafeArea)
    .preferredColorScheme(.dark)
}
