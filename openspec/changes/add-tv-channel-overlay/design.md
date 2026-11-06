# Design

## Context

See proposal.md for why. The overlay sits over the tvOS player from `tvos-shell` and reads groups and order from `channel-catalogue`, programmes from `guide-data` and favorites from `favorites`.

Boards, under `openspec/specs/design-system/boards/`: `Main.dc.html`, `Main-Favorites.dc.html`, `Main-FavoritesEmpty.dc.html`, `Main-Empty.dc.html`, `Main-NoProgramme.dc.html`, `Main-GuideLoading.dc.html`.

Not drawn: the focused Search row, the focused Watch and favorite buttons, the unfocused catch-up mark and the focused "Loading guide…" row. Each is its drawn counterpart with the focus or muted color applied.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channel rows share one anatomy”, “A current programme always shows its progress”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

User flow: a channel plays full screen and the user presses select. The list slides in from the left over the video, highlight on the playing channel. Left moves to the groups and changes the channel list as the highlight moves. Right comes back to the channels and changes the panel. Select on a channel tunes and closes. Right from a channel reaches Watch and the favorite button. Menu closes without changing channel.

## Goals / Non-Goals

**Goals:**
- Rows visible within one second of select with 20 000 channels in All channels on an Apple TV 4K (3rd generation).

**Non-Goals:**
- Start over. It stays hidden until change `add-timeshift-catch-up-and-start-over` lands.
- A long-press menu on a channel.

## Decisions

- The one second budget is an owner's manual device check. `channel-catalogue` bounds the catalogue build.
- Playback scenarios are asserted on a fake `PlaybackEngine` injected under a launch argument, which records `load(_:)` calls to a temp file.
- `Channel.streamURL` is never logged, used in an identifier or accessibility label, or shown (adr-0003).
- Rows are keyed by the catalogue's `RowKey`, so duplicate channel ids stay distinct.
- Panel focus order is Watch then favorite until the catch-up change lands.
- Remaining-time text uses the zap bar's formatter. The next list is the guide query after the current programme's stop, or after now.
- The last group resets on a cold launch, as the zap bar's group does.
- Design deviations: selected-but-unfocused group row on the 0.12 surface at weight 600; muted text on the focused white card uses the "Text muted on focus" token; the accent "Now" eyebrow extends “One accent color”.
- Exact copy and the full row and panel rules are those in docs/specs/0007 as of 5ac1fd1.

## Risks / Trade-offs

- [All channels with 20 000 rows may be slow to open] → lazy rows keyed by `RowKey`, checked on device against the one second budget.
- Open question: hide All channels above some number of channels, as TiviMate users do by hand? Can be decided during implementation.
- Open question: a long press on a channel for a menu (favorite, hide, move), or everything through the panel? Can be decided during implementation.
- Open question: remember the last group across launches? Can be decided during implementation.
