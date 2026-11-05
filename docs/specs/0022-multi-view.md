# 0022. Multi-view: up to four live tiles on Apple TV and Mac

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0004, 0005, 0006
- Builds on specs: 0007, 0008, 0010, 0013, 0015, 0017, 0018
- Needs from other specs: 0017 refinement for muted start and moving sound without a reload, a 1080p quality cap, leaving the TV's display mode alone, the "no decoder free" reason, and no retry of 503/509 while another tile on the same account plays.
- Platforms: tvOS, macOS
- User stories: US-15

## Summary

This is for sports and news viewers who want to keep an eye on several live channels at once. Once it ships, an Apple TV or Mac shows up to four channels side by side, the sound comes from the one the user has highlighted, and each tile can be changed, enlarged, retried or removed without disturbing the others. Leaving multi-view keeps the highlighted channel playing on its own. It is not on iPhone or iPad, it has one fixed layout per tile count, and tiles are live only: no pausing, rewinding or catch-up inside a tile.

## Design

Boards: `docs/design/boards/TV-MultiView.dc.html`, `TV-MultiView-Two.dc.html`, `TV-MultiView-Failed.dc.html`, `TV-MultiView-Actions.dc.html`, `TV-MultiView-Swap.dc.html`, `TV-MultiView-Pick.dc.html`, `iPad-MultiView.dc.html`, `iPad-MultiView-Failed.dc.html`. The two `iPad-` boards draw the Mac window in the shared iPad and Mac frame; they do not put iPadOS in scope.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13, DR-14.
Not drawn: the overlay's "Add to multi-view" button over full-screen live; the "Try again" row in tile actions; the Mac right-click item; the Mac enlarged state; the Mac loading ring; a radio-stream tile.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Sports and news viewers want two to four live channels on one screen with the sound from the one they are watching. TiviMate users praise its multi-view and keep paying for it, and Channels DVR users push it to nine streams. Antenna plays one channel at a time everywhere.

## Scope

In:
- Apple TV: start multi-view from the channel overlay (0007); two, three and four tiles; move between tiles with the remote; sound follows the highlighted tile; change a tile's channel through the overlay; add a tile; a per-tile actions menu (full screen, change channel, try again, remove); one tile full screen and back; Menu to leave.
- Mac: start from a channel's right-click menu or Command-Shift-M; the same layouts in the main window with the sidebar folded away; click or Command-1 to 4 to choose the audible tile; the channel list fills the chosen tile; double-click to enlarge; remove and exit buttons; a minimum window width while in multi-view.
- A limit of four tiles, two on Apple TV HD and Intel Macs, lowered for the session if the device cannot decode another stream.
- Per-tile loading and failure states, with plain words for a provider that refuses another connection and a device that cannot decode another stream.
- The TV's display mode left alone and HLS (Apple's streaming format) tiles held to 1080p (full HD) while tiles play.
- Tiles reconnect only through 0017; multi-view adds no retry of its own.

Out (explicitly):
- iPhone: tiles too small to read, battery and heat, mobile data.
- iPad, for now (see Open questions).
- Other layouts, more than four tiles, resizing or dragging tiles.
- Restoring a multi-view set after relaunch.
- Pause, rewind, catch-up or Start over in a tile.
- Per-tile audio and subtitle pickers, AirPlay and Picture in Picture while in multi-view.
- Starting multi-view from the guide or search.
- Measuring bandwidth or lowering quality beyond the 1080 cap.
- Pausing a single tile.
- A separate purchase: multi-view is part of the one unlock (ADR-0006).

## User flow

Apple TV:
1. A channel plays full screen. The user opens the overlay, highlights another channel and chooses "Add to multi-view".
2. The picture splits into two tiles: the old channel on the left, the new one on the right with focus and sound. A hint names the buttons for five seconds.
3. Swiping moves between tiles and the sound follows.
4. Select on a tile opens the overlay to pick its channel, or to add a new tile.
5. Holding select opens the tile's actions. Play/pause shows the tile full screen while the others keep playing out of sight.
6. Menu leaves multi-view. The highlighted channel keeps playing full screen; the others stop.

Mac:
1. The user right-clicks a channel and chooses "Add to Multi-view", or presses Command-Shift-M on it.
2. The sidebar folds away and two tiles appear; the new one is selected and audible.
3. Clicking a tile or Command-1 to 4 selects it and moves the sound. Clicking a channel in the list shows it in the selected tile.
4. Double-click enlarges a tile; double-click or Escape goes back.
5. A tile's close button removes it. "Exit multi-view" keeps the selected channel in the normal player.

## Acceptance criteria

### AC-11 Start multi-view on Apple TV
Given a channel playing full screen on Apple TV and the overlay open on a different channel
When the user chooses "Add to multi-view"
Then the screen splits into two tiles, the playing channel on the left continuing without a reload and the new channel on the right with focus and sound; each tile shows its number and name; a hint shows briefly; this does not count as a channel change (no zap bar); while tiles play the TV's frame rate and HDR mode stay as they were and HLS tiles stay at 1080p (full HD) or below; the option is not offered for the playing channel itself or when the channel is paused, loading or failed.

### AC-37 Start multi-view on a Mac
Given a channel playing in the Mac window and another channel in the list
When the user right-clicks that channel and chooses "Add to Multi-view", or highlights it and presses Command-Shift-M
Then the sidebar folds away, the playing channel becomes tile 1 without a reload, the chosen one tile 2, selected and audible, the toolbar shows the tile count, tiles fit the window as it resizes, and the window cannot shrink so far that the channel list disappears; the option is absent when nothing plays, on the playing channel, on a screen too narrow, and anywhere on iPhone or iPad.

### AC-14 Sound follows the highlighted tile
Given multi-view with tile 1 highlighted (Apple TV) or selected (Mac)
When the user swipes to another tile, clicks it, or presses Command and its number
Then the old tile goes quiet before the new one is heard, never two at once, each tile's spoken label says whether it has sound, on Mac the matching channel is selected in the list and the lock-screen and Control Center details follow the audible tile; swipes and arrows never change channel or leave multi-view, number entry is off, and play/pause, Space, the media key and the lock-screen control never pause a tile.

### AC-16 Change a tile's channel
Given multi-view with tile 2 highlighted or selected
When the user presses select and picks a channel from the overlay (which says "Changing tile 2 of 3" and marks channels already in a tile), or on Mac clicks a channel in the list
Then tile 2 switches to that channel with one reload and the others are untouched; picking a channel already in another tile moves the highlight there instead; picking tile 2's own channel does nothing; Menu leaves the overlay with nothing changed; no zap bar appears.

### AC-17 Add more tiles, up to the limit
Given multi-view with fewer tiles than the device's limit (four, or two on Apple TV HD and Intel Macs)
When the user chooses "Add as new tile" in the overlay, or "Add to Multi-view" on a Mac channel
Then the new channel joins as the next tile, takes focus and sound, and the layout rearranges without reloading the others; when the device cannot decode another stream, the limit drops to the tiles still playing until the user leaves multi-view; when the limit is reached the overlay offers no "Add as new tile" and the Mac menu shows a greyed "Multi-view is full"; a channel already in a tile cannot be added twice.

### AC-19a Each tile has its own actions
Given a tile highlighted on Apple TV
When the user holds select, or uses VoiceOver's actions
Then a menu offers Full screen, Change channel and Remove from multi-view, with Try again first and focused when the tile has failed; Change channel opens the channel picker for that tile; Menu closes the menu with nothing changed.

### AC-20 One tile full screen and back
Given multi-view with tile k highlighted or selected
When the user presses play/pause or chooses Full screen on Apple TV, or double-clicks the tile on Mac
Then tile k fills the screen (Mac: the tile area) with no reload and the same sound, the others keep playing out of sight, a badge says which tile of how many is shown; Menu or play/pause (Apple TV) or double-click or Escape (Mac) return to the grid; choosing another tile or adding one also returns to the grid.

### AC-22 Remove a tile
Given multi-view with three or four tiles
When the user removes a tile from its actions, its close button or right-click menu, or on Mac presses Command-Delete on the selected tile, or its channel disappears from the source after a refresh
Then that tile stops, the others close up without reloading, and the highlight and sound move to the neighbouring tile if the removed one had them; with two tiles, removing one leaves multi-view and the other channel plays alone without a reload, which counts as a channel change: the zap bar shows and the channel is remembered as the last one; if no tile's channel is left at all, multi-view ends with everything stopped.

### AC-24 Leave multi-view
Given multi-view with tile k highlighted or selected, nothing else open
When the user presses Menu on Apple TV, or "Exit multi-view" on Mac
Then every other tile stops, tile k's channel keeps playing full screen (Apple TV) or in the normal player with the sidebar back as it was (Mac) without a reload, at full quality and with the TV's mode matching again; this counts as one channel change to tile k's channel, which is remembered as the last channel; on Apple TV that Menu press does not also open the tab bar.

### AC-27 A tile that fails says why
Given multi-view with several tiles
When one tile is loading or reconnecting, or fails
Then a loading tile shows a spinner; a failed tile shows a title and explanation, stays highlightable and silent, and does nothing more until the user tries again, changes its channel or removes it; when another tile from the same source is playing and the provider refuses with busy or a 503, 509 or 403, the tile says "Your provider refused another stream. Many providers allow one or two streams per account at a time." (adding a hint to check the login for a 403); when the device cannot decode another stream it says "This Apple TV can't play another stream" (or "This Mac") with "Remove a tile or pick a lower-resolution channel."; other failures use 0018's wording; Try again reloads the tile once.

### AC-33 Leaving the app
Given four tiles playing with tile 2 audible
When the app goes to the background and comes back
Then on Apple TV every tile pauses and resumes, with tile 2 still the only one heard; on Mac nothing pauses.

### AC-35 Four tiles hold up on real hardware
Given each Apple TV 4K generation on wired Ethernet, and separately an M1 Mac, playing four tiles (two MPEG-TS 1080p50 and two HLS 1080p)
When multi-view runs for 30 minutes with 20 changes of the audible tile
Then every tile keeps playing with no buffering or failure, the app is not shut down, and the new tile is heard within half a second of each change.

## Edge cases

- Offline: a tile added while offline fails at once with 0018's offline text; a dropped connection mid-session is retried per tile, with no session-wide error.
- Provider connection limits: many Xtream accounts allow one or two streams, so the second tile from one account may be refused (AC-27). Tiles from different sources do not count against each other. On a one-stream account a new tile can push the older one off; the older one fails rather than looping.
- A slow tile that never starts times out on its own without affecting the others.
- Pick mode is the normal overlay, so huge channel lists behave as in 0007; the Mac list behaves as in 0010.
- A source whose login has not synced has no channels to pick. A source that loses its login mid-session drops out, and its tiles are removed.
- A refresh that renumbers a tile's channel counts as the channel leaving, and removes the tile (see Open questions).
- HDR or 50 Hz tiles play in whatever mode the TV was in; a 50 Hz tile judders on a 60 Hz TV until it is the one kept on exit.
- A radio stream in a tile shows the channel logo; its sound follows focus as usual.
- A highlighted failed tile leaves the room silent, so sound always matches the highlight.
- If the purchase lapses mid-session, the paywall replaces everything and every tile stops.
- Closing the app in multi-view saves nothing; next launch plays the last single channel.
- Removing an unselected tile on Mac leaves the sound where it was.
- Picking a channel from a full-screen tile returns to full screen afterwards.
- Entering multi-view widens a narrow Mac window.
- Reduce Motion: tiles rearrange and enlarge without animation. VoiceOver reads each tile as one element with its actions; the hint and full-screen badge are announced once.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-11 | core (session start commands) + ui (tvOS, fake engines) + integration (display mode, 1080 cap) |
| AC-37 | ui (macOS) + ui (iOS and iPadOS: option absent) |
| AC-14 | core + ui (tvOS, macOS, fake engine logs) + integration (Now Playing) |
| AC-16 | core + ui (tvOS, macOS) |
| AC-17 | core (capacity table) + ui (tvOS, macOS, injected device) |
| AC-19a | ui (tvOS, VoiceOver actions, macOS key) |
| AC-20 | ui (tvOS, macOS, simulated clock) |
| AC-22 | core + ui (tvOS, macOS) + integration (catalogue change) |
| AC-24 | core + ui (tvOS, macOS) |
| AC-27 | core (failure text) + ui (tvOS, macOS) |
| AC-33 | integration (simulated app lifecycle, per platform) |
| AC-35 | device (each Apple TV 4K generation and an M1 Mac, fixture server, signpost log) |

## Open questions

- iPad: an M-series iPad can decode four streams and the Mac interaction would carry over. Whether a later version includes it is open; no criterion changes here.
- Menu in the grid leaves multi-view without asking, and rebuilding four tiles takes about a dozen presses. A confirmation or a "Resume multi-view" entry would change AC-24; decide before Accepted.
- A tile whose channel is renumbered by a refresh is removed. Matching by source and channel id instead would keep it; can be decided in the plan.
- Xtream accounts report their connection limit. Refusing "Add as new tile" up front when it is reached would change AC-17; a later change.
- While one tile is full screen the others keep playing muted, which holds every connection open. Pausing them would free connections on one-stream accounts; changes AC-20.
- AC-35 runs on wired Ethernet; a Wi-Fi run waits for the wired numbers.

## Notes for the plan

- Core types from the old Types section live in `Packages/AntennaCore/Sources/AntennaCore/MultiView/` (ADR-0005): `MultiViewCapacity`, `MultiViewLayout`, `MultiViewSession` (applies actions, returns commands), `MultiViewFailureText`. `MultiViewModel` and `MultiViewScreen` in `Apps/Shared/Views/MultiView/` own one `RoutedEngine` per tile and run commands in order, so two engines are never unmuted at once. Commands carry a `RowKey`, never a URL (ADR-0003).
- Capacity: 2 for `AppleTV5,3` and Intel Macs, 4 otherwise (4K values provisional until AC-35; a generation that fails AC-35 gets the largest tile count that passes, by a spec amendment). Mac minimum window width 1024 pt. After a decoder refusal the cap becomes the larger of 2 and the tiles still decoding, and never rises in that session. Toolbar count reads "<tiles> of <max(cap, tiles)>".
- Layout rule: two columns for 2 to 4 tiles, two rows for 3 and 4, 16:9 tiles at the largest whole width, grid centred, a third tile centred on the second row. tvOS container 1920 by 1080 with margin 24 and gap 16; Mac margin 16 and gap 12. The old AC-2 has worked frames for both. The tiles sit inside 24 pt of the TV edge, past Apple's title-safe area, by owner choice.
- The 0017 refinement in the header means: `setMuted` and `startsMuted`; `maximumVideoHeight` and `setMaximumVideoHeight` (system route only); `appliesDisplayCriteria` and its setter; `PlaybackError.decoderBusy`, not retried; the lifecycle observer handling several engines; a signpost at the first unmuted audio buffer carrying the tile id only; a reconnect refused with 503 or 509 while another tile on the same source plays fails at once instead of looping.
- Refinements owed to other specs: 0007 (third panel button and pick mode), 0008 (zap bar, swipes and number entry inactive in multi-view; exit fires one channel change), 0010 (right-click item, Command-Shift-M, list targets the selected tile, Space inert, Escape only undoes enlarge, 1024 pt minimum), 0015 (the shell hosts multi-view; "same engine instance" becomes the survivor's), 0018 (failure text covers 0017's reasons; tiles use 0017's reconnects only; long press opens tile actions; Now Playing follows the selected Mac tile), 0019 (no buffer in tiles), 0028 (survivor is the stored last channel).
- Hint and full-screen badge show for 5 s; badge reads "Multi-view · tile k of n"; Mac toolbar reads "2 of 4" and "Tile k of n"; tile spoken labels "104, Sport One, sound on" or "muted".
- Board deviations the owner accepted: the focused tile gets a white ring instead of a white fill; Mac remove, retry and exit buttons are drawn smaller with 44 pt hit areas; tile labels carry no programme, so no progress bar.
- Ship as a stack: core types, then Apple TV, then Mac.

## Dropped

- Split earlier (kept for history): AC-19 into AC-19a to AC-19e, because its When did not trigger the change-channel and Menu assertions; AC-40 into AC-40a, AC-40b and AC-40c, because it held four assertions.
- Merged into AC-11: AC-3, AC-11a, AC-11b, AC-11c, AC-11d, AC-12a, AC-31, AC-32.
- Merged into AC-14: AC-5, AC-13, AC-25, AC-40a, AC-40b, AC-40c, AC-45, AC-47.
- Merged into AC-16: AC-6, AC-15, AC-18, AC-25a, AC-41.
- Merged into AC-17: AC-1, AC-4, AC-12, AC-30, AC-37a.
- Merged into AC-19a: AC-19b, AC-19c, AC-19d, AC-19e.
- Merged into AC-20: AC-9b, AC-20a, AC-21, AC-42.
- Merged into AC-22: AC-7, AC-9c, AC-23, AC-34, AC-43.
- Merged into AC-24: AC-8, AC-44.
- Merged into AC-27: AC-9, AC-10, AC-26, AC-28, AC-29.
- Merged into AC-35: AC-36.
- Merged into AC-37: AC-38, AC-39, AC-46, AC-48.
- Moved to the implementation plan: AC-2, AC-9a.
