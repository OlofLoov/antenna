# Design

## Context

The owner asked on iPhone: "the icon for changing sound as well as subtitles is not obvious. We have two icons for essentially the same thing?"

Before this change `TrackPicker` had two buttons. `OpenButton` (`text.bubble`, "Audio and subtitles") opened a custom list: a sheet with a grabber and Done at compact width, a popover at regular width and on Mac. `SubtitlesButton` (`captions.bubble`, filled when on) turned subtitles on or off in one tap. Both are speech bubbles, 44 pt apart. The subtitles button showed in full screen, at regular width and on Mac, and not in the small iPhone player, so the strip changed between layouts too.

Apple's own apps settle it. The TV app on iOS 26 and the AVKit player (`AVPlayerViewController`) show one captions bubble in the controls. It opens a system menu with the audio languages and the subtitles, Off first, and closes on a pick. Turning subtitles on takes two taps there.

## Boards

- `iPhone-Player-Tracks`, `iPad-Player-Tracks`: the strip's one button and the system menu above it, in place of the sheet and the popover.
- `iPhone-Title-Player-Tracks`, `iPad-Title-Player-Tracks`: one button in the top trailing capsule, the menu below it.
- `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`: the capsule holds one button.
- The Live track boards draw two sound tracks instead of three so the menu fits above the tab bar on iPhone and above the strip on iPad. The title boards keep three.
- `iPhone-FullScreen-Subtitles`: the one button with a filled bubble, no second button.
- `iPad-Player`, `iPhone-Player`, `iPad-Menus-Go`, `Mac-Menus-Playback`: the second bubble is gone and the first draws `captions.bubble`.
- Apple TV boards (`TV-Player-Tracks`, `TV-Player-Subtitles`, `TV-Title-Player-Tracks`) do not change.

Design-system requirements followed: `design-system/liquid-glass-stays-on-the-navigation-layer` (the title capsule keeps its glass; the menu is the system's own), `design-system/one-spacing-and-radius-scale`.

## Decisions

### One button and a system menu

Options considered:
- Keep both buttons and give them different symbols, such as `waveform` for sound (rejected): still two buttons for one topic, and no Apple app does it.
- One button opening the existing custom sheet and popover (rejected): keeps our own Done button, grabber and detents, and the sheet covers the channel list at compact width.
- One button opening a system `Menu` (chosen): matches the TV app and AVKit, looks right on iPhone, iPad and Mac without per-size code, and VoiceOver, pointer and keyboard work as in every other menu.

The button is `captions.bubble`, `captions.bubble.fill` while full subtitles are on (`TrackChoice.fullSubtitlesOn`), so the state the old switch showed is still on the button. Forced subtitles alone read as off, as before. The VoiceOver label is "Audio and Subtitles" with the value "Subtitles On" or "Subtitles Off", strings the Apple TV switch already has in every language. It is grayed out only when the stream has one sound and no subtitles (`TrackMenu.hasChoices`).

### What the menu holds

- Section "Audio": one toggle per track, checked when current, the name as the title and the sound format as the subtitle line when the engine reports it.
- Section "Subtitles": Off first, then each track. With no subtitles, one text row, "No subtitles in this stream", which the system draws as a disabled row.
- A last section without a title: the stream line and, on the Antenna player path, "AirPlay not available for this stream". The old list had these as a footer; a system menu has no section footers, so they are text rows that do nothing.

Picking a row closes the menu. The old list stayed open after a pick so a viewer could hear the change before closing it; the system menu does not do that, and a second tap reopens it. `.menuActionDismissBehavior(.disabled)` would keep it open, but the check would then have to move while the menu shows, and the Apple apps this follows close theirs.

### Keeping the controls up behind the menu

The controls hide on a timer, and the timer skips while `pickerOpen` is true. A SwiftUI `Menu` has no binding for its open state. On iOS the menu builds its rows when it opens, so `onAppear` and `onDisappear` on the menu's last section set `pickerOpen` through `openPicker()` and `closePicker()`. On a Mac the menu's rows may be built ahead of time, so the hook is iOS only; there the controls hide on the pointer timer and the open menu stays where it is.

### Accessibility identifiers

- `player.tracks` stays on the one button.
- The system menu does not pass SwiftUI accessibility identifiers to its rows (checked on the iOS 27.2 simulator), so `player.trackPicker.*` is gone. UI tests find a row by its label inside the menu's list and read the check from its selected state.
- `player.subtitles` and `player.trackPicker.done` are gone. The Apple TV panel's `player.panel.subtitles` and `player.panel.track.<n>` stay.

### Turn subtitles on or off in one step

The requirement keeps its name and its Apple TV scenarios, so the switch in the info panel and the tests that cite it stay. Its iPhone, iPad and Mac scenarios move to `one-button-for-audio-and-subtitles`, which says subtitles take two taps there.

### Apple TV

The info panel (hold select: Info, Audio, Subtitles, and the Subtitles switch) already follows the system player and offers the same rows as the iPhone menu, from the same `TrackMenu` rows. On the Apple TV simulator `PlayerPanelTVUITests`, the Subtitles switch tests in `ShellUITests` and the movie panel test in `ShelfTVUITests` pass, so the panel stays as it is.
