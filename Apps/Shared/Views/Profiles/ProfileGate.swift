import AntennaCore
import SwiftData
import SwiftUI

/// Asks "Who's watching?" at launch when there are two or more profiles,
/// then shows `content` for the chosen profile through `currentProfile`
/// (profiles/who-s-watching-at-launch). With one profile it opens
/// straight on it. Profiles that arrive while the app runs wait for the
/// next launch.
struct ProfileGate<Content: View>: View {
    @Query private var records: [ProfileRecord]
    @State private var chosen: UUID?
    private let store: CurrentProfileStore
    @ViewBuilder var content: Content

    init(store: CurrentProfileStore = CurrentProfileStore(), @ViewBuilder content: () -> Content) {
        self.store = store
        self.content = content()
    }

    private var profiles: ProfileList { ProfileStore.list(records) }

    var body: some View {
        if let chosen {
            content
                .environment(\.currentProfile, chosen)
                .id(chosen)
        } else if profiles.showsPicker {
            let focused = profiles.focusedOnPicker(stored: store.read())
            ProfilePicker(tiles: profiles.profiles.map(ProfileTile.init), focus: $focusTarget, choose: choose) {
                EmptyView()
            }
            .defaultFocus($focusTarget, focused.id)
            #if os(tvOS)
                // Nothing is behind the picker, so Menu stays here.
                .onExitCommand {}
            #endif
        } else {
            Color.clear
                .task { chosen = profiles.current(stored: store.read())?.id ?? Profile.mainID }
        }
    }

    @FocusState private var focusTarget: UUID?

    private func choose(_ id: UUID) {
        store.write(id)
        chosen = id
    }
}
