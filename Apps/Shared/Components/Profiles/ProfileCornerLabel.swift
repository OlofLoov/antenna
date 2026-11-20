import AntennaCore
import SwiftUI

/// The profile button's face at the top right of the iPhone tabs
/// (`iPhone-Profile-Menu`): the current profile's color and initial in a
/// 32 pt circle, or a person glyph when there is only one profile. A
/// 44 pt target either way. Plain, with no glass, since it sits on the
/// ground color and over Movies art alike.
struct ProfileCornerLabel: View {
    /// The current profile, nil with one profile.
    let tile: ProfileTile?

    var body: some View {
        Group {
            if let tile {
                ProfileBadge(tile: tile, size: 32)
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.title)
                    .foregroundStyle(Palette.text)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}

#Preview("Profile corner", traits: .fixedLayout(width: 160, height: 64)) {
    HStack(spacing: 16) {
        ProfileCornerLabel(tile: nil)
        ProfileCornerLabel(tile: ProfileTile(id: Profile.mainID, name: "Kids", initial: "K", color: Profile.colors[5]))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.ground)
}
