import AntennaCore
import SwiftData
import SwiftUI

/// Profiles in Settings on every device (profiles/switching-profile). With
/// two or more profiles it shows the current one and goes back to "Who's
/// watching?"; with one it reads "Add a profile" and opens Manage profiles
/// (profiles/adding-a-profile).
struct ProfileSettingsRow: View {
    @Query private var records: [ProfileRecord]
    @Environment(\.currentProfile) private var current
    @Environment(\.switchProfile) private var switchProfile
    @State private var managing = false

    var body: some View {
        let profiles = ProfileStore.list(records)
        let shown = profiles.showsPicker ? profiles.profiles.first { $0.id == current } ?? profiles.profiles[0] : nil
        Button {
            if shown != nil, let switchProfile {
                switchProfile()
            } else {
                managing = true
            }
        } label: {
            LabeledContent("Profiles") {
                if let shown {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: shown.color))
                            .frame(width: 12, height: 12)
                        Text(shown.name)
                    }
                } else {
                    Text("Add a profile")
                }
            }
            .foregroundStyle(Palette.text)
        }
        .accessibilityLabel("Profiles")
        .accessibilityValue(shown?.name ?? "Add a profile")
        .accessibilityIdentifier("settings.profile")
        #if os(tvOS)
            .fullScreenCover(isPresented: $managing) { manage }
        #else
            .sheet(isPresented: $managing) { manage }
        #endif
    }

    private var manage: some View {
        ProfileManageFlow(profiles: ProfileStore.list(records)) { managing = false }
    }
}
