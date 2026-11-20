import AntennaCore
import SwiftUI

/// A profile's color circle with its initial in the ground color.
struct ProfileBadge: View {
    let tile: ProfileTile
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: tile.color))
            Text(tile.initial)
                .font(.system(size: size * 0.43, weight: .bold))
                .foregroundStyle(Palette.ground)
        }
        .frame(width: size, height: size)
    }
}

/// The eight profile colors to pick from, the selected one ringed
/// (`iPhone-Profiles-Edit`). Each is a 44 pt target.
struct ProfileColorRow: View {
    let selected: Int
    let pick: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Profile.colors.indices, id: \.self) { index in
                Button {
                    pick(index)
                } label: {
                    Circle()
                        .fill(Color(hex: Profile.colors[index]))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(index == selected ? Palette.text : .clear, lineWidth: 3))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(index + 1)")
                .accessibilityAddTraits(index == selected ? .isSelected : [])
                .accessibilityIdentifier("profiles.edit.color.\(index)")
            }
        }
    }
}

/// The five accents to pick from in the profile editor, the picked one
/// ringed (`iPhone-Profiles-Edit-Accent`, `TV-Profiles-Edit-Accent`;
/// profiles/editing-and-deleting-a-profile). Each is a 44 pt target, 72 pt
/// on Apple TV, where the focused one lifts as the colors do.
struct ProfileAccentRow: View {
    let selected: ProfileAccent
    let pick: (ProfileAccent) -> Void

    #if os(tvOS)
        private let side: CGFloat = 72
        private let ring: CGFloat = 5
        private let spacing: CGFloat = 28
    #else
        private let side: CGFloat = 36
        private let ring: CGFloat = 3
        private let spacing: CGFloat = 4
    #endif

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(ProfileAccent.allCases) { accent in
                Button {
                    pick(accent)
                } label: {
                    Circle()
                        .fill(accent.color)
                        .frame(width: side, height: side)
                        .overlay(Circle().strokeBorder(accent == selected ? Palette.text : .clear, lineWidth: ring))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(accent.title))
                .accessibilityAddTraits(accent == selected ? .isSelected : [])
                .accessibilityIdentifier("profiles.edit.accent.\(accent.rawValue)")
            }
        }
    }
}

#Preview("Profile badge and colors", traits: .fixedLayout(width: 390, height: 300)) {
    VStack(spacing: 28) {
        ProfileBadge(tile: ProfileTile(id: Profile.mainID, name: "Kids", initial: "K", color: Profile.colors[5]), size: 112)
        ProfileColorRow(selected: 5) { _ in }
        ProfileAccentRow(selected: .amber) { _ in }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.ground)
}
