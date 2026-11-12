import SwiftUI

/// One group on the Groups screen (`TV-Groups`, `iPad-Groups`,
/// `iPhone-Groups`): its name, the Locked, Hidden or Custom badges and its
/// channel count. A hidden group's name is muted.
struct GroupRow: View {
    enum Badge: String, CaseIterable {
        case locked = "LOCKED"
        case hidden = "HIDDEN"
        case custom = "CUSTOM"
    }

    let name: String
    let count: Int
    let badges: [Badge]

    var body: some View {
        HStack(spacing: 12) {
            if badges.contains(.locked) {
                Image(systemName: "lock.fill").foregroundStyle(Palette.textMuted).accessibilityHidden(true)
            }
            Text(name)
                .foregroundStyle(badges.contains(.hidden) ? Palette.textMuted : Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(badges, id: \.self) { badge in
                Text(badge.rawValue)
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
        let parts = [name] + badges.map { $0.rawValue.capitalized } + [count == 1 ? "1 channel" : "\(count) channels"]
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
