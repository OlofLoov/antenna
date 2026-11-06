# Design

## Context

See proposal.md for why. The overlay sits over the tvOS player from `tvos-shell` and reads groups and order from `channel-catalogue`, programmes from `guide-data` and favorites from `favorites`.

Boards, under `openspec/specs/design-system/boards/`: `Main.dc.html`, `Main-Favorites.dc.html`, `Main-FavoritesEmpty.dc.html`, `Main-Empty.dc.html`, `Main-NoProgramme.dc.html`, `Main-GuideLoading.dc.html`.

Not drawn: the focused Search row, the focused Watch and favorite buttons, the unfocused catch-up mark and the focused "Loading guide…" row. Each is its drawn counterpart with the focus or muted color applied.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channel rows share one anatomy”, “A current programme always shows its progress”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”.

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
- `Channel.streamURL` is never logged, used in an identifier or accessibility label, or shown. The fake engine writes its `load(_:)` log to the test's temp directory, never to an accessibility attribute.
- Rows are keyed by the catalogue's `RowKey`, so duplicate channel ids stay distinct.
- Panel focus order is Watch then favorite until the catch-up change lands.
- Remaining-time text uses the zap bar's formatter. The next list is the guide query after the current programme's stop, or after now.
- The last group resets on a cold launch, as the zap bar's group does.
- Design deviations: selected-but-unfocused group row on the 0.12 surface at weight 600; muted text on the focused white card uses the "Text muted on focus" token; the accent "Now" eyebrow extends “One accent color”.
- Exact copy and the full row and panel rules are in Copy and Rules below.

## Copy

- Group column eyebrow "Groups". Favorites carries the star glyph and Search the magnifier glyph.
- Channel column heading: the group's label over "Sorted by number"; for Favorites, "Favorites" over "Your order".
- Empty Favorites: "No favorites yet. Press the star on a channel to add it."
- Empty catalogue: "No channels yet. Add a source in Settings." The heading reads "All channels" and "Sorted by number".
- No programme covering now: "No programme information", on the row and in place of the panel's Now section.
- Guide still loading: "Loading guide…".
- Favorite button: "Add to favorites" or "Remove from favorites".
- Panel badges: the channel number, and "CATCH-UP <n>D" when `catchupDays` is above zero or "CATCH-UP" when `hasCatchup` is true without a day count. No resolution or audio badge.
- Empty-state text is muted 26 pt, centered in the channel column. "No programme information" and "Loading guide…" on a row are muted 22 pt.

## Rules

Rows:
- A row shows the number, the logo tile, the name and the programme title on one line, the progress bar below them, and the catch-up mark at the trailing edge. Progress is elapsed over duration, within 0.01.
- A row is 92 pt tall unfocused and 100 pt focused, never under 64 pt.
- The row's accessibility label is "<number>, <name>, <programme title or state text>, <remaining text>".
- A nil or failing logo shows the `channel-catalogue` initials tile, which carries the initials as its accessibility value. Logo requests are canceled when a row scrolls out of view.
- Long names end in an ellipsis. The programme title gives way before the name does.
- With no programme covering now, or while the guide loads, the row has no progress bar. A loading row switches to its programme or to "No programme information" within five seconds of the guide finishing. At a programme's stop time the row and panel move on within five seconds.

Panel:
- Now section: title, start and stop in the locale's short time style joined by an en dash, then "· " and the zap bar's remaining-time text, the progress bar, and the description when there is one.
- Next section: up to three programmes, each with its short start time and title. The section is absent when there are none.
- An empty group leaves the panel empty.

Focus:
- On open, focus is on the playing channel's row in the selected group, scrolled into view, else on the group's first row. A playing channel missing from the catalogue selects All channels. With no channels at all, focus is on All channels in the group column.
- Right from a group lands on the playing channel if it is in that group, else on the first row. Right from an empty group does not move focus.
- Right from a channel reaches Watch, then the favorite button. Search is the last focusable item in the group column. The clock is not focusable.
- A swipe past the edge of a column (left from groups, right from the favorite button, up from the first item, down from the last) does not move focus or close the overlay.
- Removing a favorite while Favorites is shown moves focus to the next row, else the previous, else the Favorites group.
- When the catalogue changes while open, focus stays on the same `RowKey` if it still exists, else the first row. A selected group that is gone selects All channels.

Playback:
- Select or Watch on another channel calls `load(_:)` once with its `streamURL`, closes the overlay and shows the zap bar. The group the user tuned from becomes the current group. Menu leaves the current group as it was.
- Select on the playing channel: `.playing` or `.loading` closes the overlay with no call, `.paused` calls `play()` once, `.failed` or `.idle` calls `load(_:)` once.
- Menu closes the overlay with no `load(_:)` or `pause()` call and is consumed, so the shell does not also leave the player.
- Select is ignored while the number entry pill shows.
- The clock uses the locale's short time style and updates within one second of a minute boundary.

Identifiers: `overlay.root`, `overlay.groups`, `overlay.group.<index>` (Favorites is 0), `overlay.channelsHeader`, `overlay.channels`, `overlay.channel.<rowKey>` with `.logo`, `.progress` and `.catchup`, `overlay.panel` with `.logo`, `.badges`, `.now`, `.progress`, `.remaining`, `.summary` and `.next`, `overlay.watch`, `overlay.startOver`, `overlay.favorite`, `overlay.clock`, `overlay.search`, `overlay.emptyGroup`.

## Risks / Trade-offs

- [All channels with 20 000 rows may be slow to open] → lazy rows keyed by `RowKey`, checked on device against the one second budget.
- Open question: hide All channels above some number of channels, as TiviMate users do by hand? Can be decided during implementation.
- Open question: a long press on a channel for a menu (favorite, hide, move), or everything through the panel? Can be decided during implementation.
- Open question: remember the last group across launches? Can be decided during implementation.
