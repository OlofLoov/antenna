import SwiftUI

/// One group on the Groups screen (`TV-Groups`, `iPad-Groups`,
/// `iPhone-Groups`): its name, the Locked, Hidden or Custom badges and its
/// channel count. A hidden group's name is muted.
struct GroupRow: View {
    /// The raw value is the suffix of the row's accessibility identifier.
    enum Badge: String, CaseIterable {
        case locked
        case hidden
        case custom

        /// The badge as the row shows it.
        var title: LocalizedStringResource {
            switch self {
            case .locked: "LOCKED"
            case .hidden: "HIDDEN"
            case .custom: "CUSTOM"
            }
        }

        /// The badge as VoiceOver reads it.
        var spoken: LocalizedStringResource {
            switch self {
            case .locked: "Locked"
            case .hidden: "Hidden"
            case .custom: "Custom"
            }
        }
    }

    let name: String
    let count: Int
    let badges: [Badge]
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            if badges.contains(.locked) {
                Image(systemName: "lock.fill").foregroundStyle(Palette.textMuted).accessibilityHidden(true)
            }
            Text(name)
                .foregroundStyle(badges.contains(.hidden) ? Palette.textMuted : Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(badges, id: \.self) { badge in
                Text(badge.title)
                    .font(.caption.bold())
                    .tracking(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            Text("\(count)").monospacedDigit().foregroundStyle(Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        let words = Words(locale)
        let parts = [name] + badges.map { words($0.spoken) } + [words(count == 1 ? "1 channel" : "\(count) channels")]
        return parts.joined(separator: ", ")
    }
}

#Preview("Rows") {
    List {
        GroupRow(name: "All channels", count: 412, badges: [])
        GroupRow(name: "Movies", count: 58, badges: [.locked])
        GroupRow(name: "Adult", count: 36, badges: [.hidden])
        GroupRow(name: "Weekend sports", count: 6, badges: [.custom])
    }
}
