#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// One menu item as the screen in front publishes it: what it reads,
    /// whether it can run now, and what it does.
    struct MenuCommand {
        var title: String
        var isEnabled = true
        var perform: @MainActor () -> Void
    }

    /// View's zoom items, from the Guide.
    struct ZoomCommands {
        var zoomIn: MenuCommand
        var zoomOut: MenuCommand
    }

    /// Playback's first items, from Live or the movie player. Mute and the
    /// volume items are nil outside Live and on iPad.
    struct PlaybackCommands {
        var playPause: MenuCommand
        var skipBack: MenuCommand
        var skipForward: MenuCommand
        var mute: MenuCommand?
        var volumeUp: MenuCommand?
        var volumeDown: MenuCommand?
    }

    /// Playback's tile items, from multi-view: one entry per tile, up to four.
    struct TileCommands {
        var select: [MenuCommand]
        var remove: MenuCommand
    }

    /// The Go menu, from the iPad and Mac sidebar.
    struct SectionCommands {
        var offered: [LiveSection]
        var select: @MainActor (LiveSection) -> Void
    }

    extension FocusedValues {
        @Entry var findCommand: MenuCommand?
        @Entry var zoomCommands: ZoomCommands?
        @Entry var playbackCommands: PlaybackCommands?
        @Entry var addToMultiViewCommand: MenuCommand?
        @Entry var tileCommands: TileCommands?
        @Entry var sectionCommands: SectionCommands?
    }

    extension EnvironmentValues {
        /// True where screens publish their menu items: the iPad and Mac
        /// columns, and the movie player over them. False on iPhone, in a
        /// narrow iPad window and under a playing movie, where the screens
        /// keep their own keys.
        @Entry var publishesMenuCommands = false
    }

    extension View {
        /// Publishes `value` for the menus while `publishesMenuCommands` is
        /// on, for the window rather than the focused view, so the menus
        /// work after a click on the video leaves nothing focused.
        func menuCommand<Value>(_ key: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View {
            modifier(MenuCommandPublisher(key: key, value: value))
        }

        /// The key and modifiers the catalogue gives `command`, none on
        /// iPad for a key iPadOS's own menus hold.
        @ViewBuilder func keyboardShortcut(_ command: KeyCommand) -> some View {
            #if os(iOS)
                if command.isHeldByIPadOS {
                    self
                } else {
                    keyboardShortcut(command.combination.equivalent, modifiers: command.combination.eventModifiers)
                }
            #else
                keyboardShortcut(command.combination.equivalent, modifiers: command.combination.eventModifiers)
            #endif
        }
    }

    private struct MenuCommandPublisher<Value>: ViewModifier {
        let key: WritableKeyPath<FocusedValues, Value?>
        let value: Value?
        @Environment(\.publishesMenuCommands) private var publishes

        func body(content: Content) -> some View {
            content.focusedSceneValue(key, publishes ? value : nil)
        }
    }

    extension KeyCombination {
        var equivalent: KeyEquivalent {
            switch key {
            case .character(let character): KeyEquivalent(character)
            case .space: .space
            case .delete: .delete
            case .upArrow: .upArrow
            case .downArrow: .downArrow
            case .leftArrow: .leftArrow
            case .rightArrow: .rightArrow
            }
        }

        var eventModifiers: EventModifiers {
            var flags: EventModifiers = []
            if modifiers.contains(.command) { flags.insert(.command) }
            if modifiers.contains(.shift) { flags.insert(.shift) }
            if modifiers.contains(.option) { flags.insert(.option) }
            if modifiers.contains(.control) { flags.insert(.control) }
            return flags
        }
    }

    extension LiveSection {
        /// The Go item for this section.
        var goCommand: KeyCommand {
            switch self {
            case .live: .goLive
            case .guide: .goGuide
            case .movies: .goMovies
            case .series: .goSeries
            case .search: .goSearch
            case .settings: .goSettings
            }
        }
    }

    /// Command-F on iPad. iPadOS's Edit menu has its own Find on Command-F
    /// and refuses a second menu item with that key, so the screen keeps a
    /// hidden key command, which comes before the menu bar's. Nothing on Mac,
    /// where Find is in Edit (keyboard-commands/shortcuts-are-listed-in-the-menus).
    struct FindKey: View {
        let action: () -> Void

        var body: some View {
            #if os(iOS)
                Button(KeyCommand.find.title, action: action)
                    .keyboardShortcut(KeyCommand.find.combination.equivalent, modifiers: .command)
            #endif
        }
    }

    /// Find in Edit (Mac only, see `FindKey`), zoom in View, and the Playback and Go menus in the Mac
    /// menu bar and the iPad menu bar (keyboard-commands capability; boards
    /// `Mac-Menus-Playback`, `iPad-Menus-Go`). Each item acts on what the
    /// frontmost window publishes and is dimmed when nothing there can use it.
    struct AntennaCommands: Commands {
        @FocusedValue(\.findCommand) private var find
        @FocusedValue(\.zoomCommands) private var zoom
        @FocusedValue(\.playbackCommands) private var playback
        @FocusedValue(\.addToMultiViewCommand) private var addToMultiView
        @FocusedValue(\.tileCommands) private var tiles
        @FocusedValue(\.sectionCommands) private var sections

        var body: some Commands {
            #if os(macOS)
                CommandGroup(replacing: .textEditing) {
                    item(.find, find)
                }
            #endif
            CommandGroup(before: .toolbar) {
                item(.zoomIn, zoom?.zoomIn)
                item(.zoomOut, zoom?.zoomOut)
                Divider()
            }
            CommandMenu("Playback") {
                item(.playPause, playback?.playPause)
                item(.skipBack, playback?.skipBack)
                item(.skipForward, playback?.skipForward)
                #if os(macOS)
                    Divider()
                    item(.mute, playback?.mute)
                    item(.volumeUp, playback?.volumeUp)
                    item(.volumeDown, playback?.volumeDown)
                #endif
                Divider()
                item(.addToMultiView, addToMultiView)
                Divider()
                ForEach(1...4, id: \.self) { number in
                    item(.selectTile(number), tiles?.select.dropFirst(number - 1).first)
                }
                item(.removeTile, tiles?.remove)
            }
            CommandMenu("Go") {
                ForEach([LiveSection.live, .guide, .movies, .series, .search], id: \.self) { section in
                    go(section)
                }
                Divider()
                go(.settings)
            }
        }

        /// An item that keeps its place and key whatever is in front.
        private func item(_ command: KeyCommand, _ published: MenuCommand?) -> some View {
            Button(published?.title ?? command.title) { published?.perform() }
                .keyboardShortcut(command)
                .disabled(published?.isEnabled != true)
        }

        private func go(_ section: LiveSection) -> some View {
            let offered = sections?.offered.contains(section) == true
            return Button(section.goCommand.title) { sections?.select(section) }
                .keyboardShortcut(section.goCommand)
                .disabled(!offered)
        }
    }
#endif
