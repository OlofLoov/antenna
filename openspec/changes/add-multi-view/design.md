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
