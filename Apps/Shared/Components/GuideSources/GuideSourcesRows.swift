import AntennaCore
import SwiftUI

/// The Guide sources screen's parts (boards `iPhone-GuideSources`,
/// `iPhone-GuideSources-Diagnosis`, `iPad-GuideSources`, `TV-GuideSources`).
/// Each takes values and closures; the screen decides what a tap does.
enum GuideSourcesRows {
    static func color(_ style: GuideSourcesText.Style) -> AnyShapeStyle {
        switch style {
        case .normal: AnyShapeStyle(.primary)
        case .muted: AnyShapeStyle(.secondary)
        case .error: AnyShapeStyle(OnboardingForm.errorColor)
        }
    }

    /// A guide: its name, its redacted link, and its status line, with
    /// Retry now beside a failed one.
    struct Guide: View {
        let name: String
        let address: String?
        let status: GuideSourcesText.Line
        let identifier: String
        let select: () -> Void
        let retry: (() -> Void)?

        var body: some View {
            HStack(spacing: 12) {
                Button(action: select) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .lineLimit(1)
                        if let address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Text(status.text)
                            .font(.footnote)
                            .foregroundStyle(GuideSourcesRows.color(status.style))
                            .lineLimit(2)
                            .accessibilityIdentifier("\(identifier).status")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
                if let retry {
                    Button(GuideSourcesText.retry, action: retry)
                        .accessibilityIdentifier("\(identifier).retry")
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// A channel: logo or initials, name, number and a short label.
    struct Channel: View {
        let name: String
        let number: String?
        let logo: URL?
        let label: String
        let identifier: String
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                HStack(spacing: 12) {
                    Logo(name: name, logo: logo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .lineLimit(1)
                        if let number {
                            Text(number)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
    }

    /// A logo, or the channel's initials when it has none
    /// (design-system/channels-without-a-logo-show-initials).
    struct Logo: View {
        let name: String
        let logo: URL?
        @ScaledMetric(relativeTo: .body) private var width: CGFloat = 44

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Palette.surface(0.08))
                if let logo {
                    AsyncImage(url: logo) { image in
                        image.resizable().scaledToFit().padding(4)
                    } placeholder: {
                        initials
                    }
                } else {
                    initials
                }
            }
            .frame(width: width, height: width * 0.66)
            .accessibilityHidden(true)
        }

        private var initials: some View {
            Text(AntennaCore.Channel.initials(for: name))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    /// Why a channel has no guide, or where its guide comes from.
    struct Card: View {
        let card: GuideSourcesText.Card

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title.text)
                    .font(.headline)
                    .foregroundStyle(GuideSourcesRows.color(card.title.style))
                    .accessibilityIdentifier("guideSources.reason.title")
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(card.body.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("guideSources.reason.body")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    /// A guide entry in the picker: its name with the matched words tinted,
    /// and "<id> · <guide> · <n> programmes".
    struct Entry: View {
        let name: String
        let nameRanges: [Range<String.Index>]
        let detail: String
        let detailRanges: [Range<String.Index>]
        let identifier: String
        let pick: () -> Void

        var body: some View {
            Button(action: pick) {
                VStack(alignment: .leading, spacing: 2) {
                    SearchRow.Highlighted(text: name, ranges: nameRanges)
                        .lineLimit(1)
                    SearchRow.Highlighted(text: detail, ranges: detailRanges)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
    }
}

#Preview("Guide sources rows") {
    List {
        Section("Guide sources") {
            GuideSourcesRows.Guide(
                name: "Guide URL", address: "https://epg.sportpack.tv/….gz",
                status: GuideSourcesText.Line("Loaded · 388 of 412 channels · 7 days"), identifier: "guideSources.row.0", select: {},
                retry: nil)
            GuideSourcesRows.Guide(
                name: "epg-mirror.example.org", address: "epg-mirror.example.org/…",
                status: GuideSourcesText.Line("Could not download · Server returned 404", .error), identifier: "guideSources.row.1",
                select: {}, retry: {})
        }
        Section("Channels without guide · 2") {
            GuideSourcesRows.Channel(
                name: "Sport One", number: "104", logo: nil, label: "Id not found", identifier: "guideSources.channels.row.0", select: {})
            GuideSourcesRows.Channel(
                name: "Arena HD", number: "106", logo: nil, label: "No guide id", identifier: "guideSources.channels.row.1", select: {})
        }
        Section {
            GuideSourcesRows.Card(
                card: GuideSourcesText.Card(
                    title: GuideSourcesText.Line("Guide id “sport1” is not in the guide"),
                    body: ["“Guide URL” does not list “sport1”. Pick an entry below.", "1 of 3 guides could not be downloaded."]))
            GuideSourcesRows.Entry(
                name: "Sport One", nameRanges: [], detail: "sportone · Guide URL · 212 programmes", detailRanges: [],
                identifier: "guideSources.picker.row.0", pick: {})
        }
    }
    .preferredColorScheme(.dark)
}
