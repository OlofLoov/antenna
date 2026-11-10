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
                .environment(\.switchProfile, { self.chosen = nil })
                .id(chosen)
        } else if profiles.showsPicker {
            ProfileFlow(profiles: profiles, focused: profiles.focusedOnPicker(stored: store.read()).id, choose: choose)
        } else {
            Color.clear
                .task { chosen = profiles.current(stored: store.read())?.id ?? Profile.mainID }
        }
    }

    private func choose(_ id: UUID) {
        store.write(id)
        chosen = id
    }
}

extension EnvironmentValues {
    /// Goes back to "Who's watching?" (profiles/switching-profile); nil outside a gate.
    @Entry var switchProfile: (@MainActor () -> Void)?
}
