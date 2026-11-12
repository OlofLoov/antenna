import AntennaCore
import SwiftUI

/// One source in the Sources list (`iPhone-Settings`, `iPad-Settings`,
/// `TV-Settings`): the name, the type badge and the status lines. Never a link.
struct SourceRowLabel: View {
    let name: String
    let kind: SourceKind
    let lines: [SourceStatusText.Line]
    var metrics = Metrics.phone

    struct Metrics {
        var name: CGFloat
        var line: CGFloat
        var badge: CGFloat

        static let phone = Metrics(name: 17, line: 13, badge: 11)
        static let television = Metrics(name: 29, line: 22, badge: 18)
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(name).font(.system(size: metrics.name, weight: .semibold))
                Text(Self.badge(kind))
                    .font(.system(size: metrics.badge, weight: .bold))
                    .tracking(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 6) {
                    if line.busy { ProgressView().controlSize(.mini) }
                    Text(line.text)
                        .font(.system(size: metrics.line))
                        .foregroundStyle(color(line.style))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func color(_ style: SourceStatusText.Line.Style) -> Color {
        switch style {
        case .normal: Palette.textMuted
        case .muted: Palette.textMuted.opacity(0.8)
        case .error: OnboardingForm.errorColor
        }
    }
}

#Preview("Source rows") {
    VStack(alignment: .leading, spacing: 20) {
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
    .padding()
    .background(Palette.ground)
    .preferredColorScheme(.dark)
}

#Preview("Source rows, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    VStack(alignment: .leading, spacing: 30) {
        SourceRowLabel(
            name: "Home provider", kind: .xtream, lines: [.init("412 channels · Guide 7 days · 12 minutes ago")], metrics: .television)
        SourceRowLabel(
            name: "Family login", kind: .xtream, lines: [.init("Not signed in on this Apple TV", style: .muted)], metrics: .television)
    }
    .padding(80)
    .background(Palette.ground)
    .preferredColorScheme(.dark)
}
