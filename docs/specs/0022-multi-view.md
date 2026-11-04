# 0022. Multi-view: up to four live tiles on Apple TV and Mac

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0004, 0005, 0006
- Platforms: tvOS, macOS. Not iOS (see Scope). iPadOS v1 has no multi-view; whether a later version does is an open question.
- Builds on specs 0007 (overlay, reused as the per-tile channel picker), 0008 (channel-change event, zap bar, current group), 0010 (Mac browse layout, list, keyboard focus), 0013 (`RowKey`, catalogue lookup), 0015 (tvOS shell, Menu, last channel), 0017 (playback engine, draft), 0018 (failure text, Now Playing, draft).
- 0017 and 0018 are drafts on their own branches. Citations of them give the criterion number in the current draft and its subject, for example `0017/AC-43 (display criteria)`. What this spec needs from 0017 that its draft lacks is under "Required of other specs".
- 0007, 0008, 0010 and 0015 are Accepted. The changes this spec needs in them are listed under "Required of other specs"; the implementing PR carries one amendment commit per spec, ahead of the code, citing the criterion ids named there.
- Blocked on (implementing PR, not acceptance): 0017 gaining the additions listed under "Required of other specs". Criteria are written against fakes that already have them.

## Design

Boards:
- `docs/design/boards/TV-MultiView.dc.html`: four tiles, tile 2 focused and audible.
- `docs/design/boards/TV-MultiView-Two.dc.html`: two tiles side by side just after entry, tile 2 focused, `multiView.hint` at the bottom.
- `docs/design/boards/TV-MultiView-Failed.dc.html`: three tiles (two on top, one centred below), tile 1 buffering, tile 3 failed and focused, nothing audible.
- `docs/design/boards/TV-MultiView-Actions.dc.html`: `multiView.actions` open on tile 2 over the four-tile grid.
- `docs/design/boards/TV-MultiView-Swap.dc.html`: tile 2 full screen with `multiView.swapBadge`.
- `docs/design/boards/TV-MultiView-Pick.dc.html`: the 0007 overlay in pick mode over the three-tile grid, with `overlay.pickTarget`, the `TILE n` row badges, `overlay.watch` reading "Show in tile 2" and `overlay.multiView` reading "Add as new tile".
- `docs/design/boards/iPad-MultiView.dc.html`: the Mac window drawn in the iPad frame, sidebar collapsed, 0010's list, `multiView.toolbar` and four tiles with tile 2 selected and audible.
- `docs/design/boards/iPad-MultiView-Failed.dc.html`: the same window with three tiles, tile 3 failed and selected, nothing audible.

The `iPad-` prefix on the two Mac boards follows the design README's convention that iPad and Mac share the 1194 by 834 frame. It does not put iPadOS in scope.

Element identifiers are comments on those boards (DR-11). Frames on the boards come from AC-2's function, so the boards and the criteria share one set of numbers.

Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13, DR-14.
Deviations:
- DR-2: a video tile cannot be white-filled, so the focused tile gets the 5 pt `#F2F4F8` ring and shadow of README section 3's focused content card, and its label chip becomes the white card with the muted-on-focus token on the number.
- DR-5: on Mac `multiView.tile.<n>.remove` is drawn 28 pt and `multiView.tile.<n>.retry` and `multiView.exit` 32 pt; each gets a 44 by 44 pt hit area, as 0010 does for its player controls.
- DR-7: tile labels show number and name only, no programme, so no progress bar is owed; the pick-mode rows keep theirs.
- DR-3: nothing in a tile is accent-coloured; the speaker glyph uses Text or Text muted.
- tvOS title-safe area: the tiles run to 24 pt from the screen edge and the bottom-row labels sit 45 pt above the bottom edge, inside Apple's 60 pt title-safe inset. Accepted because the grid is full-bleed video and a 60 pt margin would shrink every tile by 7 percent; the labels are short and repeat what the overlay shows.

Display mode matching is the product's differentiator in ADR-0001. Multi-view is the one place it is switched off (AC-31): four tiles cannot each own the display mode. ADR-0001's follow-ups are unaffected.

Not drawn, to be added before the implementing PR:
- `overlay.multiView` over full-screen live (AC-11): `Main.dc.html`'s panel with a third button after the star, the grid glyph and "Add to multi-view" at 24/600 on the 0.12 surface, 64 tall, as drawn for "Add as new tile" on `TV-MultiView-Pick.dc.html`.
- `multiView.action.retry` (AC-19b): a fourth 72 pt row "Try again" above "Full screen" on `TV-MultiView-Actions.dc.html`, focused.
- A tile playing an audio-only stream: the tile on Ground with the 132 by 88 logo or initials tile of 0008 centred (DR-8), label unchanged.
- The buffering ring on Mac: 28 pt ring centred in the tile, no caption.
- The Mac swapped state (AC-42): one tile at the `MultiViewLayout` single-tile frame of the tile area, toolbar unchanged, `multiView.count` reading "Tile 2 of 4" in the 14 pt muted style.
- The Mac row context menu with `multiView.add` ("Add to Multi-view", or the disabled "Multi-view is full") and the View menu item: system menus, no custom drawing.

## Problem

Sports and news viewers want two to four live channels on one screen with the sound from the one they are watching. TiviMate users call its multi-view "spectacular" and keep paying for it (research note, love item 4), and Channels DVR users push it to nine streams. Antenna plays one channel at a time on every platform.

## Scope

In:
- tvOS: entering multi-view from the 0007 overlay; two, three and four tile layouts; moving focus between tiles; audio follows focus; picking a tile's channel through the 0007 overlay in a pick mode; adding a tile from that picker; an actions panel per tile (full screen, change channel, retry, remove); one tile full screen and back; leaving with Menu.
- macOS: entering from a channel row's context menu or Command-Shift-M; the same layouts in 0010's detail column with the sidebar collapsed; audio follows selection; picking a tile's channel from 0010's list; double-click for one tile full size and back; remove and exit buttons; a minimum window width while in multi-view.
- A cap of four tiles, lowered to two on Apple TV HD and on Intel Macs, and lowered for the rest of a session when the device refuses another decoder.
- Per-tile buffering and failure states, with failure text for a provider that refuses another connection and for a device that cannot decode another stream.
- Display mode left alone while tiles play; HLS tiles capped at 1080 lines while they are tiles.
- `MultiViewLayout`, `MultiViewCapacity`, `MultiViewSession` and `MultiViewFailureText` in `Packages/AntennaCore/Sources/AntennaCore/MultiView/` as pure value types and functions (ADR-0005). `MultiViewModel` and `MultiViewScreen` in `Apps/Shared/Views/MultiView/`, which own one `RoutedEngine` (0017) per tile and carry out the commands `MultiViewSession` returns.
- Accessibility identifiers with prefix `multiView.`, plus the overlay identifiers listed under "Required of other specs".

Out (explicitly):
- iPhone. Four 16:9 tiles on a 390 pt wide screen are 187 pt wide, too small to read a channel; four hardware decodes drain the battery and heat the phone; four streams on cellular burn through a data plan. No later spec owns it.
- iPad. A later spec decides, reusing the Mac interaction (tap selects, the list picks).
- User-selectable layouts (one large and three small, picture in picture inside multi-view), more than four tiles, resizing or dragging tiles. A later multi-view spec if users ask.
- Saving or restoring a multi-view set across launches: 0028 (session restore) restores the single last channel only.
- Timeshift, catch-up or Start over in a tile: 0019 and the catch-up spec; tiles are live only.
- Audio and subtitle track pickers per tile, AirPlay and system Picture in Picture while in multi-view: 0018 owns those for single playback and they are not offered here.
- Entering multi-view from the guide (0009) or search (0012).
- Bandwidth measurement or adaptive downgrades beyond the 1080 cap.
- Pausing a single tile. Tiles are live; play/pause on tvOS and Space on Mac do other things or nothing (AC-20, AC-47).
- Paywall: multi-view is part of the one unlock (ADR-0006); the shell assumes entitlement (DR-14).

## User flow

tvOS:
1. A channel plays full screen. The user presses select; the 0007 overlay opens. They focus another channel and swipe right into the panel past Watch and the star to "Add to multi-view".
2. The overlay closes. The picture splits into two tiles: the channel that was playing on the left, the new one on the right with focus and sound. A hint names the buttons for five seconds.
3. Swiping moves focus between tiles. The sound follows focus.
4. Select on a tile opens the overlay in pick mode. Select on a channel shows it in that tile. "Add as new tile" in the panel adds a third or fourth tile.
5. A long press on select opens the tile's actions: Full screen, Change channel, Remove from multi-view, and Try again on a failed tile.
6. Play/Pause shows the focused tile full screen; the other tiles keep playing unseen. Play/Pause or Menu returns to the grid.
7. Menu in the grid leaves multi-view. The focused tile's channel keeps playing full screen; the others stop.

macOS:
1. A channel plays inline (0010). The user right-clicks another row and chooses "Add to Multi-view", or moves the keyboard focus to it and presses Command-Shift-M.
2. The sidebar collapses. The detail column shows two tiles; the new one is selected and audible.
3. Clicking a tile, or Command-1 to Command-4, selects it and moves the sound. Clicking a row in the list shows that channel in the selected tile. The context menu adds a tile.
4. Double-click a tile to fill the tile area; double-click or Escape to return.
5. The tile's close button removes it. "Exit multi-view" in the toolbar keeps the selected tile's channel in 0010's inline player.

## Types

Names the criteria use. Field lists are the contract; the implementing PR may add private members.

```swift
public enum MultiViewDevice: Sendable, Equatable { case appleTV(machine: String), mac(appleSilicon: Bool) }
public enum MultiViewCapacity { public static func maxTiles(for device: MultiViewDevice) -> Int }

public enum MultiViewLayout {
    /// Tile frames in container coordinates, in tile order. Count 1 is the swapped frame on macOS; tvOS swaps to the full container.
    /// Empty for a count outside 1...4 or a container too small for one point of tile width.
    public static func frames(count: Int, in size: CGSize, margin: Double, gap: Double) -> [CGRect]
}

public struct MultiViewTile: Sendable, Equatable, Identifiable {
    public let id: UUID                 // one engine per id, for the tile's lifetime
    public var channel: RowKey          // 0013/AC-11a
    public var failure: PlaybackError?  // nil while loading, playing, buffering, paused or idle
}

public struct MultiViewSession: Sendable, Equatable {
    public private(set) var tiles: [MultiViewTile]
    public private(set) var focused: Int          // index into tiles; "selected" on macOS
    public private(set) var isSwapped: Bool       // the focused tile fills the container
    public private(set) var capacity: Int
    /// nil when playing == adding or capacity < 2.
    public init?(playing: RowKey, playingTile: UUID, adding: RowKey, capacity: Int, newID: UUID)
    public var startCommands: [MultiViewCommand] { get }
    public mutating func apply(_ action: MultiViewAction) -> [MultiViewCommand]
}

public enum MultiViewAction: Sendable, Equatable {
    // user actions address tiles by index
    case add(RowKey, newID: UUID), replace(tile: Int, with: RowKey), remove(tile: Int), focus(tile: Int), retry(tile: Int)
    case swap, unswap, exit
    // engine and catalogue events address tiles by id
    case failed(tile: UUID, PlaybackError), recovered(tile: UUID)
    case catalogueChanged(resolvable: Set<RowKey>)
}

public enum MultiViewCommand: Sendable, Equatable {
    case load(tile: UUID, channel: RowKey, muted: Bool)
    case setMuted(tile: UUID, Bool)
    case setAppliesDisplayCriteria(tile: UUID, Bool)
    case setMaximumVideoHeight(tile: UUID, Int?)
    case stop(tile: UUID)
    case end(survivor: UUID?)           // nil when no tile is left
}

public enum MultiViewFailureText {
    public static func text(for error: PlaybackError, source: String, keychainSyncs: Bool,
                            otherPlayingTilesOnSameSource: Int, device: MultiViewDevice) -> (title: String, body: String)
}
```

Commands carry a `RowKey`, never a URL. `MultiViewModel` resolves the channel through the catalogue and calls `load(channel.streamURL, options:)` with `PlaybackOptions(maximumVideoHeight: 1080, appliesDisplayCriteria: false, startsMuted: muted)` (fields added to 0017, see "Required of other specs"). `MultiViewModel` awaits each returned command in order before the next, and a newer action's batch waits for the previous one, so rapid focus moves end in the last target's mute state and two engines are never unmuted at once. On macOS `setAppliesDisplayCriteria` is a no-op (there is no `AVDisplayManager`) and is not asserted. Tile indices in identifiers and copy are one-based: `multiView.tile.1` is `tiles[0]`. A tile's audio value is "on" when it is the focused (tvOS) or selected (macOS) tile and its `failure` is nil, and "off" otherwise.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber. "Fake engine" is a `PlaybackEngine` conformance that records calls in order and emits the states the test tells it to; UI tests inject one per tile under a launch argument and write the call log to the test's temp directory. Nothing derived from `streamURL` is set on any accessibility attribute (ADR-0003). In UI and integration tests, "at once" means the calls are recorded before the event that caused them has finished being handled, on the injected clock; real-time bounds are device criteria (AC-35, AC-36).

### AC-1 Capacity table (core)
Given `MultiViewCapacity.maxTiles(for:)`
When it is called with `.appleTV(machine:)` for "AppleTV5,3", "AppleTV6,2", "AppleTV11,1", "AppleTV14,1", "AppleTV99,9", "arm64" and "x86_64", and with `.mac(appleSilicon: true)` and `.mac(appleSilicon: false)`
Then it returns 2, 4, 4, 4, 4, 4, 4, 4 and 2. "arm64" and "x86_64" are the simulator's machine strings. The values for `AppleTV6,2` and `AppleTV11,1` are provisional until AC-35 passes on those devices.

### AC-2 Layout frames (core)
Given `MultiViewLayout.frames(count:in:margin:gap:)`
When it is called for a 1920 by 1080 container with margin 24 and gap 16, for an 842 by 782 container with margin 16 and gap 12, with count 0 and 5, and for a 40 by 40 container with margin 24
Then for 1920 by 1080 it returns, as (x, y, width, height): count 1 `(43, 24, 1834, 1031)`; count 2 `(24, 279, 928, 522)`, `(968, 279, 928, 522)`; count 3 `(49, 25, 903, 507)`, `(968, 25, 903, 507)`, `(508, 548, 903, 507)`; count 4 `(49, 25, 903, 507)`, `(968, 25, 903, 507)`, `(49, 548, 903, 507)`, `(968, 548, 903, 507)`. For 842 by 782: count 1 `(16, 163, 810, 455)`; count 2 `(16, 279, 399, 224)`, `(427, 279, 399, 224)`; count 3 `(16, 161, 399, 224)`, `(427, 161, 399, 224)`, `(221, 397, 399, 224)`; count 4 `(16, 161, 399, 224)`, `(427, 161, 399, 224)`, `(16, 397, 399, 224)`, `(427, 397, 399, 224)`. Counts 0 and 5 and the 40 by 40 container return an empty array. The rule: two columns for counts 2 to 4, two rows for 3 and 4; tile width is the largest whole number for which 16:9 tiles fit inside the margins, height is the width times 9/16 rounded down; the grid is centred with offsets rounded down; with three tiles the third is centred horizontally on the second row, its offset rounded down.

### AC-3 Start (core)
Given `MultiViewSession(playing: P, playingTile: a, adding: C, capacity: 4, newID: b)` with C different from P
When `startCommands` is read
Then `tiles` is `[P (id a), C (id b)]`, `focused` is 1, `isSwapped` is false, and the commands are exactly `[.setAppliesDisplayCriteria(a, false), .setMaximumVideoHeight(a, 1080), .setMuted(a, true), .load(b, C, muted: false)]` in that order; with C equal to P, or capacity under 2, the initialiser returns nil.

### AC-4 Add (core)
Given a session with n tiles and focus on tile j
When `.add(C, newID: x)` is applied
Then with n under `capacity` and C in no tile, C is appended with id x, `focused` is n, `isSwapped` is false, and the commands are `[.setMuted(tiles[j].id, true), .load(x, C, muted: false)]`; with n at or above `capacity`, or C already in a tile, nothing changes and the result is empty.

### AC-5 Focus moves the audio (core)
Given a session with focus on tile j
When `.focus(tile: k)` is applied
Then for k different from j the commands are `[.setMuted(tiles[j].id, true), .setMuted(tiles[k].id, false)]` in that order and `focused` is k; for k equal to j the result is empty.

### AC-6 Replace (core)
Given a session with n tiles, focus on tile j, and a tile k
When `.replace(tile: k, with: C)` is applied
Then with C in no tile, tile k keeps its id, its channel becomes C, its `failure` becomes nil and the commands are `[.load(tiles[k].id, C, muted: k != j)]`; with C already in tile m different from k, the result equals `.focus(tile: m)` and no `.load` is returned; with C already in tile k, nothing changes and the result is empty.

### AC-7 Remove (core)
Given a session with n tiles and focus on tile j
When `.remove(tile: k)` is applied
Then with n of 3 or more, the first command is `.stop(tiles[k].id)`, tile k leaves `tiles`, and: when k is j, focus moves to the tile now at index k, or k minus 1 when k was the last, `isSwapped` becomes false, and `.setMuted(<that tile>, false)` follows; when k is not j, focus stays on the same tile id with no further command. With n of 2, the commands are `[.stop(removed), .setMuted(other, false), .setAppliesDisplayCriteria(other, true), .setMaximumVideoHeight(other, nil), .end(survivor: other)]`.

### AC-8 Exit (core)
Given a session with n tiles and focus on tile j
When `.exit` is applied
Then the commands are `.stop` for every tile except j in tile order, then `.setAppliesDisplayCriteria(tiles[j].id, true)`, `.setMaximumVideoHeight(tiles[j].id, nil)` and `.end(survivor: tiles[j].id)`; a failed tile j is still the survivor.

### AC-9 Failure, retry and capacity (core)
Given a session with n tiles and `capacity` 4
When `.failed(tile: id, e)` is applied for tile k's id, then later `.retry(tile: k)`, and separately `.recovered(tile: id)`
Then after `.failed` tile k's `failure` is e and the result is empty; when e is `.decoderBusy`, `capacity` becomes the larger of 2 and the number of tiles whose `failure` is not `.decoderBusy`, and never rises again in this session; `.retry` returns `[.load(tiles[k].id, tiles[k].channel, muted: k != focused)]` and clears `failure`; `.recovered` clears `failure` and returns nothing. `MultiViewModel` applies `.recovered` only when the engine of a failed tile reports `.loading` after a `load` this session issued (AC-28 or AC-6); otherwise 0017's `.failed` is terminal.

### AC-9a Stale and out-of-range actions (core)
Given a session
When `.failed` or `.recovered` names an id that is not in `tiles` (a tile already removed), or `.focus`, `.replace`, `.remove` or `.retry` names an index outside `tiles`
Then the session is unchanged and the result is empty.

### AC-9b Swap (core)
Given a session with focus on tile j
When `.swap`, then `.unswap`, are applied, and separately `.swap` followed by `.remove(tile: j)` with 3 or more tiles
Then `.swap` sets `isSwapped` true and `.unswap` sets it false, each returning no commands; removing the swapped tile sets `isSwapped` false as AC-7 says; `.focus(tile: m)` while swapped sets `isSwapped` false and then behaves as AC-5, so a pick or Command-k that lands on another tile returns to the grid.

### AC-9c Catalogue change (core)
Given a session with tiles whose channels are P, C and D
When `.catalogueChanged(resolvable:)` is applied with a set lacking C, and separately with an empty set
Then without C the result equals applying `.remove` to C's tile; a set lacking several channels applies `.remove` for each missing tile in tile order, ending as AC-7's two-tile case when one is left; with the empty set the result is `.stop` for every tile in tile order followed by `.end(survivor: nil)`.

### AC-10 Failure text (core)
Given `MultiViewFailureText.text(for:source:keychainSyncs:otherPlayingTilesOnSameSource:device:)`, where the count is the number of other tiles on the same source whose engine is `.playing`
When it is called with `.serverBusy` and `.serverError(509)` and count 1; with `.unauthorized` and count 1; with those three errors and count 0; with `.decoderBusy` for `.appleTV(machine: "AppleTV14,1")` and for `.mac(appleSilicon: true)`; and with `.offline` and count 2
Then `.serverBusy` and `.serverError(509)` with count 1 return title "Your provider refused another stream" and body "Many providers allow one or two streams per account at a time."; `.unauthorized` with count 1 returns the same title and the body "Many providers allow one or two streams per account at a time. If this channel fails on its own too, check the login for this source."; with count 0 each returns the title and body that 0018's `PlaybackFailureText.describe(e, source:, keychainSyncs:)` (0018/AC-18, failure text) defines for e; `.decoderBusy` returns "This Apple TV can't play another stream" and "This Mac can't play another stream", each with body "Remove a tile or pick a lower-resolution channel."; `.offline` returns 0018's text for `.offline`. No returned string contains a URL, host or credential.

### AC-11 Entry button in the overlay (tvOS)
Given full-screen Live with the engine `.playing` or `.buffering`, the 0007 overlay open, and focus on channel C
When the panel is rendered
Then with C different from the playing channel, `overlay.multiView` exists after `overlay.favorite`, labelled "Add to multi-view", and swiping right from the channel row reaches `overlay.watch`, `overlay.favorite`, `overlay.multiView` in that order; with C the playing channel, or the engine `.idle`, `.loading`, `.paused` or `.failed`, `overlay.multiView` does not exist.

### AC-11a Entering shows two tiles (tvOS)
Given AC-11's overlay with `overlay.multiView` focused for channel C while channel P plays
When the user presses select
Then `overlay.root` is dismissed, `multiView.root` exists with `multiView.tile.1` labelled for P and `multiView.tile.2` labelled for C, and focus is on `multiView.tile.2`.

### AC-11b Hint on entry (tvOS)
Given multi-view was entered per AC-11a
When 5 seconds pass on the injected clock
Then `multiView.hint` existed and was not focusable before the deadline and does not exist after it; it is not shown again until multi-view is entered again.

### AC-11c Entering keeps the playing engine (tvOS)
Given AC-11a's entry while P plays on engine E
When the call logs are read
Then E is tile 1's engine and received no `load`, `pause` or `stop`; E received `setAppliesDisplayCriteria(false)`, `setMaximumVideoHeight(1080)` and `setMuted(true)` in that order, all before a second engine received its first call; the second engine received exactly one `load` with C's URL and `startsMuted` false.

### AC-11d Entering is not a single-channel tune (tvOS)
Given AC-11a's entry with C picked from group G
When `multiView.root` appears
Then `zapBar.root` does not exist, 0008's channel-change event has not fired, and the current group is G (0008/AC-15a).

### AC-12 Layout on screen (tvOS)
Given multi-view with 2, 3 and 4 tiles
When the grid is rendered
Then the frame of each `multiView.tile.<n>` equals AC-2's 1920 by 1080 frame for that count and position within 1 pt; adding or removing a tile changes the frames without any `load`, `pause` or `stop` on the tiles that stay.

### AC-12a Tile label (tvOS)
Given a tile showing channel number 104 named "Sport One"
When the tile is rendered
Then `multiView.tile.<n>.label` shows "104" and "Sport One" and no programme text; the tile's accessibility label is "104, Sport One, sound on" when its `multiView.tile.<n>.audio` value is "on" and "104, Sport One, muted" when it is "off"; a channel without a number shows the name only.

### AC-13 Focus movement (tvOS)
Given multi-view in the grid with focus on a tile
When the user swipes
Then with 2 tiles, right from 1 goes to 2 and left from 2 to 1; with 4 tiles, focus moves to the neighbour in the swiped direction in the 2 by 2 grid; with 3 tiles, down from 1 or 2 goes to 3, up from 3 goes to 1, right from 1 goes to 2 and left from 2 to 1; every other swipe leaves focus where it is. No swipe calls `load` on any engine or leaves multi-view.

### AC-14 Audio follows focus (tvOS)
Given multi-view with focus on tile j
When focus moves to tile k
Then at once tile j's fake engine has recorded `setMuted(true)` and, after it, tile k's has recorded `setMuted(false)`; `multiView.tile.<k>.audio` has value "on" unless tile k is failed, and every other tile's has "off"; at no point do two fake engines report themselves unmuted.

### AC-15 Select opens the overlay in pick mode (tvOS)
Given multi-view with n tiles, focus on tile k showing channel K, and current group G
When the user presses select
Then `overlay.root` is presented over the grid with `overlay.pickTarget` reading "Changing tile k of n", `overlay.watch` labelled "Show in tile k", and no `overlay.search`; G is selected and focus is on K's row when K is in G, else on G's first row (0007/AC-2 with K in place of the playing channel); each row whose channel is in a tile m has `overlay.channel.<rowKey>.tile` reading "TILE m"; no engine receives any call and `multiView.tile.<k>.audio` is unchanged.

### AC-16 Pick replaces the tile's channel (tvOS)
Given AC-15's pick mode for tile k and focus on channel C's row, or on `overlay.watch` for C, with C in group H
When the user presses select
Then `overlay.root` is dismissed, the current group becomes H (as 0007/AC-22), and: with C in no tile, tile k's engine received exactly one `load` with C's URL and `startsMuted` false, the other engines received no call, `multiView.tile.<k>.label` shows C and focus is on tile k; with C in tile m different from k, no engine received `load`, the grid is shown even if tile k was swapped, and focus is on tile m with AC-14's audio switch; with C in tile k, no engine received any call and focus is on tile k.

### AC-17 Add as a new tile from pick mode (tvOS)
Given AC-15's pick mode with n tiles, focus on channel C, and the session `capacity`
When the panel is rendered, and then the user activates `overlay.multiView`
Then with n under `capacity` and C in no tile, `overlay.multiView` exists after `overlay.favorite` labelled "Add as new tile"; activating it dismisses the overlay, leaves the swapped state if it was shown, adds `multiView.tile.<n+1>` for C at AC-2's frames for n+1, gives it focus and the audio per AC-14, and the existing engines receive only `setMuted`; with n at or above `capacity`, or C in a tile, `overlay.multiView` does not exist.

### AC-18 Menu in pick mode (tvOS)
Given AC-15's pick mode for tile k, opened with current group G
When the user presses Menu
Then `overlay.root` is dismissed, focus is on tile k, no engine receives any call, the current group is G, and `multiView.root` still exists.

### AC-19a Tile actions for a playing tile (tvOS)
Given multi-view with focus on tile k whose `failure` is nil
When the user long-presses select
Then `multiView.actions` exists anchored on tile k and lists `multiView.action.fullScreen`, `multiView.action.changeChannel` and `multiView.action.remove` in that order, with focus on `multiView.action.fullScreen`, and `player.panel` (0018) does not exist.

### AC-19b Tile actions for a failed tile (tvOS)
Given multi-view with focus on tile k whose `failure` is not nil
When the user long-presses select
Then `multiView.actions` lists `multiView.action.retry`, `multiView.action.fullScreen`, `multiView.action.changeChannel` and `multiView.action.remove` in that order, with focus on `multiView.action.retry`.

### AC-19c Change channel from the actions (tvOS)
Given `multiView.actions` open on tile k
When the user activates `multiView.action.changeChannel`
Then `multiView.actions` is dismissed and AC-15's pick mode for tile k is shown.

### AC-19d Menu closes the actions (tvOS)
Given `multiView.actions` open on tile k
When the user presses Menu
Then `multiView.actions` is dismissed, focus is on tile k, `multiView.root` still exists and no engine receives any call.

### AC-19e Actions without a long press
Given VoiceOver on and focus on tile k (tvOS), or tile k selected (macOS)
When the tile's accessibility custom actions are listed, and on macOS the user presses Command-Delete
Then on tvOS the custom actions are "Full screen", "Change channel", "Remove from multi-view" and, for a failed tile, "Try again", each with AC-19a to AC-19c's outcome; on macOS Command-Delete removes tile k as AC-43.

### AC-20 One tile full screen (tvOS)
Given multi-view in the grid with focus on tile k
When the user presses play/pause (test a) or activates `multiView.action.fullScreen` (test b)
Then `multiView.tile.<k>` has frame (0, 0, 1920, 1080), no other `multiView.tile.<n>` exists as a focus target, no engine receives `load`, `pause` or `stop`, and the audio values are unchanged.

### AC-20a Swap badge (tvOS)
Given AC-20 has just swapped tile k of n
When 5 seconds pass on the injected clock
Then `multiView.swapBadge` read "Multi-view · tile k of n" before the deadline and does not exist after it.

### AC-21 Back to the grid (tvOS)
Given AC-20's swapped state for tile k
When the user presses Menu or play/pause, and separately select
Then Menu or play/pause restore AC-12's frames with focus on tile k and no engine call; select opens AC-15's pick mode for tile k, and after the overlay is dismissed by Menu or by a pick that replaces tile k's channel the swapped state is still shown; AC-17, and a pick of a channel already in another tile (AC-16), return to the grid.

### AC-22 Remove a tile (tvOS)
Given multi-view with n of 3 or more tiles and focus on tile k
When the user activates `multiView.action.remove`
Then tile k's engine received `stop()` once, the remaining tiles are renumbered in order at AC-2's frames for n minus 1, focus is on the tile now numbered k, or k minus 1 when k was the last, and that tile's audio follows AC-14; the other engines received no call except that `setMuted(false)`.

### AC-23 Removing the second-last tile ends multi-view (tvOS)
Given multi-view with 2 tiles and focus on tile k
When the user activates `multiView.action.remove`
Then tile k's engine received `stop()` once, `multiView.root` does not exist, `shell.player` plays the other tile's channel on that tile's engine instance with no `load`, that engine received `setMuted(false)`, `setAppliesDisplayCriteria(true)` and `setMaximumVideoHeight(nil)`, and 0008's channel-change event fired once for that channel (the zap bar shows per 0008/AC-1 and 0015/AC-8 stores it).

### AC-24 Menu leaves multi-view (tvOS)
Given multi-view in the grid with no overlay, `multiView.actions` or swapped state shown, and focus on tile k
When the user presses Menu
Then every engine except tile k's received `stop()` once, `multiView.root` does not exist, `shell.player` plays tile k's channel on tile k's engine instance with no `load`, that engine received `setAppliesDisplayCriteria(true)` and `setMaximumVideoHeight(nil)`, 0008's channel-change event fired once for tile k's channel, and `shell.tabBar` does not exist (Menu is consumed; the next Menu follows 0015/AC-3).

### AC-25 Single-channel inputs are inactive (tvOS)
Given `multiView.root` exists
When the user types digits on a hardware keyboard, or, with 2 tiles, swipes up or down
Then `zapBar.entry` (0008/AC-10) and `zapBar.root` (0008/AC-1, AC-9) do not appear and no engine receives `load`.

### AC-25a Tile changes are not channel changes (tvOS)
Given `multiView.root` exists
When a tile's channel is replaced (AC-16) or a tile is added (AC-17)
Then `zapBar.root` does not appear and 0008's channel-change event does not fire.

### AC-26 Buffering tile
Given multi-view on tvOS or macOS
When tile k's engine reports `.loading` or `.buffering(_)`, and then `.playing`; and separately `.paused` or `.idle`
Then `multiView.tile.<k>.buffering` exists while the state is `.loading` or `.buffering` and is gone once `.playing` is reported; `.paused` and `.idle` show neither `.buffering` nor `.failed`; no other tile shows it and no other engine receives a call.

### AC-27 Failed tile
Given multi-view on tvOS or macOS with tile k on source S and m other tiles on S whose engines are `.playing`
When tile k's engine reports `.failed(e)`
Then `multiView.tile.<k>.failed` exists, `multiView.tile.<k>.failed.title` and `.failed.body` equal AC-10's text for (e, S, m, this device), `multiView.tile.<k>.label` is unchanged, the tile can still take focus (tvOS) or selection (macOS), `multiView.tile.<k>.audio` reads "off", and tile k's engine receives no further call until a retry, replace or remove; `.failed` clears only through a retry (AC-28) or a replace (AC-16). While 0017 reconnects after a drop the tile reports `.buffering(ReconnectAttempt)` and shows AC-26's ring, not `.failed`.

### AC-28 Retry a failed tile
Given AC-27's failed tile k
When the user activates `multiView.action.retry` (tvOS) or `multiView.tile.<k>.retry` (macOS)
Then tile k's engine received exactly one `load` with its channel's URL, `startsMuted` true unless tile k has focus or selection, and `multiView.tile.<k>.failed` is gone once the engine reports `.loading`.

### AC-29 The device refuses another decoder
Given multi-view with 4 tiles, capacity 4, and tile 4's engine reporting `.failed(.decoderBusy)`
When pick mode is opened on any tile (tvOS) or the row context menu is opened (macOS), before and after tile 4 is removed
Then `multiView.tile.4.failed.title` reads AC-10's decoder text; the session capacity is 3, so with 4 tiles and again with 3 after the removal, `overlay.multiView` does not exist (tvOS) and `multiView.add` is disabled (macOS, AC-37a); after leaving and entering multi-view again the cap is AC-1's value.

### AC-30 Lower caps
Given an injected `MultiViewDevice.appleTV(machine: "AppleTV5,3")` on tvOS, and separately `.mac(appleSilicon: false)` on macOS, with multi-view showing 2 tiles
When pick mode is opened (tvOS) or the row context menu is opened (macOS)
Then `overlay.multiView` does not exist, and `multiView.add` is disabled with the title "Multi-view is full".

### AC-31 Display mode is left alone (tvOS)
Given an integration test with fake engines, a full-screen channel on engine E, then multi-view entered, 4 `replace` or `add` actions, and an exit with survivor T
When the fake engines' call logs are read
Then E received `setAppliesDisplayCriteria(false)` at entry; every load issued by multi-view had `appliesDisplayCriteria` false; no engine received `setAppliesDisplayCriteria(true)` before the exit, and T received it once at the exit.

### AC-32 HLS tiles are capped at 1080
Given multi-view on tvOS or macOS
When the model loads any tile, and when multi-view ends with survivor T
Then each load records `PlaybackOptions.maximumVideoHeight` equal to 1080; tile 1's engine at entry receives `setMaximumVideoHeight(1080)` instead of a reload; T receives `setMaximumVideoHeight(nil)` at the end, and the cap stays on a swapped tile.

### AC-33 Background and foreground
Given multi-view with 4 tiles playing, focus on tile 2, and `PlaybackLifecycle` (0017) observing every tile engine with an injected scene-phase stream
When the phase becomes `.background` and then `.active`
Then on tvOS each engine received `pause()` once and later `play()` once, no engine received `setMuted`, and tile 2 is the only tile with audio "on" after resume; on macOS no engine received `pause()` (0017's lifecycle never pauses on macOS).

### AC-34 A tile's channel leaves the catalogue
Given multi-view with n tiles and a catalogue refresh after which tile k's `RowKey` no longer resolves (0013/AC-15)
When the catalogue change is delivered
Then tile k is removed as in AC-22, or as in AC-23 when one tile is left; when no tile's `RowKey` resolves, every engine received `stop()`, `multiView.root` does not exist, and the shell follows 0015/AC-11 or 0015/AC-2b (tvOS) or 0010/AC-23 (macOS).

### AC-35 Four tiles hold on Apple TV
Given an Apple TV 4K of each generation (`AppleTV6,2`, `AppleTV11,1`, `AppleTV14,1`) on wired Ethernet, and four tiles from the fixture server: two MPEG-TS 1080p50 H.264 on the demuxer route and two HLS 1080p on the system route
When multi-view runs for 30 minutes with 20 focus moves
Then every tile stays `.playing` with no `.buffering` or `.failed`, the app is not terminated, and for each focus move the time from the remote event to the new tile's first unmuted audio buffer, read from the engines' signpost log, is at most 500 ms. A generation that fails gets the largest tile count that passes written into AC-1 by a spec amendment.

### AC-36 Four tiles hold on Mac
Given a Mac with an M1 chip and AC-35's four fixtures
When multi-view runs for 30 minutes with 20 selection changes
Then AC-35's outcome holds, measured from the click to the first unmuted audio buffer.

### AC-37 Entry from the row context menu (macOS)
Given 0010's regular-width layout with channel P playing inline on engine E (`.playing` or `.buffering`) and a row for channel R
When the user opens the context menu on `browse.row.<rowKey>` for R and chooses `multiView.add` ("Add to Multi-view")
Then with R different from P, `multiView.root` replaces `browse.player` and `browse.panel`, `browse.sidebar` does not exist and `browse.toggleSidebar` does, `multiView.tile.1` shows P on engine E with no `load`, `pause` or `stop` and AC-11c's calls, `multiView.tile.2` shows R and is selected and audible, and `multiView.count` reads "2 of 4"; when nothing plays, E is in another state, or R is P, `multiView.add` is not in the menu.

### AC-37a Context menu inside multi-view (macOS)
Given multi-view with n tiles in the grid or swapped
When the user opens the context menu on a row for channel C
Then with n under `capacity` and C in no tile, `multiView.add` is enabled and choosing it applies AC-4, shows the grid, and selects the new tile; with n at or above `capacity`, `multiView.add` is disabled with the title "Multi-view is full"; with C in a tile it is absent.

### AC-38 Keyboard entry (macOS)
Given 0010's layout or multi-view, and the keyboard focus ring (0010/AC-14) on the row for channel R
When the user presses Command-Shift-M
Then the result equals choosing `multiView.add` on R per AC-37 or AC-37a; with no focused row, or when `multiView.add` would be absent or disabled for R, nothing changes and the View menu item "Add to Multi-view" is disabled.

### AC-39 Layout in the window (macOS)
Given multi-view with 2, 3 and 4 tiles in a window whose tile area (`multiView.tileArea`, below `multiView.toolbar`) has size S, in a normal window and in macOS full screen
When the window is resized and the layout settles
Then the frame of each `multiView.tile.<n>` equals `MultiViewLayout.frames(count: n, in: S, margin: 16, gap: 12)` within 1 pt, and the resize makes no engine call.

### AC-40a Selection by click or key (macOS)
Given multi-view with tile j selected
When the user clicks tile k, or presses Command-k for k from 1 to the tile count
Then tile k alone has the `.isSelected` trait; when a tile was swapped, the grid is shown again (AC-9b).

### AC-40b Selection moves the audio (macOS)
Given AC-40a's selection change from j to k
When the call logs are read
Then AC-14's mute order and audio values hold with selection in place of focus.

### AC-40c List and out-of-range keys (macOS)
Given multi-view with tile k selected
When the list shows the group containing tile k's channel, and separately the user presses Command with a number above the tile count
Then the row of tile k's channel has the `.isSelected` trait; when tile k's channel is not in the shown group, no row is selected and the group is unchanged; the out-of-range key changes nothing.

### AC-41 The list picks for the selected tile (macOS)
Given multi-view with tile k selected
When the user clicks, or presses Return on, the row for channel C
Then the result equals AC-16 for tile k: one `load` on tile k's engine when C is in no tile, tile m selected with no `load` when C is in tile m, nothing when C is in tile k; `browse.player` does not appear.

### AC-42 One tile at full size (macOS)
Given multi-view with tile k selected
When the user double-clicks tile k, then double-clicks it again, and separately presses Escape while swapped
Then after the first double-click tile k's frame equals `MultiViewLayout.frames(count: 1, in: S, margin: 16, gap: 12)[0]`, the other tiles are hidden with no engine call, and `multiView.count` reads "Tile k of n"; the second double-click or Escape restores AC-39's frames with no engine call; Escape in the grid changes nothing.

### AC-43 Remove a tile (macOS)
Given multi-view with tile k selected, or the pointer over unselected tile k
When the user activates `multiView.tile.<k>.remove` (44 by 44 pt hit area) or "Remove" in the tile's context menu
Then with 3 or more tiles AC-22's outcome holds with selection in place of focus when k is selected, and when k is not selected the selection stays on the same tile and no `setMuted` is sent; with 2 tiles AC-23's engine calls hold, `browse.player` shows the survivor on its engine instance with `browse.panel` back, the sidebar is shown or hidden as it was before entry, and the survivor's row is selected.

### AC-44 Exit (macOS)
Given multi-view with tile k selected
When the user activates `multiView.exit`
Then every engine except tile k's received `stop()` once, tile k's engine received `setMaximumVideoHeight(nil)` and no `load`, `multiView.root` does not exist, and the window returns to 0010's layout as in AC-43's two-tile case with `browse.player` on tile k's engine instance.

### AC-45 Now Playing follows the audible tile (macOS)
Given multi-view and 0018/AC-26a (Now Playing) publishing to an injected Now Playing sink
When the selection moves to tile k
Then at once the sink holds 0018/AC-26a's fields for tile k's channel (title its programme title, artist "<number> <name>") and no field carries a URL; a media play/pause key press makes no engine call.

### AC-46 Not on iPhone or iPad
Given the app on iOS, and on iPadOS with a hardware keyboard
When the user opens the context menu on any `browse.row.<rowKey>` and presses Command-Shift-M
Then `multiView.add` is not in the menu, the key press changes nothing, and no `multiView.` identifier exists.

### AC-47 Inputs in multi-view (macOS)
Given multi-view with tile k selected and focus outside a text field
When the user presses Space or the media play/pause key, Up or Down, and `multiView.count` is read
Then Space and the media key make no engine call; Up and Down move the list's keyboard focus as 0010/AC-14 without a `load`; `multiView.count` reads "<tile count> of <the larger of capacity and tile count>" in the grid, so a lowered cap never shows "4 of 3" (AC-42 gives the swapped text).

### AC-48 Minimum window width (macOS)
Given a window narrower than 1024 pt
When multi-view is entered, and then the user tries to make the window narrower than 1024 pt
Then the window widens to 1024 pt on entry so that 0010's list stays visible (0010/AC-1 hides it below 672 pt), it cannot be resized below 1024 pt while `multiView.root` exists, and after exit 0010's own minimum applies again; when the window's screen has less than 1024 pt of usable width, or the window is in 0010's compact layout, `multiView.add` is absent and Command-Shift-M does nothing.

## Dropped

- AC-19 (tile actions): split into AC-19a to AC-19d; its When did not trigger the change-channel and Menu assertions.
- AC-40 (selection moves the audio, macOS): split into AC-40a to AC-40c; it held four assertions.

## Edge cases and failure modes

- Offline: a tile added while offline fails at once with `.offline` (0017) and shows 0018's offline text (AC-10, AC-27); offline mid-session each tile reconnects on its own 0017 schedule and fails on its own; there is no session-wide error.
- Provider connection cap: many Xtream accounts allow one or two streams. The second tile from the same account then fails with 503 or 509, or with 403 on some panels; AC-10 says so in plain words and, for 403, also points at the login. Tiles from different sources do not count against each other. On a one-stream account the new tile can evict the older one, whose reconnect would then evict the new one. 0017 ends such a reconnect at once (see Required of other specs), so the evicted tile shows AC-10's text instead of looping.
- Slow source: a tile that never gets a first frame times out per 0017 and shows AC-27; the other tiles are not affected.
- Huge sources: pick mode is 0007's overlay and meets 0007/AC-16 on 20 000 channels; the Mac list is 0010's and meets 0010/AC-22. No criterion here scales with channel count.
- Malformed data: a tile whose URL is unsupported or whose body is not a stream fails per 0017/AC-2 and AC-26 and shows AC-27.
- Credential not yet synced from iCloud Keychain: that source contributes no channels (0004/AC-10), so it cannot be picked. A source that loses its credential mid-session drops out of the catalogue; its tiles are removed by AC-34 and no `.unauthorized` text is shown for it.
- A refresh that re-keys a tile's channel (0013's `RowKey` includes the position) counts as the channel leaving the catalogue, and AC-34 removes the tile. Matching by source and channel id instead is an open question.
- First launch with an empty store: nothing plays, so AC-11 and AC-37 never offer entry.
- tvOS focus and remote: every tile, row and action is reachable by swipe; select, long press, play/pause and Menu are the only buttons used (AC-13 to AC-24).
- Same channel twice: never; AC-4, AC-6 and AC-17 refuse a channel already in a tile and move focus to that tile instead.
- HDR or 4K tiles play in whatever display mode the TV was in at entry; a 50 Hz tile in a 60 Hz mode judders until it is the survivor. AC-31 accepts that over a mode switch on every focus move.
- Audio-only stream in a tile: drawn per the Not drawn list; audio follows focus as usual.
- A failed tile with focus leaves the room silent. AC-27 accepts that so that sound always matches the highlighted tile.
- MPEG-2 channels fail in a tile as in single playback (`.decodeFailed(.mpeg2)`, 0017).
- Entitlement lapses mid-session: the paywall replaces the shell at the next root evaluation (ADR-0006, 0015 edge case); multi-view ends as AC-34's last case, every engine stopped.
- App terminated in multi-view: nothing is saved; the next launch follows 0015/AC-2a with the last channel stored before entry or at the last exit.
- `streamURL` and the URL 0017 builds are never shown, logged, or set on a label, identifier or Now Playing field (ADR-0003); `MultiViewCommand` carries `RowKey` only.
- Reduce Motion: tiles change frames and the swap happens without animation.
- VoiceOver: each tile is one element with AC-12a's label and AC-19e's custom actions; the hint and swap badge are announced once when they appear.
- macOS window minimised or hidden: playback continues (AC-33); the selected tile stays audible.

## Test plan

Core criteria are swift-testing tests in AntennaCore over value types with fixed UUIDs. UI tests run on the tvOS simulator and on macOS with one fake engine per tile injected under `-antenna.uiTest`, a fixture catalogue, an injected clock and an injected `MultiViewDevice`. Integration tests drive `MultiViewModel` with fakes, a fake Now Playing sink and an injected scene-phase stream. Device criteria use the 0017 fixture server and the engines' signpost log. Identifiers: `multiView.root`, `multiView.tile.<n>`, `multiView.tile.<n>.label`, `multiView.tile.<n>.audio`, `multiView.tile.<n>.buffering`, `multiView.tile.<n>.failed`, `multiView.tile.<n>.failed.title`, `multiView.tile.<n>.failed.body`, `multiView.tile.<n>.retry`, `multiView.tile.<n>.remove`, `multiView.hint`, `multiView.actions`, `multiView.action.fullScreen`, `multiView.action.changeChannel`, `multiView.action.retry`, `multiView.action.remove`, `multiView.swapBadge`, `multiView.toolbar`, `multiView.tileArea`, `multiView.count`, `multiView.exit`, `multiView.add`; overlay additions `overlay.multiView`, `overlay.pickTarget`, `overlay.channel.<rowKey>.tile`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core (parameterised over n and k) | TBD |
| AC-8 | core | TBD |
| AC-9 | core | TBD |
| AC-9a | core | TBD |
| AC-9b | core | TBD |
| AC-9c | core | TBD |
| AC-10 | core | TBD |
| AC-11 | ui (tvOS, fake engine states) | TBD |
| AC-11a | ui (tvOS) | TBD |
| AC-11b | ui (tvOS, injected clock) | TBD |
| AC-11c | ui (tvOS, fake engine logs) | TBD |
| AC-11d | ui (tvOS) | TBD |
| AC-12 | ui (tvOS, frames) | TBD |
| AC-12a | ui (tvOS) | TBD |
| AC-13 | ui (tvOS, per count) | TBD |
| AC-14 | ui (tvOS, fake engine logs) | TBD |
| AC-15 | ui (tvOS) | TBD |
| AC-16 | ui (tvOS, three Givens) | TBD |
| AC-17 | ui (tvOS, grid and swapped) | TBD |
| AC-18 | ui (tvOS) | TBD |
| AC-19a | ui (tvOS) | TBD |
| AC-19b | ui (tvOS, fake engine failed) | TBD |
| AC-19c | ui (tvOS) | TBD |
| AC-19d | ui (tvOS) | TBD |
| AC-19e | ui (tvOS custom actions, macOS key) | TBD |
| AC-20 | ui (tvOS, tests a and b) | TBD |
| AC-20a | ui (tvOS, injected clock) | TBD |
| AC-21 | ui (tvOS) | TBD |
| AC-22 | ui (tvOS) | TBD |
| AC-23 | ui (tvOS) | TBD |
| AC-24 | ui (tvOS) | TBD |
| AC-25 | ui (tvOS) | TBD |
| AC-25a | ui (tvOS) | TBD |
| AC-26 | ui (tvOS and macOS) | TBD |
| AC-27 | ui (tvOS and macOS) | TBD |
| AC-28 | ui (tvOS and macOS) | TBD |
| AC-29 | ui (tvOS and macOS, injected device) | TBD |
| AC-30 | ui (tvOS and macOS, injected device) | TBD |
| AC-31 | integration (MultiViewModel, fake engine logs) | TBD |
| AC-32 | integration (fake engine options) | TBD |
| AC-33 | integration (PlaybackLifecycle, fake engines, per platform) | TBD |
| AC-34 | integration (MultiViewModel, catalogue change) | TBD |
| AC-35 | device | manual on each Apple TV 4K generation with the fixture server and signpost log |
| AC-36 | device | manual on an M1 Mac with the fixture server and signpost log |
| AC-37 | ui (macOS) | TBD |
| AC-37a | ui (macOS) | TBD |
| AC-38 | ui (macOS) | TBD |
| AC-39 | ui (macOS, window resize and full screen) | TBD |
| AC-40a | ui (macOS) | TBD |
| AC-40b | ui (macOS, fake engine logs) | TBD |
| AC-40c | ui (macOS) | TBD |
| AC-41 | ui (macOS) | TBD |
| AC-42 | ui (macOS) | TBD |
| AC-43 | ui (macOS) | TBD |
| AC-44 | ui (macOS) | TBD |
| AC-45 | integration (fake Now Playing sink) | TBD |
| AC-46 | ui (iOS and iPadOS) | TBD |
| AC-47 | ui (macOS) | TBD |
| AC-48 | ui (macOS, window frame) | TBD |

## Required of other specs

- 0017 (playback engine):
  - `func setMuted(_ muted: Bool) async` on `PlaybackEngine`, and `PlaybackOptions.startsMuted` (default false). A muted engine keeps decoding and becomes audible within 500 ms of `setMuted(false)`.
  - `PlaybackOptions.maximumVideoHeight: Int?` (default nil) and `func setMaximumVideoHeight(_ height: Int?) async`. The system route maps both to `AVPlayerItem.preferredMaximumResolution`; the demuxer route ignores them because a TS stream has one rendition.
  - `PlaybackOptions.appliesDisplayCriteria` (default true) and `func setAppliesDisplayCriteria(_ applies: Bool) async`. While false the engine never writes `AVDisplayManager.preferredDisplayCriteria` and does not clear it; set to true with presentation known, it applies 0017/AC-43 (display criteria) at once.
  - `PlaybackError.decoderBusy`, raised on the system route for `AVError.decoderTemporarilyUnavailable` and on the demuxer route when a VideoToolbox decompression session cannot be created while another is active; `RetryPolicy` does not retry it.
  - `PlaybackLifecycle` observes several engines: background pauses each one it would pause alone and foreground resumes each one it paused (AC-33).
  - A signpost per engine at the first unmuted audio buffer after `setMuted(false)`, for AC-35 and AC-36, carrying the tile id only, never a channel name or URL (ADR-0003).
  - A drop reconnect that gets 503 or 509 while the screen reports another engine on the same source as playing ends at once in `.failed(.serverBusy)`, so two tiles do not evict each other in a loop.
  - The edge case "Two `RoutedEngine`s in one process share nothing" holds for four.
- 0007 (overlay), amendment to AC-14 and AC-9: the panel gains `overlay.multiView` after `overlay.favorite` (AC-11, AC-17), so 0007/AC-14's focus order becomes Watch, favorite, multi-view. A pick mode (AC-15 to AC-18): `overlay.pickTarget`, `overlay.watch` relabelled "Show in tile k", `overlay.search` absent, `overlay.channel.<rowKey>.tile` badges, initial focus on the tile's channel, and select loads into the tile's engine instead of 0007/AC-9's; the zap bar does not show. `Main.dc.html` gains the third button (see Not drawn).
- 0008 (zap bar), amendment to AC-1, AC-9 and AC-10: none of them fires while `multiView.root` exists (AC-25). Leaving multi-view fires the channel-change event once for the survivor (AC-23, AC-24).
- 0010 (Mac browse), amendment to AC-6, AC-14 and AC-17: row context menu item `multiView.add` and Command-Shift-M (AC-37, AC-38); in multi-view `multiView.root` replaces `browse.player` and `browse.panel`, the sidebar collapses on entry and is restored on exit, a list click or Return targets the selected tile instead of 0010/AC-6's inline playback (AC-41), Space does nothing and Escape only undoes the swap (AC-42, AC-47), `browse.player.fullscreen` is absent, and the window minimum is 1024 pt (AC-48).
- 0015 (tvOS shell), amendment to AC-3 and its "same engine instance" wording: `shell.player` hosts `multiView.root`; multi-view consumes Menu in the grid (AC-24); on exit the shell's engine instance becomes the survivor's, so "the same engine instance" in 0015 means the survivor's from then on; content tabs are not reachable from inside multi-view, so 0015/AC-5a never applies to tile engines.
- 0018 (player controls): its failure table covers every `PlaybackError` case 0017 defines, including `.serverBusy`, `.serverError(_)`, `.decoderBusy` and `.offline` (the draft table names `.httpStatus`, `.credentialMissing`, `.unsupportedCodec` and `.malformedStream`, which 0017 lacks); tiles use 0017's reconnect policy only, never 0018/AC-19a's schedule; in multi-view the media play/pause key and Now Playing's remote pause make no engine call; a long press in the grid opens `multiView.actions`, not `player.panel`; tiles draw `multiView.tile.<n>.buffering` and `.failed` instead of `player.buffering` and `player.error`; `PlaybackFailureText.describe` is reused by AC-10; Now Playing follows the selected tile on Mac (AC-45, which 0018/AC-26c should cite); `player.mute` and `player.volume` are not shown in multi-view.
- 0019 (timeshift): tiles have no timeshift buffer; the swapped tile shows no `player.transport`.
- 0028 (session restore): a multi-view set is not restored; the stored last channel is the survivor of the last exit.
- Design README: `multiView.` added to DR-11, section 4 rows for the eight boards, and a "Multi-view" entry in section 2 for Apple TV and for iPad and Mac. Done in this PR.

## Open questions

Each line is a decision made for this draft; overturn any at review.

- Cap: four tiles, two on Apple TV HD and Intel Macs, with the runtime `.decoderBusy` fallback (AC-1, AC-9, AC-29). TiviMate stops at four; Channels DVR users run nine on a Shield. If tvOS 26 no longer runs on Apple TV HD, its table entry is dead code and goes.
- After `.decoderBusy` the session cap never rises, even though the failure text suggests a lower-resolution channel (AC-9). Letting it rise again after a successful load would invite a second failure.
- Xtream's auth response carries `max_connections`. A later change could refuse "Add as new tile" up front when the account's limit is reached instead of waiting for the 503.
- A new tile takes focus and sound (AC-3, AC-4, AC-17). The alternative keeps the sound on the tile the user was watching.
- Menu in the grid leaves multi-view without asking and keeps the focused tile (AC-24). Rebuilding a four-tile set takes about a dozen presses; a confirmation, or a "Resume multi-view" entry in the overlay for the session, would protect it.
- Entry is refused while the playing channel is paused (AC-11), because 0017 closes the demuxer connection on a live pause and tile 1 would sit frozen.
- Sound follows focus strictly, so a focused failed tile is silent (AC-27).
- While one tile is full screen the others keep playing muted (AC-20), which keeps the return instant but holds every connection open. Pausing them would free connections on single-stream accounts.
- HLS tiles are capped at 1080 lines while they are tiles (AC-32); MPEG-TS cannot be capped.
- The display mode stays as it was at entry (AC-31).
- iPad: an M-series iPad can decode four streams and the Mac interaction would carry over. Undecided whether a later version includes it, and whether compact width (Split View) disables it.
- One fixed layout per tile count. The three-tile layout puts the third tile centred below the first two instead of one large tile and two small.
- Mac leaves multi-view only through `multiView.exit` and removing tiles; Escape only undoes the swap (AC-42), so a stray Escape never drops three channels.
- Command-Shift-M for "Add to Multi-view" on Mac. Command-M is Minimize, so the shift variant is the nearest free key.
- Tile labels stay visible all the time on tvOS. Fading them after a few seconds would show more picture; the speaker glyph would then need another home.
- A tile whose channel is re-keyed by a refresh is removed (edge cases). Matching tiles by source and channel id, ignoring position, would keep it.
- Size: about sixty criteria over two platforms. The implementing PR should ship as a stack: core types, then tvOS, then macOS.
- AC-10's strings live in AntennaCore like 0018's `PlaybackFailureText`; localisation follows whatever 0018 decides for that type.
- AC-35 runs on wired Ethernet. Most Apple TVs are on Wi-Fi; a Wi-Fi run belongs in the device checklist once there are numbers from the wired run.
