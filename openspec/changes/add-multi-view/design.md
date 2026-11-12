# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-MultiView.dc.html`, `TV-MultiView-Two.dc.html`, `TV-MultiView-Failed.dc.html`, `TV-MultiView-Actions.dc.html`, `TV-MultiView-Swap.dc.html`, `TV-MultiView-Pick.dc.html`, `iPad-MultiView.dc.html`, `iPad-MultiView-Failed.dc.html`. The two `iPad-` boards draw the Mac window in the shared iPad and Mac frame. They do not put iPadOS in scope.

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Channel rows share one anatomy", "A current programme always shows its progress", "Channels without a logo show initials", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall".

Not drawn yet: the overlay's "Add to multi-view" button over full-screen live, the "Try again" row in tile actions, the Mac right-click item, the Mac enlarged state, the Mac loading ring, and a radio-stream tile.

## Goals / Non-Goals

**Goals:**
- Session logic (capacity, layout, actions, failure text) lives in AntennaCore and is testable without UI.
- Apple TV and Mac share one session model and differ only in input and chrome.

**Non-Goals:**
- iPad, even though an M-series iPad could decode four streams.
- Any retry logic of multi-view's own. Tiles reconnect through the playback engine only.
- Restoring a tile set after relaunch.

## Decisions

- Core types live in `Packages/AntennaCore/Sources/AntennaCore/MultiView/`: `MultiViewCapacity`, `MultiViewLayout`, `MultiViewSession` (applies actions, returns commands) and `MultiViewFailureText`. `MultiViewModel` and `MultiViewScreen` in `Apps/Shared/Views/MultiView/` own one `RoutedEngine` per tile and run commands in order, so two engines are never unmuted at once. Commands carry a `RowKey`, never a URL.
- Capacity is 2 for `AppleTV5,3` and Intel Macs and 4 otherwise. The 4K values are provisional until the hardware requirement passes. A generation that fails it gets the largest tile count that passes, by a spec amendment. After a decoder refusal the cap becomes the larger of 2 and the tiles still decoding, and never rises in that session. The toolbar count reads "<tiles> of <max(cap, tiles)>".
- Mac minimum window width is 1024 pt.
- Layout: two columns for 2 to 4 tiles, two rows for 3 and 4, 16:9 tiles at the largest whole width, grid centered, a third tile centered on the second row. The tvOS container is 1920 by 1080 with margin 24 and gap 16. Mac uses margin 16 and gap 12. The tiles sit inside 24 pt of the TV edge, past Apple's title-safe area, by owner choice.
- Playback engine additions: `setMuted` and `startsMuted`; `maximumVideoHeight` and `setMaximumVideoHeight` (system route only); `appliesDisplayCriteria` and its setter; `PlaybackError.decoderBusy`, not retried; the lifecycle observer handling several engines; a signpost at the first unmuted audio buffer carrying the tile id only; a reconnect refused with 503 or 509 while another tile on the same source plays fails at once instead of looping.
- The hint and the full-screen badge show for 5 s. The badge reads "Multi-view · tile k of n". The Mac toolbar reads "2 of 4" and "Tile k of n". Tile spoken labels read "104, Sport One, sound on" or "muted".
- Board deviations the owner accepted: the focused tile gets a white ring instead of a white fill; Mac remove, retry and exit buttons are drawn smaller with 44 pt hit areas; tile labels carry no programme, so no progress bar.
- A tile whose channel is renumbered by a refresh is removed. Matching by source and channel id instead would keep it, and the implementation may choose that.
- Ship as a stack: core types, then Apple TV, then Mac.

## Risks / Trade-offs

- Open question: Menu in the grid leaves multi-view without asking, and rebuilding four tiles takes about a dozen presses. A confirmation or a "Resume multi-view" entry would change the leave requirement. Decide before the change is accepted.
- Open question: Xtream accounts report their connection limit. Refusing "Add as new tile" up front when it is reached would change the tile limit requirement. A later change.
- Open question: while one tile is full screen the others keep playing muted, which holds every connection open. Pausing them would free connections on one-stream accounts and changes the full-screen requirement.
- Open question: whether a later version includes iPad.
- [The hardware run uses wired Ethernet] → a Wi-Fi run waits for the wired numbers.
- [Provider connection limits refuse the second tile from one account] → the tile says so in plain words and stays failed rather than looping.

## Implementation decisions

Made while building, without a review round. Each names what was picked and why.

- Tiles never reload on the way in or out because routed engines trade their engines. `RoutedEngine.exchange(with:)` swaps the Apple-player and demuxer pair between two routed engines and forwards the new pair's reports. On entry the single player's pair moves into tile 1 and the single player sits idle with a fresh pair; on leave the kept tile's pair moves back. The shell, its player model, the language picks and the last-channel tracker keep the same engine object throughout. Replacing the shell's engine instead would have meant rebuilding every object that holds it.
- Mute is an app-level call on both of a routed engine's engines, `setMuted(_:)`, next to the `setVolume(_:muted:)` that change `add-player-controls-and-playback-errors` added, not a `PlaybackEngine` protocol method. It is synchronous, so commands run in order are muted in order. There is no separate `startsMuted`: mute holds across loads, and a new tile's engine is muted before its first load.
- `TilePlayback` holds the two tile settings. The 1080p cap is `maximumVideoHeight` on Apple's player, set as the item's preferred maximum resolution (1920 by 1080), which reaches HLS only. `DisplayMatcher.appliesDisplayCriteria` false leaves the TV's mode alone: a mode a tile asks for waits, and letting go does nothing, so a tile changing channel never returns the TV to its own mode. When the kept tile turns it back on, its waiting mode is applied.
- The "no decoder free" reason already existed as `PlaybackFailure.noDecoderFree`, which neither retry policy retries. No `decoderBusy` was added.
- The engine maps every 5xx to `serverError` and keeps no status code, so 503 and 509 cannot be told apart from 500. While another tile plays from the same source, `refusalsAreFinal` stops both engines from retrying a busy server or any server error, on the first connection and on reconnects. It is set per tile each time the set of tiles changes, so the older tile on a one-stream account fails once the new tile pushes it off.
- Each tile gets its own `PlaybackLifecycle`, rather than one observer that handles several engines. It pauses on Apple TV and leaves a Mac alone, as the single player's does, and mute is untouched by a pause, so the same tile is heard after the app comes back.
- The signpost is an event named "tile audible" carrying the tile id, emitted when a tile is unmuted. Timing the first unmuted audio buffer needs a hook inside both engines' renderers; it waits for the hardware run in task 6.1, which is the only place it is read.
- On Apple TV, multi-view is a full-screen cover over the shell. Menu, play/pause, swipes and digits reach only the grid, so the tab bar, the info bar, channel swipes and number entry stay out of reach without changes to their code, and Menu that leaves never opens the tab bar.
- The single player sits idle under the cover while tiles play. When multi-view ends, the shell takes the kept channel as tuned, writes it as the last channel and shows the info bar, even when the kept channel is the one it had before.
- "Add to multi-view" shows only while the playing channel is in the playing state, and only for another channel with a place in a source. The picker for a tile is the channel overlay with a pick-mode value: the eyebrow, "Show in tile n", "TILE n" badges and "Add as new tile", and no Search row. It shares the shell's overlay model, so it opens on the group last tuned from.
- A tile shows its spinner as soon as it loads, buffers or reconnects, with no half-second wait; tiles have no caption to time.
- Each tile has VoiceOver actions for Full screen, Change channel, Remove from multi-view and Try again, calling the same model methods as the actions menu. XCUITest cannot invoke custom actions on tvOS, so the UI tests go through the menu and a model test covers the methods.
- UI tests run tiles on scripted engines: `UITESTING_TILE_FAIL=<file>:<reason>` fails a tile's first load of that file, and `UITESTING_MULTIVIEW_CAP` sets the limit. The shell's scripted engine is now wrapped in a routed engine so it can trade with a tile.
- The tile limit reads the device model from `hw.machine`, or the simulator's model identifier, and a Mac's architecture at build time.
- The overlay never opens over a failed playing channel, since select on the error is Try again, so "Add to multi-view" cannot show there in the first place.
- The stream line in the info panel names the player by the router's pick when one engine takes both routes, as the shell's scripted UI-test engine does now that it is routed.
- On a Mac, multi-view replaces the Live detail column. While it is open the window lays out as if it were narrower than 904 pt, so the sidebar folds and the list header's sidebar button brings it back. The tile area's minimum width (1024 minus the 352 pt list and its divider) holds the window at 1024 pt; SwiftUI grows a narrower window to its content's minimum.
- "The screen is too narrow" means the Mac's main screen is under 1024 pt wide. Command-Shift-M adds the channel under the list's keyboard ring.
- A click in the list changes the selected tile's channel, and the list's selected fill marks that tile's channel. The single channel stays as it was until multi-view ends.
- Tiles play at the window's volume level, and mute alone picks the tile heard. When multi-view ends, the single player's level and mute are set again from the volume store.
- Now Playing shows the selected tile's channel, playing unless that tile failed; Space and the lock screen's play and pause do nothing while tiles play.
- `LiveModel.swift` and `LiveRegularView.swift` were near their limits: the guide-text helpers and `LiveModel.Dependencies.live` moved to `LiveModel+Text.swift`, `LiveDetails` moved to `LiveViews.swift`, and the multi-view additions sit in same-file extensions or new files.
