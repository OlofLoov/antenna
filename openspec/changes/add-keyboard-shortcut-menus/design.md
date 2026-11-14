# Design

## Context

`add-control-hints` left the keyboard out: "They are zero-size buttons with `keyboardShortcut`, so neither the Mac menu bar nor the iPad Command-hold shortcut list shows them. The platform's way to show shortcuts is those two lists, and moving the keys into `.commands` menus would show them on both without a legend over the picture. A legend through this mechanism would also need a focused view on Mac, where clicking the video leaves none."

The app has one `WindowGroup` in `Apps/Shared/AntennaApp.swift`, shared by iPhone, iPad, native Mac and Apple TV, with no `.commands`. iPad and Mac show a sidebar (`LiveSection`: Live, Guide, Movies, Series, Search, Sources & Settings); iPhone and a narrow iPad window show tabs.

### Inventory

Every `keyboardShortcut` and `onKeyPress` in `Apps/Shared` on 2026-11-14, with what this change does to it. "Menu" moves it into a menu item; "Stays" keeps it in the screen.

| Screen | Key | Action | Where it is | This change |
|--------|-----|--------|-------------|-------------|
| Live list | Command-F | Find a channel | `LiveRegularView.swift:427` | Menu: Edit, Find Channel |
| Live list | Down, Up | Move the focus ring | `LiveRegularView.swift:431-433` | Stays |
| Live list | Return | Play the ringed channel | `LiveRegularView.swift:435` | Stays |
| Live list | Space | Pause or play | `LiveRegularView.swift:437` | Menu: Playback, Pause / Play |
| Live list | Command-Shift-M | Add the ringed channel to multi-view (iOS, macOS) | `MultiViewGridScreen.swift:241` (`LiveMultiViewKey`) | Menu: Playback, Add to Multi-view |
| Live full screen | Escape | Leave full screen | `LiveRegularView.swift:106` (Mac), `LiveEscapeKey` (iPad) | Stays |
| Live picture (Mac) | M | Mute | `LivePicture.swift:170` | Menu: Playback, Mute |
| Live picture (Mac) | Command-Up, Command-Down | Volume | `LivePicture.swift:173-175` | Menu: Playback, Volume Up / Down |
| Live timeshift | Left, Right | Back 15 s, forward 30 s | `LiveTimeshift.swift:60-62` | Menu: Playback, Back 15 / Forward 30 Seconds |
| Guide | Command-F | Filter channels | `GuideRegularScreen.swift:110` | Menu: Edit, Filter Channels |
| Guide | Command-Plus, Command-Equals | Zoom in | `GuideRegularScreen.swift:112-114` | Menu: View, Zoom In (Equals as a second key equivalent, see below) |
| Guide | Command-Minus | Zoom out | `GuideRegularScreen.swift:116` | Menu: View, Zoom Out |
| Guide | Arrows | Move the cursor | `GuideRegularScreen.swift:119-125` | Stays |
| Guide | Return | Open details | `GuideRegularScreen.swift:127` | Stays |
| Search | Command-F | Put the cursor in the field | `SearchRegularScreen.swift:95` | Menu: Edit, Search |
| Search | Arrows, Return, Escape | Move, open, clear | `SearchRegularScreen.swift:45-113` | Stays |
| Title page | Left, Right | Previous or next season | `TitleScreen.swift:136-138` | Stays |
| Title page | Return | Play | `TitleScreen.swift:140` | Stays |
| Title page | Escape | Back | `TitlePageLayouts.swift:141, 162`, `LiveEscapeKey` (iPad) | Stays |
| Movie player | Left, Right | Skip 10 s | `ShelfPlayerView.swift:309-311` | Menu: Playback, Back / Forward 10 Seconds |
| Movie player | Space | Play or pause | `ShelfPlayerView.swift:313` | Menu: Playback, Pause / Play |
| Movie player | Escape | Close | `ShelfPlayerView.swift:317`; error Back at `:98` | Stays |
| Multi-view | Command-1 to 4 | Select a tile | `MultiViewGridScreen.swift:164` | Menu: Playback, Select Tile n, moved to Option-Command-1 to 4 |
| Multi-view | Command-Delete | Remove the selected tile | `MultiViewGridScreen.swift:167` | Menu: Playback, Remove Tile |
| Multi-view | Escape | Back to the grid | `MultiViewGridScreen.swift:170` | Stays |
| Number entry (Apple TV) | Digits, Return, Backspace, Escape | Tune by number | `NumberEntryInput.swift:37` | Stays, tvOS only |

## Decisions

### Which keys go into menus

Commands go into menus; moving through a list does not. A command is something the viewer asks for by name: pause, skip, mute, zoom, find, go to the Guide. Moving through a list is the arrows, Return to open what the cursor is on, and Escape to go back. That belongs to the list on screen, and a menu full of "Up Arrow: previous channel" items hides the useful ones.

Options considered:
- Every key in a menu (rejected). Arrows and Return in menus take them from text fields and lists everywhere, and the menus would list the same arrow three times with different names.
- Only Command shortcuts in menus (rejected). Space, M and the player's Left and Right are the keys a viewer most wants to discover, and leaving them out keeps half the inventory hidden.
- Commands in menus, list movement in the screens (chosen).

Left and Right are both: skip in the players, season on a series page. They go in Playback as skip items, and the series page keeps its own Left and Right. Both are never available together, because the movie player covers the page while it plays, and the skip items are dimmed when nothing plays.

### Menus

```
Edit       Find Channel / Filter Channels / Search      ⌘F
View       Zoom In                                     ⌘+   (⌘= too)
           Zoom Out                                    ⌘−
Playback   Pause / Play                                Space
           Back 15 Seconds / Back 10 Seconds           ←
           Forward 30 Seconds / Forward 10 Seconds     →
           ─
           Mute (Mac)                                  M
           Volume Up (Mac)                             ⌘↑
           Volume Down (Mac)                           ⌘↓
           ─
           Add to Multi-view                           ⇧⌘M
           ─
           Select Tile 1 … 4                           ⌥⌘1 … ⌥⌘4
           Remove Tile                                 ⌘⌫
Go         Live                                        ⌘1
           Guide                                       ⌘2
           Movies                                      ⌘3
           Series                                      ⌘4
           Search                                      ⌘5
           ─
           Sources & Settings                          ⌘,
```

Find replaces the system's text-editing Find group (`CommandGroup(replacing: .textEditing)`), so Edit has one Command-F item. Zoom goes before the toolbar group in View (`CommandGroup(before: .toolbar)`). Playback and Go are `CommandMenu`s, which SwiftUI puts between View and Window in that order. The Mac's File menu keeps New Window from `WindowGroup`.

Command-Equals for Zoom In: a menu item has one key equivalent. Zoom In shows Command-Plus. A second, hidden Zoom In item would show in the iPad list, so Command-Equals stays a hidden button in `GuideRegularScreen`, the one command key that does. On a US layout Plus needs Shift, which is why Command-Equals exists.

Titles follow the screen in front: Pause or Play by state, Back 15 or Back 10 by player, Find Channel, Filter Channels or Search by screen. With nothing in front that can use an item, the item keeps its last generic title (Play, Back, Forward, Find) and is dimmed. Items are never hidden, so the menus do not change shape; the iPad list shows dimmed items too.

### The Go menu

New keys: Command-1 to 5 for the sidebar's sections and Command-Comma for Sources & Settings. Command-1 onward switches a window's views in Finder and Xcode's navigators, and Command-Comma is the Settings key on Mac and iPad. With Go in place, multi-view's tile keys move to Option-Command-1 to 4. The multi-view spec names Command-Delete and Command-Shift-M but not Command-1 to 4, so no requirement changes.

Options considered for the tile keys:
- Keep Command-1 to 4 in multi-view and give Go other keys (rejected). Go's numbers would differ from every other Mac app with sections.
- Plain 1 to 4 in multi-view (rejected). Multi-view has no text field, but a bare digit in a menu reads as a typo, and Apple TV's number entry already gives digits a different meaning.
- Option-Command-1 to 4 (chosen).

In a narrow iPad window, the tabs replace the sidebar and Series sits inside Movies. Command-4 then opens Movies with Series picked.

### How the menus reach the screens

`AntennaCommands`, a `Commands` value in `Apps/Shared/Commands/`, is added with `.commands { AntennaCommands() }` on the `WindowGroup` for iOS and macOS. It reads one focused value per menu section: `\.findCommand`, `\.zoomCommands`, `\.playbackCommands`, `\.tileCommands` and `\.sectionCommands`, each a small struct of titles, enabled flags and closures, declared with `@Entry` on `FocusedValues`.

Screens publish them with `.focusedSceneValue(_:_:)`:
- `LiveRegularView`: find, playback (pause, timeshift skip, mute and volume on Mac, add to multi-view).
- `GuideRegularScreen`: find, zoom.
- `SearchRegularScreen`: find.
- `ShelfPlayerView`: playback (pause, 10-second skip). It sits over the shell, and the value nearest the focused part of the scene wins, so the player's playback replaces Live's while it shows.
- `MultiViewGridScreen`: tiles.
- The iPad and Mac sidebar root: sections.

Options considered:
- `focusedValue` (rejected). It needs a focused view, and on Mac clicking the video leaves none, so Space and the volume keys would stop working after a click, which the hidden buttons do not do today.
- One `@Observable` command router in the environment, read by the commands (rejected). Commands do not get the window's environment, and with two windows a shared router acts on the wrong one.
- `focusedSceneValue` (chosen). It belongs to the window, holds without a focused view, and with two windows the menus act on the one in front.

The hidden buttons for moved commands are deleted, so each key is bound in one place.

### Typing

A command whose key has no Command, Option or Control modifier is dimmed while a text field has the keyboard. The screens already track this (`live.typing`, `filterFocused`, Search's `focused`) and disable their hidden buttons with it; the published values carry it as `isEnabled`. A dimmed menu item does not take its key, so the field gets it.

Three Command keys are also text-field keys: Command-Up and Command-Down (start and end of the field) and Command-Delete (delete to the start). Volume Up, Volume Down and Remove Tile are dimmed while typing too. Find, Zoom, Add to Multi-view and Go stay on.

### Clashes

`KeyCommand` in AntennaCore lists every command with its menu, its titles, its key (a small `Key` enum: a character, an arrow, Space, Delete) and its modifiers, and which screens can enable it. Apps map `Key` to SwiftUI's `KeyEquivalent`. Tests check that:
- no two commands that one screen can enable at once share a key and modifiers;
- none uses a reserved combination: Command-Q, W, H, M, N, Tab, Space and Grave, Command-Comma except for Settings, Control-Command-F, Control-Command-Q, Command-Shift-3, 4 and 5, Command-Option-Escape, and the Edit menu's Command-X, C, V, Z, Shift-Z and A;
- every command in the inventory above marked "Menu" is in the catalogue.

Command-H and Command-M are Hide and Minimize on Mac, which is why mute is plain M, as `player-controls-and-playback-errors` already has it, and not Command-M.

Space with keyboard navigation: on Mac with Keyboard Navigation on, and on iPad with Full Keyboard Access, Space presses the focused button. A menu item's key equivalent is handled before the focused control, so Space pauses instead, as the hidden button does today. The change keeps that behavior and lists it under open questions.

### iPad

SwiftUI commands populate the iPad menu bar in iPadOS 26, which shows with the pointer at the top edge, a swipe down from the top, or while Command is held. The same menus show there. Mute and the volume items are Mac-only (`#if os(macOS)`), as the Mac-only keys are today; the iPad uses its hardware volume.

### iPhone and Apple TV

No `.commands` on tvOS; Apple TV keeps the remote hints and the number entry. iPhone runs the same `WindowGroup`, but iOS on iPhone shows no menu bar. The compact screens publish no command values, so with a keyboard paired to an iPhone the commands stay dimmed, as the compact screens have none of these keys today.

## Boards

New, under `openspec/specs/design-system/boards/`:
- `Mac-Menus-Playback`: Live in a Mac window with the Playback menu open.
- `iPad-Menus-Go`: Live on iPad with the iPadOS menu bar showing and the Go menu open.

Follows: `iPad-Player` (the screen under the menus), `iPad-Guide` (View's zoom items act on it). The bar and menus are drawn by the system; the boards fix which items Antenna adds, their order, titles and keys. Not drawn: the Edit and View menus (one and two items, listed above) and the Playback menu in the movie player and in multi-view (same items, titles from the table).

Design-system requirements that apply: "Accessibility identifiers follow the board" (menu items get no identifiers; UI tests press the keys), "Deviations from a design rule are named" (none; system menus are outside the app's type and color rules).

## Identifiers

None new on screen. Tests drive the keys with `XCUIElement.typeKey(_:modifierFlags:)` and check the screens' existing identifiers.

## Risks

- `focusedSceneValue` from a view inside a `fullScreenCover` or overlay may not reach the commands on iPad. The movie player is an overlay in the same scene, so this should hold; the iPad UI test covers Space in the player.
- iPadOS 26 menu bar behavior is new and has not been checked on a device for this app.

## Open questions

1. **Go menu keys.** Recommend Command-1 to 5 and moving the tile keys to Option-Command-1 to 4. The alternative is no Go menu, which keeps this change to moving existing keys only.
2. **Space with Full Keyboard Access or Keyboard Navigation on.** Recommend keeping today's behavior (Space pauses) and revisiting if a keyboard user reports it. The alternative is dimming Pause while a button has keyboard focus, which makes Space unreliable for everyone else.
3. **Season keys on the title page.** Recommend leaving Left and Right as list movement. They could be listed under Go as Previous Season and Next Season if the owner prefers them visible.
4. **iPadOS 26 Command-hold.** Check on a device that holding Command shows the menu bar with these menus, and record what it shows in this design before the code PR.
