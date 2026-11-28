import AntennaCore
import SwiftUI

/// The Play on control on iPhone, iPad and Mac (`iPhone-Title-PlayOn`,
/// play-on-apple-tv/play-on-from-what-can-be-played). With one Apple TV
/// it is a button that sends at once; with more, or with local network
/// access refused, a system menu with one row per TV saying whether it
/// starts now, and a last row pointing at Settings when access is
/// refused (design-system/controls-use-system-styles). Takes values and
/// closures only.
enum PlayOnControl {
    typealias Actions = PlayOnActions

    /// A button that sends to the one TV, or opens the menu of TVs: the
    /// title page's under Play beside My list (`title.playOn`,
    /// `title.playOn.menu`, `title.playOn.menu.device`) and the Guide
    /// details' "Watch on Living Room" (`guide.detail.watchOn`).
    struct Button<Label: View>: View {
        let choice: PlayOnChoice
        let actions: Actions
        /// The identifier of the one-TV button; the menu adds `.menu`, its rows `.menu.device`.
        var identifier = "title.playOn"
        /// The one-TV button's words for a TV name.
        var single: (String, Locale) -> String = { PlayOnText.playOn($0, locale: $1) }
        /// The words on the button: "Play on Living Room" with one TV, "Play on" with more.
        @ViewBuilder var label: (String) -> Label
        @Environment(\.locale) private var locale

        var body: some View {
            if let only = choice.single {
                SwiftUI.Button {
                    actions.opened()
                    actions.pick(only.id)
                } label: {
                    label(single(only.name, locale))
                }
                .accessibilityIdentifier(identifier)
            } else {
                Menu {
                    Rows(choice: choice, actions: actions, identifier: "\(identifier).menu.device")
                        .onAppear(perform: actions.opened)
                } label: {
                    label(PlayOnText.playOnMenu(locale))
                }
                .accessibilityIdentifier("\(identifier).menu")
            }
        }
    }

    /// The items in a channel's or an episode's touch-and-hold menu:
    /// "Play on Living Room", or a "Play on" submenu with more TVs
    /// (`channel.menu.playOn`, `episode.menu.playOn`).
    struct MenuItems: View {
        let choice: PlayOnChoice
        let actions: Actions
        let identifier: String
        /// The item's words for one TV: "Play on Living Room", or "Watch on Living Room" in the Guide.
        var title: (String) -> String = { PlayOnText.playOn($0) }
        @Environment(\.locale) private var locale

        var body: some View {
            if let only = choice.single {
                SwiftUI.Button(title(only.name), systemImage: "tv") {
                    actions.opened()
                    actions.pick(only.id)
                }
                .accessibilityIdentifier(identifier)
            } else {
                Menu {
                    Rows(choice: choice, actions: actions, identifier: "\(identifier).device")
                        .onAppear(perform: actions.opened)
                } label: {
                    SwiftUI.Label(PlayOnText.playOnMenu(locale), systemImage: "tv")
                }
                .accessibilityIdentifier(identifier)
            }
        }
    }

    /// One row per TV with its second line, then the Settings row while
    /// access is refused.
    struct Rows: View {
        let choice: PlayOnChoice
        let actions: Actions
        let identifier: String
        @Environment(\.locale) private var locale

        var body: some View {
            ForEach(choice.rows) { row in
                let line = row.ready ? PlayOnText.readyNow(locale) : PlayOnText.playsWhenOpen(locale)
                SwiftUI.Button {
                    actions.pick(row.id)
                } label: {
                    SwiftUI.Label {
                        Text(verbatim: row.name)
                        Text(line)
                    } icon: {
                        Image(systemName: "tv")
                    }
                }
                // VoiceOver reads the second line too, which a menu leaves out.
                .accessibilityLabel(Text(verbatim: "\(row.name), \(line)"))
                .accessibilityIdentifier(identifier)
            }
            if choice.accessRefused {
                Divider()
                SwiftUI.Button(PlayOnText.allowLocalNetwork(locale), systemImage: "gear", action: actions.openSettings)
                    .accessibilityIdentifier("playOn.menu.settings")
            }
        }
    }
}

extension PlayOnChoice {
    /// The one TV a plain button sends to: only when there is one and
    /// the menu has no Settings row to show.
    var single: Row? {
        rows.count == 1 && !accessRefused ? rows.first : nil
    }
}

/// The short line at the top after a send (`playOn.sent`,
/// `iPhone-PlayOn-Messages`), with what the screen passes at its trailing
/// end, as Cancel while the request can be taken back.
struct PlayOnToast<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("playOn.sent")
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thickMaterial, in: Capsule())
        .padding(.horizontal, 16)
    }
}

extension PlayOnToast where Trailing == EmptyView {
    init(text: String) {
        self.init(text: text) { EmptyView() }
    }
}

#Preview("Play on, two TVs") {
    let choice = PlayOnChoice(
        rows: [.init(id: UUID(), name: "Living Room", ready: true), .init(id: UUID(), name: "Bedroom", ready: false)],
        accessRefused: false)
    PlayOnControl.Button(choice: choice, actions: .init(opened: {}, pick: { _ in }, openSettings: {})) { Text($0) }
        .secondaryActionStyle()
        .padding()
        .background(Palette.ground)
}

#Preview("Play on, one TV") {
    let choice = PlayOnChoice(rows: [.init(id: UUID(), name: "Living Room", ready: true)], accessRefused: false)
    PlayOnControl.Button(choice: choice, actions: .init(opened: {}, pick: { _ in }, openSettings: {})) { Text($0) }
        .secondaryActionStyle()
        .padding()
        .background(Palette.ground)
}

#Preview("Play on, sent") {
    PlayOnToast(text: "Playing on Living Room")
        .padding()
        .background(Palette.ground)
}

#Preview("Play on, sent with Cancel") {
    PlayOnToast(text: "Sent. Living Room plays it if Antuna opens there within a minute.") {
        Button("Cancel") {}
            .font(.subheadline.weight(.semibold))
    }
    .padding()
    .background(Palette.ground)
}
