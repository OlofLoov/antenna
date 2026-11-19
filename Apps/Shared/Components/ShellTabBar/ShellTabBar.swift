import AntennaCore
import SwiftUI

/// The Apple TV shell's top bar (tvos-shell capability; `TV-Shell-Menu`,
/// `TV-Shell-FocusedTab`, `TV-Movies`, `TV-Shell-Guide-Menu`). Compiles on
/// every platform so the snapshot job renders its previews.
enum ShellTabBar {
    /// The band the bar takes along the top of the screen.
    static let height = 104.0

    /// How a pill looks when it does not have focus. A focused pill always
    /// carries the Focus token.
    enum Look: Equatable, Sendable {
        case plain
        /// The open tab while focus is in the tab's content: white fill (design-system/focus-is-the-lifted-white-card deviation in tvos-shell).
        case currentInContent
        /// The open tab while focus is elsewhere in the bar: 0.12 surface, weight 600.
        case currentInBar
    }

    /// Mark, pill group, settings button and the trailing clock or slot,
    /// 104 tall with 64 at each side. The pill group sits on the screen's
    /// horizontal center, as the system tab bar does; the profile and
    /// Settings buttons hang 14 to its right without moving it.
    struct Bar<Pills: View, Settings: View, Trailing: View>: View {
        @ViewBuilder var pills: Pills
        @ViewBuilder var settings: Settings
        @ViewBuilder var trailing: Trailing

        var body: some View {
            ZStack {
                HStack(spacing: 0) {
                    Mark()
                        .frame(width: 260, alignment: .leading)
                    Spacer(minLength: 0)
                    trailing
                }
                HStack(spacing: 6) { pills }
                    .padding(6)
                    .glassEffect(.regular, in: Capsule())
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Tabs")
                    .accessibilityIdentifier("shell.tabs")
                    .overlay(alignment: .trailing) {
                        HStack(spacing: 14) { settings }
                            .fixedSize()
                            .alignmentGuide(.trailing) { $0[.leading] - 14 }
                    }
            }
            .padding(.horizontal, 64)
            .frame(height: ShellTabBar.height)
            .frame(maxWidth: .infinity)
        }
    }

    /// The Antenna glyph and name. Not focusable.
    struct Mark: View {
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.boardStyle(30))
                    .accessibilityHidden(true)
                Text("Antenna")
                    .font(.boardStyle(28, weight: .bold))
                    .accessibilityIdentifier("shell.mark")
            }
            .foregroundStyle(Palette.text)
        }
    }

    /// One tab. Select opens it; moving focus onto it opens nothing.
    struct Pill: View {
        let title: LocalizedStringResource
        let look: Look
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(.boardStyle(26, weight: look != .plain ? .semibold : .regular))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 26)
            }
            .buttonStyle(FocusCardStyle(.capsule, resting: resting, restingText: restingText))
            .accessibilityAddTraits(look == .plain ? [] : .isSelected)
        }

        /// The open tab rests white while focus is in its content, and on
        /// the surface while focus is elsewhere in the bar.
        private var resting: Color {
            switch look {
            case .plain: .clear
            case .currentInContent: Palette.focus
            case .currentInBar: Palette.surface(0.12)
            }
        }

        private var restingText: Color { look == .currentInContent ? Palette.ground : Palette.text }
    }

    /// The current profile's color and initial, 56 by 56, between the tabs
    /// and the gear when there are two or more profiles (`TV-Shell-Menu-Profile`).
    struct ProfileButton: View {
        let tile: ProfileTile
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                Text(tile.initial)
                    .font(.boardStyle(26, weight: .bold))
                    .foregroundStyle(Palette.ground)
                    .frame(width: 56, height: 56)
                    .background(Color(hex: tile.color), in: Circle())
                    .profileCircleHighlight()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Profile, \(tile.name)")
        }
    }

    /// The gear that opens Settings, a bordered circle. Not a tab.
    struct SettingsButton: View {
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                Image(systemName: "gearshape")
                    .font(.boardStyle(30))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Settings")
        }
    }

    /// Hours and minutes in the user's locale, 260 wide, right aligned. Not focusable.
    struct Clock: View {
        let date: Date
        /// `overlay.clock` when the channel overlay shows it.
        var identifier = "shell.clock"

        var body: some View {
            Text(date, format: .dateTime.hour().minute())
                .font(.boardStyle(34, weight: .semibold))
                .letterSpacing(0.5)
                .monospacedDigit()
                .foregroundStyle(Palette.text)
                .frame(width: 260, alignment: .trailing)
                .accessibilityIdentifier(identifier)
        }
    }

    /// Keeps the clock's 260 pt when another screen shows the clock (the Guide).
    struct ClockSlot: View {
        var body: some View {
            Color.clear
                .frame(width: 260, height: 1)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// The highlight hover effect on the profile circle on Apple TV; nothing elsewhere.
    @ViewBuilder fileprivate func profileCircleHighlight() -> some View {
        #if os(tvOS)
            contentShape(.hoverEffect, Circle()).hoverEffect(.highlight)
        #else
            self
        #endif
    }
}

#Preview("Tab bar, Live focused over the picture", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ShellScrim()
        ShellTabBar.Bar {
            ShellTabBar.Pill(title: "Live", look: .currentInBar) {}
            ShellTabBar.Pill(title: "Guide", look: .plain) {}
            ShellTabBar.Pill(title: "Movies", look: .plain) {}
            ShellTabBar.Pill(title: "Series", look: .plain) {}
            ShellTabBar.Pill(title: "Search", look: .plain) {}
        } settings: {
            ShellTabBar.SettingsButton {}
        } trailing: {
            ShellTabBar.Clock(date: Date(timeIntervalSince1970: 77_640))
        }
    }
}

#Preview("Tab bar, Movies open with focus in its content", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Palette.ground
        ShellTabBar.Bar {
            ShellTabBar.Pill(title: "Live", look: .plain) {}
            ShellTabBar.Pill(title: "Guide", look: .plain) {}
            ShellTabBar.Pill(title: "Movies", look: .currentInContent) {}
            ShellTabBar.Pill(title: "Series", look: .plain) {}
            ShellTabBar.Pill(title: "Search", look: .plain) {}
        } settings: {
            ShellTabBar.SettingsButton {}
        } trailing: {
            ShellTabBar.Clock(date: Date(timeIntervalSince1970: 77_640))
        }
    }
}

#Preview("Tab bar with the profile button, tabs on the center line", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Palette.ground
        Rectangle().fill(Palette.surface(0.12)).frame(width: 2).accessibilityHidden(true)
        ShellTabBar.Bar {
            ShellTabBar.Pill(title: "Live", look: .currentInBar) {}
            ShellTabBar.Pill(title: "Guide", look: .plain) {}
            ShellTabBar.Pill(title: "Movies", look: .plain) {}
            ShellTabBar.Pill(title: "Series", look: .plain) {}
            ShellTabBar.Pill(title: "Search", look: .plain) {}
        } settings: {
            ShellTabBar.ProfileButton(tile: ProfileTile(id: Profile.mainID, name: "Kids", initial: "K", color: Profile.colors[5])) {}
            ShellTabBar.SettingsButton {}
        } trailing: {
            ShellTabBar.Clock(date: Date(timeIntervalSince1970: 77_640))
        }
    }
}

#Preview("Tab bar over the guide, clock slot kept", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Palette.ground
        ShellScrim()
        ShellTabBar.Bar {
            ShellTabBar.Pill(title: "Live", look: .plain) {}
            ShellTabBar.Pill(title: "Guide", look: .currentInBar) {}
            ShellTabBar.Pill(title: "Search", look: .plain) {}
        } settings: {
            ShellTabBar.SettingsButton {}
        } trailing: {
            ShellTabBar.ClockSlot()
        }
    }
}
