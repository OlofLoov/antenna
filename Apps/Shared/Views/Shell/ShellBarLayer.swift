#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The Apple TV tab bar over the picture (tvos-shell/the-tabs-in-order): the
    /// tabs, the profile button with two or more profiles, Settings and the clock.
    struct ShellBarLayer: View {
        let model: ShellModel
        let focus: FocusState<ShellFocus?>.Binding
        /// True while focus is somewhere in the bar.
        let barHasFocus: Bool
        @Environment(\.currentProfile) private var current
        @Environment(\.switchProfile) private var switchProfile
        @Query private var records: [ProfileRecord]

        var body: some View {
            ShellTabBar.Bar {
                ForEach(model.tabs, id: \.self) { tab in
                    ShellTabBar.Pill(title: tab.title, look: look(for: tab)) {
                        Task { focus.wrappedValue = await model.select(tab) }
                    }
                    .focused(focus, equals: .tab(tab))
                    .accessibilityIdentifier("shell.tab.\(tab.identifier)")
                }
            } settings: {
                let profiles = ProfileStore.list(records)
                if let profile = profiles.profiles.first(where: { $0.id == current }), profiles.showsPicker {
                    ShellTabBar.ProfileButton(tile: ProfileTile(profile)) {
                        // Playback stops before "Who's watching?" (profiles/switching-profile).
                        Task {
                            await model.engine.stop()
                            switchProfile?()
                        }
                    }
                    .focused(focus, equals: .profile)
                    .accessibilityIdentifier("shell.profile")
                }
                ShellTabBar.SettingsButton { model.settingsOpen = true }
                    .focused(focus, equals: .settings)
                    .accessibilityIdentifier("shell.settings")
            } trailing: {
                if model.tab == .guide {
                    ShellTabBar.ClockSlot()
                } else {
                    TimelineView(.everyMinute) { context in
                        ShellTabBar.Clock(date: context.date)
                    }
                }
            }
            .focusSection()
        }

        private func look(for tab: ShellTab) -> ShellTabBar.Look {
            guard tab == model.tab else { return .plain }
            return barHasFocus ? .currentInBar : .currentInContent
        }
    }
#endif
