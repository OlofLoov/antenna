# Design

## Context

See proposal.md for why. Apple TV screens are built from `ShellScreen` (`Apps/Shared/Views/Shell/ShellView.swift`) with the picture, the tab content, the info bar, the channel overlay and the tab bar as layers of one `ZStack`. The Movies and Series player is an overlay added by `ShelfSync` at the window root, and Settings is a `fullScreenCover` over the shell. Which layer has the highlight is held in the shell's `FocusState<ShellFocus?>`, the guide's local focus, and the player's own `FocusState`.

Other work in flight touches the same files: the transport controls in `ShelfPlayerView`, the overlay and guide performance work in `ShellView`, `ChannelOverlayView` and `GuideScreen`, the hero banner in `ShelfTVScreen`, and the refresh-visual-design Settings slice (PR #358) in `SettingsView`. Each of those files gets one modifier line from this change.

## Decisions

### How a screen names its hints

Each screen applies `.controlHints(_:)` with a `ControlHintScreen` value. The modifier sets a focused value (`FocusedValues.controlHints`, declared with `@Entry`), and the legend host reads it with `@FocusedValue`. SwiftUI hands the host the value set on the focused view or its nearest ancestor, so:

- the overlay's group column names `.overlayGroups` and its channel column and panel name `.overlayChannels`, and the legend follows the highlight across without the overlay reading its focus state in `body`;
- the tab bar names `.tabBar`, so a raised bar over Movies shows the bar's hints while it has the highlight and the rows' hints once the highlight goes back down;
- a title page over the rows wins because the rows are disabled under it.

Options considered:
- An environment value set by each screen (rejected): the environment flows down, and the legend has to be drawn once, above every layer, from whichever screen has the highlight.
- A preference key, last value wins (rejected): every layer in the `ZStack` reports at once, so the overlay could not tell groups from channels, and the raised tab bar over Movies would always win.
- A focused value (chosen): it follows the highlight, needs no state in the screens, and costs one modifier per screen.

`ControlHintScreen` lives in AntennaCore with the hint lists, the corner, the spoken sentence and the schedule, so the lists are unit tested and the views only draw them. Its cases: `livePicture(swipe:)`, `infoBar(swipe:)`, `overlayGroups`, `overlayChannels`, `guide`, `tabBar`, `titleRows(ShelfTitle.Kind)`, `titlePage`, `titlePlayer(scrubbing:)`, `settings`. The swipe preference is an associated value because it changes what up and down do on Live, and scrubbing because a slide changes what select and Back do in the player.

Where the modifier goes:

| Screen | View | Value |
|--------|------|-------|
| Live full screen, info bar | the picture button in `ShellScreen` | `.live(swipe:infoBar:)`: `.infoBar` while the bar shows, else `.livePicture` |
| Channel overlay | `ChannelOverlayView` group column, channel column, panel | `.overlayGroups`, `.overlayChannels` |
| Guide | `GuideScreen` root | `.guide` |
| Tab bar | `ShellBarLayer` | `.tabBar` |
| Movies, Series | `ShelfTVScreen` section (rows and grid) | `.titleRows(kind)` |
| Title page | `TitleScreen`, tvOS branch | `.titlePage` |
| Movie and episode player | the picture button in `ShelfPlayerView`'s `TitleRemoteLayer` | `.titlePlayer(scrubbing: transport.isScrubbing)` |
| Settings | `SettingsView` navigation stack | `.settings` |

The live info panel, the movie player's track panel, Search, multi-view, onboarding and the paywall name nothing, so no legend shows there.

### Where the legend is drawn

`.controlHintsLegend()` adds `ControlHintsHost`, an overlay that draws `ControlHints.Legend` for the focused screen. It is applied twice: on `ShellScreen` in `ShellView` (`ShellViewParts.swift`), after `ShelfSync` so it draws over the movie player, and on `SettingsView`, because a full-screen cover hides the shell's overlay. The legend is padded by `Metrics.televisionSafeArea` (60 pt top and bottom, 80 pt at the sides) and aligned to the screen's corner: top right for `livePicture`, `infoBar` and `titlePlayer`, where the bottom holds the info bar, subtitles and score graphics; bottom right for every other screen, where the top right holds the clock.

### When it shows

`ControlHintSchedule` (AntennaCore) decides. The host calls `arrive(at:)` each time the focused screen changes; it returns true when the screen is a new place and that place has shown fewer than three times since launch. On true the host sets `hideAt` to now plus six seconds, and a task keyed on `hideAt` clears it then. A screen change within the same place updates the legend's lines without moving `hideAt`. Places: `livePicture` and `infoBar` are one, so zapping with the info bar does not flash the legend; `overlayGroups` and `overlayChannels` are one; every other screen is its own. A nil focused value, as while focus moves between layers, changes nothing.

Options considered for when to stop:
- Always on (rejected): it would sit on the picture for the whole film.
- Show on every screen change (rejected): picking a channel from the overlay is a screen change, so a viewer zapping through the overlay would see it every few seconds.
- On for the first days after install (rejected): a viewer who wants it would lose it on a date they cannot see, and a time limit needs the clock in tests.
- Three showings per place per launch, until switched off (chosen): enough to learn a screen each evening, quiet after that, and the next launch teaches again.

With Reduce Motion on, the legend appears and goes without the 0.3-second fade.

### The switch

`ControlHintsSetting` is a small Codable struct, `{"shows": true}`, stored as JSON in `UserDefaults.standard` under `hints.remote`, read through `@AppStorage` in the host and in `RemoteHintsRow`. A missing or unreadable value reads as on. It is per device, as the hard constraint on per-device state asks, and holds no secret or stream link. The row is a system `Toggle`, "Show remote hints", in its own section after Preferences on Apple TV, identifier `settings.remoteHints`. On Apple TV the list cell takes focus and the identifier sits on the control inside it, so the UI test looks for the focused cell that contains it. Switching it on sets `hideAt` so the Settings legend shows at once.

### The legend

`ControlHints.Legend` (`Apps/Shared/Components/ControlHints/`) takes a `ControlHintScreen` and draws a `Label("Remote", systemImage: "appletvremote.gen4.fill")` header, then a `Grid` with one row per hint: the control's SF Symbol, its name in caption semibold, and the action in caption, muted. Symbols: `circle.circle` for Click, `hand.tap` for Hold, `arrow.up.and.down`, `arrow.left.and.right`, `arrow.up.and.down.and.arrow.left.and.right` for the swipes, `playpause` for Play/Pause and `chevron.backward` for Back. No Apple remote artwork is copied. The panel is `Palette.scrimTint` at 0.82 in the large corner shape with large padding, the same fill as the number box and the info bar. Text uses the caption text style, 25 pt on Apple TV, above the 23 pt floor. The legend is one accessibility element with the identifier `hints.legend` and `ControlHintScreen.spoken` as its label, and it never takes focus or hit tests.

### Mac and iPad with a keyboard

Not built in this change. The Live, Guide and title page screens on iPad and Mac already answer the arrow keys, Return, Space, Command-F and, on Mac, M and Command-Up and Down. They are zero-size buttons with `keyboardShortcut`, so neither the Mac menu bar nor the iPad Command-hold shortcut list shows them. The platform's way to show shortcuts is those two lists, and moving the keys into `.commands` menus would show them on both without a legend over the picture. A legend through this mechanism would also need a focused view on Mac, where clicking the video leaves none, and keyboard detection on iPad. Recorded as a follow-up change: "List the keyboard shortcuts in the menu bar and the iPad shortcut list". iPhone has neither remote nor shortcuts.

### The movie player

`add-title-transport-controls` left room for these hints in `TitleRemoteLayer` and named the state they can read. While playing or paused, `titlePlayer(scrubbing: false)` lists click left or right to skip 10 seconds, swipe left or right to scrub, play/pause, hold for audio and subtitles, and Back to stop and go back. Once a slide has set a new place (`TitleTransport.isScrubbing`), `titlePlayer(scrubbing: true)` lists swipe left or right to move it, click to play from there, and Back to cancel. Both count as one place, so starting a scrub does not bring a faded legend back. The legend sits top right, clear of the transport bar along the bottom. The live timeshift scrubber gets no hints in this change.

## Boards

Under `openspec/specs/design-system/boards/`, new:

- `TV-Hints-Live`: Live full screen with the info bar and the legend top right.
- `TV-Hints-Overlay`: the channel overlay with the highlight on a channel and the legend bottom right.
- `TV-Hints-Movies`: the Movies rows with the legend bottom right.
- `TV-Settings-Hints`: Settings with the "Show remote hints" row focused, on.

Not drawn: the legend on the guide, the tab bar, a title page, the movie player and the overlay's groups. Each is the same panel with the lines from the table in `ControlHintScreen.hints`, in the corner named above. When PR #358 lands, `TV-Settings-Hints` follows its split layout with the row in the right-hand column.

Design-system requirements that apply: "Type uses text styles", "Text stays above the platform caption floor", "Apple TV content stays in the safe area", "One spacing and radius scale", "Live video keeps playing under overlays", "Accessibility identifiers follow the board" and "Visual changes update the boards in the same change".

## Identifiers

- `hints.legend`: the legend, its label the spoken sentence.
- `settings.remoteHints`: the switch.
- `-ui-testing-hints`: Debug-only launch argument; clears `hints.remote` at launch and keeps the legend from fading.
