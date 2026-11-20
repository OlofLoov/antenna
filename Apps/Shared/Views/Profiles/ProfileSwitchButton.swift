#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The current profile's color and initial at the top of Settings on
    /// Apple TV, with two or more profiles (tvos-shell/the-tabs-in-order,
    /// `TV-Shell-TabView`). Select goes back to "Who's watching?" through
    /// the `switchProfile` the shell provides, which stops playback first
    /// (profiles/switching-profile). Nothing with one profile.
    struct ProfileSwitchButton: View {
        @Query private var records: [ProfileRecord]
        @Environment(\.currentProfile) private var current
        @Environment(\.switchProfile) private var switchProfile

        var body: some View {
            let profiles = ProfileStore.list(records)
            if profiles.showsPicker, let profile = profiles.profiles.first(where: { $0.id == current }) {
                let tile = ProfileTile(profile)
                Button {
                    switchProfile?()
                } label: {
                    ProfileBadge(tile: tile, size: 56)
                        .contentShape(.hoverEffect, Circle())
                        .hoverEffect(.highlight)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Profile, \(tile.name)")
                .accessibilityIdentifier("shell.profile")
            }
        }
    }
#endif
