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
                    Badge(tile: tile)
                }
                // The circle shows focus itself; a system style or hover effect
                // lifts it on a platter that cuts it (profiles/who-s-watching-at-launch).
                .buttonStyle(FocusHolderStyle())
                .accessibilityLabel("Profile, \(tile.name)")
                .accessibilityIdentifier("shell.profile")
            }
        }

        /// The 56 pt circle, lifted with a shadow while focused.
        private struct Badge: View {
            let tile: ProfileTile
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                ProfileBadge(tile: tile, size: 56).circleLiftOnTelevision(isFocused)
            }
        }
    }
#endif
