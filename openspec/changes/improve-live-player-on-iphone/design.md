# Design

## Context

Boards: `iPhone-FullScreen` (the full-screen picture with its strip) and `iPhone-Player` (the picture pinned at the top, portrait). This change adds to both: the channel line at the top of `iPhone-FullScreen`, and the Previous channel button in the strip on both. `iPad-Player` uses the same strip and is not redrawn; the button sits in the same place. The double-tap note reuses the timeshift notice drawn on `iPhone-Player-Timeshift`. Not drawn: the swipe and double-tap themselves, which have no chrome.

Design-system requirements that apply: "Visual changes update the boards in the same change", "Live video keeps playing under overlays", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Text meets contrast minimums".

What the code does today:
- `RootView` picks `CompactTabs` when the horizontal size class is compact. A Plus or Pro Max iPhone held sideways reports regular, so it gets `LiveRegularView`, the iPad sidebar.
- `CompactTabs` turns full screen on in `.onChange(of: verticalSizeClass)`, which fires only on a rotation. `LiveModel.setFullScreen` ignores the call while nothing plays, and `LiveModel.suspend()` clears full screen before a movie. So picking a channel sideways, launching sideways, opening Live sideways and coming back from a movie all stay in the list layout with the tab bar and the now-playing line.
- In full screen nothing names the channel except the error panel.
- The strip has pause, progress, clock, LIVE, tracks, Picture in Picture and full screen. Timeshift skips 15 back and 30 forward from its strip buttons and the arrow keys.

## Goals / Non-Goals

**Goals:**
- Full screen on iPhone is a function of the current state, not of a rotation event.
- The gestures go through the same model calls as the buttons, so UI tests and VoiceOver reach them without a finger.

**Non-Goals:**
- Turning the interface upright when the user exits full screen sideways.
- Changing the skip amounts of the strip buttons and arrow keys.
- Gestures on Apple TV and on multi-view tiles.

## Decisions

### Full screen is derived from all its inputs

`CompactTabs` computes `SidewaysLive(sideways:channel:)`: `sideways` is true when the tab is Live, the vertical size class is compact and the device is a phone; `channel` is the playing channel's id. It observes it with `.onChange(of:initial: true)`. When the new value is sideways with a channel, it calls `live.setFullScreen(true)`. When the old value was sideways and the new one is not, it calls `setFullScreen(false)`. Anything else leaves full screen alone, so the full-screen button in portrait keeps working and a channel change in portrait full screen does not exit.

`resumeIfSuspended()` tunes the same channel, so the id does not change after a movie. The movie plays from another tab, though, so coming back to Live flips `sideways` and full screen returns. A movie started from Live itself through Siri is the only gap; see Risks.

Options considered:
- Keep the rotation handler and add calls at each entry point (pick, appear, resume). Rejected: five call sites that each have to remember the rule, and the next entry point forgets it.
- Put the rule in `LiveModel` with the size class pushed in. Rejected: the tab selection and size class are view state, and the model would hold copies of them.
- Observe a derived value in the view. Chosen: one place reads every input, and `initial: true` covers launch.

### Exit full screen while sideways shows the list sideways

Options considered:
- Hide Exit full screen while sideways. Rejected: the user loses a way out, and on a Mac keyboard the Escape shortcut would do something the screen does not offer.
- Ask the window scene to turn the interface upright, as some video apps do. Rejected for now: it fights the user's hand, needs `requestGeometryUpdate` and per-scene orientation masks, and is hard to test in the simulator.
- Leave full screen and show the list sideways. Chosen. Because the derived value includes the channel id, picking or swiping to another channel fills the screen again, and turning upright and back does too.

### Every iPhone stays on the phone layout

`RootView.compact` is true on a phone (`UIDevice.current.userInterfaceIdiom == .phone`) as well as at compact width. On a phone, `RootView` also sets `traitOverrides.horizontalSizeClass = .compact` on each window scene, so UIKit's tab bar and the screens that read the size class (the track picker's sheet or popover, Guide sources, the reminder banner) match the tab bar layout on a Pro Max held sideways. A first try set only the SwiftUI environment value; UIKit's tab bar still saw a regular width, and on a sideways Pro Max in full screen the app never went idle, so taps waited a minute in UI tests. iPad and Mac are unchanged. The `*RegularUITests` classes skip on anything but an iPad, so none of them ran on a sideways Pro Max before either.

Options considered: pass a `compact` flag down to each screen (rejected, a layout `Bool`), override only `RootView`'s choice (rejected, the track picker would pop over on a sideways Pro Max inside the tab layout), or override the SwiftUI environment value below the root (rejected, see above).

### The channel line rides with the controls

In full screen, `LivePicture` draws `Browse.PictureTitle` at the top under the same condition as the strip at the bottom (`controlsShown`, a channel playing, no failure), with the same `.opacity` transition and `ControlsTimer` delay. It shows the logo, the channel name and "Now: <programme>" on a top scrim at `Palette.scrimTint` 0.72, matching the strip. Outside full screen the line under the picture already names the channel, so the top line is not drawn there. The error panel keeps naming the channel, since it stays until the user acts on it.

### Swipe direction follows Apple TV

Swipe up plays the next channel in the list and swipe down the one before, as on the Apple TV remote (`ShellScreen.zap`, steps +1 for up). The list is what the Live list shows (`LiveModel.rows`, the open group narrowed by the filter); when the playing channel is not in it, All channels. It wraps at both ends. A list of one does nothing. The gesture is a `DragGesture(minimumDistance: 24)` that counts when the vertical travel is at least 60 pt and larger than the horizontal travel, so the timeshift scrubber's horizontal drag is untouched.

The swipe works in and out of full screen and on the iPad and Mac picture too. On a Mac it is a click-drag on the picture, which nothing else uses. The model call is `LiveModel.zap(by:)`, and `Catalogue.neighbor(of:in:by:)` in AntennaCore does the list arithmetic, with tests.

### Previous channel remembers the last switch

`LiveModel` keeps `lastChannel`, the channel playing before the most recent `tune` to a different channel. Previous channel plays it, which sets `lastChannel` to the one just left, so two presses flip back. With no `lastChannel`, as after a relaunch, it falls back to the most recent other channel in Recents, the rule Apple TV's swipe left uses. Options considered: Recents only (rejected: a channel counts as watched after ten seconds, so a quick flip between two games skips the one just left), or a separate stored history (rejected, more stored state for the same result).

The button is `Browse.PreviousChannelButton`, symbol `arrow.uturn.backward`, 44 pt hit area, identifier `browse.player.previous`, label "Previous channel", dimmed and disabled with nothing to go back to. It sits in the extras before the track button on both strips, so the timeshift strip gets it too. If the favorite star from the parallel favorites work lands in the strip, the button sits next to it.

### Double-tap skips 15 seconds either way

`.onTapGesture(count: 2)` with its location, before the single tap that shows the controls. The left half skips back, the right half forward, both 15 seconds through `TimeshiftModel.skip(seconds:)`, which the existing `skip(forward:)` now calls with the limits. 15 forward rather than 30 because the two halves are one gesture and a double-tap overshooting by 30 is hard to undo by feel; the strip buttons keep 30.

When the channel cannot rewind, or a forward skip is already at live, nothing moves and the timeshift notice says "Rewind isn't available on this channel" or "Already live" for its usual four seconds. The strings live in `TimeshiftText`.

The cost is that a single tap waits for the double-tap window before the controls show. Video apps on iPhone behave the same, and the UI tests already allow two seconds.

### VoiceOver

The picture element (`browse.player.surface`) gets named accessibility actions: "Channel up", "Channel down", and while the channel can rewind "Back 15 seconds" and "Forward 15 seconds". Previous channel is a button in the strip. "Channel up" and "Channel down" rather than "Next" and "Previous" keep the swipe apart from the Previous channel button.

### Identifiers

- `browse.player.previous`: Previous channel button.
- `browse.player.title`: the full-screen channel line.
- UI tests reach swipe and double-tap through `XCUIElement.swipeUp()`, `swipeDown()` and `doubleTap()` on a coordinate in each half of `browse.player.surface`.

## Risks / Trade-offs

- [Siri or Shortcuts starting a movie while Live is on screen sideways leaves the list sideways after the movie, because neither the tab nor the channel changes] → rare; turning the phone or picking a channel fixes it. Not worth a model flag now.
- [Single taps wait for the double-tap window] → accepted, see above.
- [A swipe that starts on the scrubber could change channel] → the gesture needs mostly vertical travel, and the scrubber drags sideways.
- [The capability's main spec does not exist until `add-live-tv-on-iphone-ipad-mac` archives] → this change only adds requirements, so archiving it first creates the spec and the other change's additions land beside them later.
