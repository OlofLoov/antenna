import AntennaCore
import SwiftUI

extension Browse {
    /// The open group under the now-playing line on iPhone (`iPhone-Live-Groups`,
    /// live-tv-on-iphone-ipad-mac/pick-a-group): its name in its own text
    /// run, a middle dot, its channel count and a chevron, leading-aligned
    /// across the width. A plain button with no fill; tapping it opens the
    /// Groups sheet.
    struct GroupButton: View {
        let name: String
        let count: Int
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: name)
                        .font(.headline)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Group {
                        Text(verbatim: "·")
                        Text(count, format: .number)
                            .monospacedDigit()
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Browse.spokenGroup(name, count: count)))
            .accessibilityHint(Text("Opens the list of groups"))
        }
    }

    /// A group in the Groups sheet: a checkmark on the open one, the
    /// built-in group's glyph, the name, and the count at the trailing edge.
    /// A locked group has a lock and no count.
    struct GroupChoiceRow: View {
        @Environment(\.accent) private var accent
        let name: String
        let systemImage: String?
        /// The channel count; nil for a locked group.
        let count: Int?
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent.color)
                        .opacity(isSelected ? 1 : 0)
                        .accessibilityHidden(true)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(Palette.textMuted)
                            .frame(minWidth: 22)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: name)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let count {
                        Text(count, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textMuted)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }

        private var label: Text {
            if let count { Text(Browse.spokenGroup(name, count: count)) } else { Text("\(name), locked") }
        }
    }
}

extension Browse {
    /// What VoiceOver reads for a group: "Sport, 42 channels", or "Sport, 1 channel".
    static func spokenGroup(_ name: String, count: Int) -> LocalizedStringResource {
        "\(name), \(count) channels"
    }
}

#Preview("Group button") {
    VStack(spacing: 0) {
        Browse.GroupButton(name: "All channels", count: 1240) {}
        Browse.GroupButton(name: "UK ▸ SPORTS HD | BACKUP FEEDS FOR THE WEEKEND", count: 64) {}
        Browse.GroupButton(name: "أخبار", count: 22) {}
    }
    .frame(width: 390)
    .background(Palette.ground)
}

#Preview("Group rows") {
    List {
        Section {
            Browse.GroupChoiceRow(name: "Favorites", systemImage: "star", count: 12, isSelected: false) {}
            Browse.GroupChoiceRow(name: "All channels", systemImage: nil, count: 1240, isSelected: false) {}
        }
        Section {
            Browse.GroupChoiceRow(name: "SE | NEWS", systemImage: nil, count: 18, isSelected: false) {}
            Browse.GroupChoiceRow(name: "SE | SPORT", systemImage: nil, count: 42, isSelected: true) {}
            Browse.GroupChoiceRow(name: "AR | أخبار", systemImage: nil, count: 22, isSelected: false) {}
            Browse.GroupChoiceRow(name: "PPV EVENTS", systemImage: nil, count: nil, isSelected: false) {}
        }
    }
    .frame(width: 390, height: 520)
}
