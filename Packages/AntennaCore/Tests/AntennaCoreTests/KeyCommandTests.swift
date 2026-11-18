import AntennaCore
import Testing

/// The catalogue behind the Mac and iPad menus.
@Suite struct KeyCommandTests {
    @Test("keyboard-commands/shortcuts-stay-clear-of-the-system-s no two commands that can be on together share a key")
    func noClashes() {
        for (index, first) in KeyCommand.all.enumerated() {
            for second in KeyCommand.all.dropFirst(index + 1) {
                let together =
                    !first.screens.isDisjoint(with: second.screens) || first.screens.contains(.window) || second.screens.contains(.window)
                guard together else { continue }
                #expect(first.combination != second.combination, "\(first) and \(second)")
            }
        }
    }

    @Test("keyboard-commands/shortcuts-stay-clear-of-the-system-s none uses a reserved combination")
    func noReservedCombination() {
        for command in KeyCommand.all where command != .goSettings {
            #expect(!KeyCombination.reserved.contains(command.combination), "\(command)")
        }
        #expect(KeyCommand.goSettings.combination == KeyCombination(.character(","), .command))
        #expect(KeyCommand.mute.combination == KeyCombination(.character("m")), "Command-M is Minimize")
        #expect(KeyCommand.all.filter(\.isHeldByIPadOS) == [.find, .goSettings], "iPadOS's Find and Settings")
    }

    @Test("keyboard-commands/shortcuts-are-listed-in-the-menus every moved key is in the catalogue, in its menu")
    func inventory() {
        struct Moved {
            var command: KeyCommand
            var menu: KeyCommandMenu
            var combination: KeyCombination

            init(_ command: KeyCommand, _ menu: KeyCommandMenu, _ combination: KeyCombination) {
                self.command = command
                self.menu = menu
                self.combination = combination
            }
        }
        let expected: [Moved] = [
            Moved(.find, .edit, KeyCombination(.character("f"), .command)),
            Moved(.zoomIn, .view, KeyCombination(.character("+"), .command)),
            Moved(.zoomOut, .view, KeyCombination(.character("-"), .command)),
            Moved(.playPause, .playback, KeyCombination(.space)),
            Moved(.skipBack, .playback, KeyCombination(.leftArrow)),
            Moved(.skipForward, .playback, KeyCombination(.rightArrow)),
            Moved(.mute, .playback, KeyCombination(.character("m"))),
            Moved(.volumeUp, .playback, KeyCombination(.upArrow, .command)),
            Moved(.volumeDown, .playback, KeyCombination(.downArrow, .command)),
            Moved(.addToMultiView, .playback, KeyCombination(.character("m"), [.command, .shift])),
            Moved(.removeTile, .playback, KeyCombination(.delete, .command)),
        ]
        for moved in expected {
            #expect(KeyCommand.all.contains(moved.command))
            #expect(moved.command.menu == moved.menu, "\(moved.command)")
            #expect(moved.command.combination == moved.combination, "\(moved.command)")
        }
        #expect(Set(KeyCommand.all).count == KeyCommand.all.count)
        #expect(KeyCommand.all.filter(\.isMacOnly) == [.mute, .volumeUp, .volumeDown])
    }

    @Test("keyboard-commands/menu-items-follow-the-screen-in-front tiles move to Option-Command-1 to 4")
    func tiles() {
        for number in 1...4 {
            let command = KeyCommand.selectTile(number)
            #expect(command.combination == KeyCombination(.character(Character(String(number))), [.command, .option]))
            #expect(command.title == "Select Tile \(number)")
            #expect(command.screens == [.multiView])
        }
    }

    @Test("keyboard-commands/go-to-a-section Command-1 to 5 in the sidebar's order, Command-Comma for settings")
    func goMenu() {
        let go = KeyCommand.all.filter { $0.menu == .go }
        #expect(go.map(\.title) == ["Live", "Guide", "Movies", "Series", "Search", "Sources & Settings"])
        #expect(go.map(\.combination.key) == ["1", "2", "3", "4", "5", ","].map { Key.character($0) })
        #expect(go.allSatisfy { $0.combination.modifiers == .command })
    }

    @Test("keyboard-commands/typing-is-never-taken-by-a-shortcut single keys and the text field's Command keys dim")
    func typing() {
        let dimmed = KeyCommand.all.filter(\.isDimmedWhileTyping)
        #expect(dimmed == [.playPause, .skipBack, .skipForward, .mute, .volumeUp, .volumeDown, .removeTile])
    }

    @Test("keyboard-commands/menu-items-follow-the-screen-in-front titles name what the item does")
    func titles() {
        #expect(KeyCommand.pauseTitle(paused: false) == "Pause")
        #expect(KeyCommand.pauseTitle(paused: true) == "Play")
        #expect(KeyCommand.skipTitle(forward: false, seconds: 15) == "Back 15 Seconds")
        #expect(KeyCommand.skipTitle(forward: true, seconds: 10) == "Forward 10 Seconds")
        #expect(KeyCommand.findTitle(on: .live) == "Find Channel")
        #expect(KeyCommand.findTitle(on: .guide) == "Filter Channels")
        #expect(KeyCommand.findTitle(on: .search) == "Search")
    }

    @Test("keyboard-commands/moving-through-lists-stays-off-the-menus no item takes Up, Down, Return or Escape alone")
    func listMovement() {
        let listKeys: Set<KeyCombination> = [
            KeyCombination(.upArrow), KeyCombination(.downArrow), KeyCombination(.character("\r")), KeyCombination(.character("\u{1B}")),
        ]
        #expect(KeyCommand.all.allSatisfy { !listKeys.contains($0.combination) })
        #expect(KeyCommand.skipBack.screens.isDisjoint(with: [.guide, .search]), "the guide and search keep Left and Right")
    }
}
