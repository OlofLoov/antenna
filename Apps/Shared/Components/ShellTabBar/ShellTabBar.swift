import SwiftUI

/// The Apple TV shell's top bar (spec 0015; `TV-Shell-Menu`,
/// `TV-Shell-FocusedTab`, `TV-Movies`, `TV-Shell-Guide-Menu`). Compiles on
/// every platform so the snapshot job renders its previews.
enum ShellTabBar {
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
    /// 104 tall with 64 at each side.
    struct Bar<Pills: View, Settings: View, Trailing: View>: View {
        @ViewBuilder var pills: Pills
        @ViewBuilder var settings: Settings
        @ViewBuilder var trailing: Trailing

        var body: some View {
            HStack(spacing: 0) {
                Mark()
                    .frame(width: 260, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    HStack(spacing: 6) { pills }
                        .padding(6)
                        .background(Palette.tabBar, in: Capsule())
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Tabs")
                    settings
                }
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, 64)
            .frame(height: 104)
            .frame(maxWidth: .infinity)
        }
    }

    /// The Antenna glyph and name. Not focusable.
    struct Mark: View {
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .accessibilityHidden(true)
                Text("Antenna")
                    .font(.system(size: 28, weight: .bold))
                    .accessibilityIdentifier("shell.mark")
            }
            .foregroundStyle(Palette.text)
        }
    }

    /// One tab. Select opens it; moving focus onto it opens nothing.
    struct Pill: View {
        let title: String
        let look: Look
        let select: () -> Void

        var body: some View {
            Button(title, action: select)
                .buttonStyle(PillStyle(look: look))
                .accessibilityAddTraits(look == .plain ? [] : .isSelected)
        }
    }

    struct PillStyle: ButtonStyle {
        let look: Look

        func makeBody(configuration: Configuration) -> some View {
            PillLabel(label: configuration.label, look: look)
        }
    }

    private struct PillLabel<Label: View>: View {
        let label: Label
        let look: Look
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 26, weight: isFocused || look != .plain ? .semibold : .regular))
                .padding(.vertical, 10)
                .padding(.horizontal, 26)
                .foregroundStyle(isFocused || look == .currentInContent ? Palette.ground : Palette.text)
                .background(fill, in: Capsule())
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }

        private var fill: Color {
            if isFocused { return Palette.focus }
            switch look {
            case .plain: return .clear
            case .currentInContent: return Palette.focus
            case .currentInBar: return Palette.surface(0.12)
            }
        }
    }

    /// The gear that opens Settings: 56 by 56 with a 30 pt glyph. Not a tab.
    struct SettingsButton: View {
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                Image(systemName: "gearshape")
                    .font(.system(size: 30))
            }
            .buttonStyle(GearStyle())
            .accessibilityLabel("Settings")
        }
    }

    private struct GearStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            GearLabel(label: configuration.label)
        }
    }

    private struct GearLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .frame(width: 56, height: 56)
                .background(isFocused ? Palette.focus : .clear, in: Circle())
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }

    /// Hours and minutes in the user's locale, 260 wide, right aligned. Not focusable.
    struct Clock: View {
        let date: Date

        var body: some View {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: 34, weight: .semibold))
                .tracking(0.5)
                .monospacedDigit()
                .foregroundStyle(Palette.text)
                .frame(width: 260, alignment: .trailing)
                .accessibilityIdentifier("shell.clock")
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
