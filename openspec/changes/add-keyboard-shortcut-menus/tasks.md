# Tasks

## 1. Proposal and boards

- [x] 1.1 Proposal, delta spec, design and tasks; `openspec validate add-keyboard-shortcut-menus --strict`
- [x] 1.2 Boards `Mac-Menus-Playback` and `iPad-Menus-Go`
- [ ] 1.3 Check on an iPad with a keyboard what holding Command shows on iPadOS 26, and record it in design.md

## 2. The catalogue

- [ ] 2.1 AntennaCore: `KeyCommand` and `Key` with every command's menu, titles, key, modifiers and screens; tests citing `keyboard-commands/shortcuts-stay-clear-of-the-system-s` and `keyboard-commands/shortcuts-are-listed-in-the-menus`

## 3. Menus

- [ ] 3.1 `FocusedValues` entries for find, zoom, playback, tiles and sections; `AntennaCommands` with Edit, View, Playback and Go, on the `WindowGroup` for iOS and macOS
- [ ] 3.2 Live, Guide and Search publish their values; their moved hidden buttons go
- [ ] 3.3 The movie player and multi-view publish theirs; tile keys move to Option-Command-1 to 4
- [ ] 3.4 The sidebar root publishes sections; Command-Comma opens Sources & Settings
- [ ] 3.5 Single keys and the three text-field Command keys dimmed while typing
- [ ] 3.6 iPad UI tests pressing Command-2, Space in the live list and in the movie player, M and Space in the filter field, and Option-Command-2 in multi-view; the touched classes pass on a local iPad simulator
- [ ] 3.7 A manual pass on a Mac: every menu item on Live, Guide, Search, the movie player and multi-view, and Space after clicking the video

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `keyboard-commands/<requirement-slug>`
- [ ] 4.2 `/opsx:verify` passes
