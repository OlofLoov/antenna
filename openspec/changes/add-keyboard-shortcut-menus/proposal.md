# Proposal

## Why

`add-control-hints` taught the Siri Remote on Apple TV and left the keyboard out, with a follow-up named in its design: "List the keyboard shortcuts in the menu bar and the iPad shortcut list". The owner asked for it from last night's report.

> As an on-the-go viewer with a Mac or an iPad keyboard, I want to find the app's shortcuts where every other app keeps them, in the menu bar, instead of guessing that Space pauses or Command-Plus zooms the guide.

Antenna has more than forty key bindings across seven screens on iPad and Mac today: Command-F, Space, the arrows, Return, Escape, M, Command-Up and Down, Command-Plus and Minus, Command-Shift-M, Command-1 to 4 and Command-Delete. Each is a `keyboardShortcut` on a zero-size, hidden button inside a screen. The Mac menu bar and the iPad menu bar list none of them, so a viewer finds them only by trying keys.

After this change the Mac menu bar and the iPad menu bar have Playback and Go menus, Find in Edit and zoom in View, each item with its key, dimmed when the screen in front cannot use it.

## What Changes

- Commands move from hidden buttons into SwiftUI `.commands`: Find (Command-F) in Edit, Zoom In and Zoom Out in View, a Playback menu (play and pause, skip, mute and volume on Mac, Add to Multi-view, the multi-view tile keys) and a Go menu.
- Screens publish what each command does through focused scene values, so the menus act on the window in front even when nothing in it has focus, as after clicking the video on Mac.
- A Go menu with Command-1 to Command-5 for Live, Guide, Movies, Series and Search, and Command-Comma for Sources & Settings. These are new.
- Multi-view tile selection moves from Command-1 to 4 to Option-Command-1 to 4, since Go takes Command-1 to 5.
- Single keys (Space, M, the arrows) are dimmed while a text field has the keyboard, so typing a space or an M in a filter field types it.
- Moving through lists and grids with the arrows, Return to open and Escape to go back keep working as today and are not listed. design.md says why.

Out of scope:
- Apple TV, which has no menu bar and keeps the remote hints from `add-control-hints`.
- iPhone, which has no menu bar.
- A keyboard legend drawn over the picture.
- Shortcuts the user can change.

## Capabilities

### New Capabilities
- `keyboard-commands`: the app's menus and shortcuts on Mac and on iPad with a keyboard, what each does on each screen, when items are dimmed, and how they stay clear of typing and of system shortcuts.

### Modified Capabilities

None. The keys the Live, Guide, Search, title page, player and multi-view specs name keep doing what those specs say. Command-1 to 4 for tiles is not in the multi-view spec, so moving it changes no requirement.

## Impact

- Platforms: Mac and iPad. iPhone and Apple TV unchanged.
- AntennaCore: `KeyCommand`, the catalogue of commands with their menu, title, key and modifiers, tested for clashes with each other and with reserved system shortcuts.
- Apps: `AntennaCommands` on the `WindowGroup` (iOS and macOS only), focused scene values from the Live, Guide, Search, movie player and multi-view screens and from the shell for Go, and the hidden buttons for those commands removed.
- Boards: new `Mac-Menus-Playback` and `iPad-Menus-Go`.
- Depends on the archived `add-control-hints` (the decision to use the menus) and on the current keys in `live-tv-on-iphone-ipad-mac/keyboard-shortcuts`, `search/search-with-a-keyboard`, `guide-on-iphone-ipad-and-mac`, `player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac` and `multi-view`.
