# 0007. Apple TV channel overlay

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: tvOS
- Builds on specs 0013 (groups, numbers, initials, favorites resolution, row keys), 0014 (guide queries), 0015 (shell, full-screen playback), 0008 (channel-change event shows the bar; remaining-time formatter), 0012 (Search tab).
- Blocked on: nothing. AC-1, AC-9, AC-9a and AC-10 are asserted on a fake `PlaybackEngine` (AntennaCore) injected under a launch argument; the real engines are the playback spec's concern.

## Design

Boards: `docs/design/boards/Main.dc.html` with the state boards `Main-Favorites.dc.html`, `Main-FavoritesEmpty.dc.html`, `Main-Empty.dc.html`, `Main-NoProgramme.dc.html` and `Main-GuideLoading.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13. Deviations: the selected-but-unfocused group row uses the 0.12 surface and weight 600 (README section 1 is amended to allow it on tvOS); on the focused white card muted text uses `#4B5563` ("Text muted on focus" token in README section 1); the accent "Now" eyebrow in the panel extends DR-3's NOW usage.
States on the boards:
- `Main.dc.html`: overlay open over live video, selected group, every group with its count at the trailing edge (AC-3), focused channel row as the white card with the muted-on-focus token on its number, programme title and catch-up glyph, unfocused rows, now and next panel for the focused channel, catch-up glyph on a row, channel column header, clock, "Groups" eyebrow, star and magnifier glyphs.
- `Main-Favorites.dc.html`: Favorites selected with its count, header "Favorites" and "Your order" (AC-4), rows in the user's order (AC-12), panel with the filled star labelled "Remove from favorites" (AC-11) and without Start over (AC-14).
- `Main-FavoritesEmpty.dc.html`: Favorites focused with count 0, `overlay.emptyGroup` reading "No favorites yet. Press the star on a channel to add it." at muted 26 pt centred in the column, panel empty (AC-13).
- `Main-Empty.dc.html`: catalogue with zero channels, only Favorites and All channels in the group column, All channels focused, `overlay.emptyGroup` reading "No channels yet. Add a source in Settings." (AC-2b), panel empty, no live video under the overlay.
- `Main-NoProgramme.dc.html`: focused row with "No programme information" at muted 22 pt and no progress bar, panel with the same text in place of the Now section and the next section listing programmes after now (AC-7, AC-20), no Start over.
- `Main-GuideLoading.dc.html`: unfocused rows with "Loading guide…" at muted 22 pt and no progress bar (AC-18), no Start over.
Not drawn: focused Search row, focused Watch and favorite buttons, unfocused catch-up glyph, focused "Loading guide…" row. Each applies the Focus token or the Text muted token of README section 1 to the drawn unfocused/focused counterpart with no other change.

## Problem

Live TV on a television is driven by one remote and one question: what else is on right now. TiviMate answers it with a three-column list over the running picture. Antenna's tvOS build pushes a plain list and a separate player, so the picture stops whenever the user looks for another channel.

## Scope

In:
- Overlay presented over the playing channel with groups, channels and a now-and-next panel.
- Group list from 0013/AC-2 with counts, and a Search entry.
- Channel column for the selected group in 0013/AC-6 order, with the header, and rows per DR-6.
- Now-and-next panel for the focused channel.
- Tuning from the overlay; closing without tuning; committing the current group (AC-22).
- Favorite add and remove from the panel (0013/AC-9, AC-10).
- Clock.
- Guide data through `GuideStore` (0014).
- Accessibility identifiers with prefix `overlay.`.

Out (explicitly):
- The zap bar and number entry (spec 0008).
- The guide grid (spec 0009) and the shell (spec 0015).
- Search behaviour (spec 0012); AC-23 only opens it.
- Start over and catch-up playback. The button is hidden until the catch-up spec is accepted (AC-14).
- Player controls, engine selection and errors (playback spec).
- Group management.
- iOS, iPadOS, macOS browsing (spec 0010).

## User flow

1. A channel is playing full screen, zap bar visible or hidden, no entry pill. The user presses select.
2. The overlay slides in from the left over the video, which keeps playing. Focus lands on the playing channel's row in the current group (0008/AC-15), or the group's first row.
3. Swiping left moves focus to the groups. Moving up and down the groups replaces the channel column.
4. Swiping right from a group returns to the channel column. Moving up and down the channels updates the panel.
5. Select on a channel tunes to it, commits its group as current, and closes the overlay.
6. Swiping right from a channel moves focus into the panel: Watch, then the favorite button.
7. Menu closes the overlay without changing the channel or the current group.
8. Select on the Search entry opens the Search tab.
9. The overlay does not auto-dismiss.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Opening keeps the video playing
Given a channel is playing, zap bar visible or hidden, and no entry pill is shown
When the user presses select
Then the overlay is presented, the engine instance is unchanged, `pause()` is not called and the state is the same value it had before the press.

### AC-2 Initial focus and selected group
Given a channel is playing and the current group is G (0008/AC-15)
When the overlay opens
Then G is selected (its row carries the `.isSelected` trait and the 0.12 surface while focus is elsewhere); focus is on the playing channel's row by `rowKey`, scrolled into view, when it is in G, else on G's first row.

### AC-2a Playing channel not in catalogue
Given a channel is playing whose `rowKey` resolves to no channel (0013/AC-15)
When the overlay opens
Then All channels is selected and focus is on its first row.

### AC-2b Empty catalogue
Given the catalogue has zero channels and the Live tab is shown with nothing playing (0015)
When the user presses select
Then All channels is selected, `overlay.channelsHeader` reads "All channels" and "Sorted by number", `overlay.emptyGroup` reads "No channels yet. Add a source in Settings.", `overlay.panel` has no children and focus is on `overlay.group.1`.

### AC-3 Group column contents
Given the catalogue of 0013/AC-2
When the overlay opens
Then the group column lists, under the "Groups" eyebrow, the groups in 0013/AC-2 order, Favorites with the star glyph, every group with its 0013/AC-3 count at the trailing edge, scrolling when they exceed the height, and `overlay.search` with the magnifier glyph as the last focusable item.

### AC-4 Focusing a group changes the channel column
Given focus on group B
When focus moves to group C
Then the channel column lists exactly C's channels in 0013/AC-6 order and `overlay.channelsHeader` reads C's label and "Sorted by number"; for Favorites it reads "Favorites" and "Your order".

### AC-5 Channel row anatomy
Given a channel with number 104, a logo URL, name "Sport One", a current programme at 68% elapsed and `hasCatchup` true
When its row is rendered
Then the row shows "104", the logo tile, "Sport One" and the programme title on one line, below them `overlay.channel.<rowKey>.progress` with a fraction equal to elapsed over duration within 0.01, and `overlay.channel.<rowKey>.catchup` at the trailing edge; the row's accessibility label is "<number>, <name>, <programme title or state text>, <remaining text>"; the frame of `overlay.channel.<rowKey>` is 92 pt tall unfocused and 100 pt tall while focused (board), never under 64 (DR-5).

### AC-6 Logo fallback
Given a channel whose logo URL is nil or fails to load
When its row is rendered
Then `overlay.channel.<rowKey>.logo` exists and has accessibility value equal to `initials(for:)` from 0013/AC-7.

### AC-7 No programme covering now
Given a channel whose `loadingState` is `.loaded`, `.noData`, `.unavailable` or `.failed` and `current(for:at:)` is nil
When its row and panel are rendered
Then the row shows "No programme information" and `overlay.channel.<rowKey>.progress` does not exist, and the panel shows the same text in place of the Now section.

### AC-8 Panel identity
Given focus on a channel row
When the panel is rendered
Then `overlay.panel.logo` shows the logo or initials tile, the name, and `overlay.panel.badges` with the number and "CATCH-UP nD" when `catchupDays` is greater than zero or "CATCH-UP" when `hasCatchup` is true without a day count; no resolution or audio badge.

### AC-9 Select on another channel
Given focus on a channel row whose `rowKey` differs from the playing channel's
When the user presses select or activates `overlay.watch`
Then the fake engine records exactly one `load(_:)` whose argument equals the channel's `streamURL` (never logged or exposed through accessibility), `overlay.root` is dismissed and the zap bar is shown (0008/AC-1).

### AC-9a Select on the playing channel
Given focus on the playing channel's row
When the user presses select or activates `overlay.watch`
Then with engine state `.playing` or `.loading` the overlay is dismissed and `load(_:)` is not called; with `.paused`, `play()` is called once and `load(_:)` is not; with `.failed` or `.idle` it is called once with the channel's `streamURL`.

### AC-10 Menu closes without tuning
Given the overlay is open and focus is anywhere in it
When the user presses Menu
Then the overlay is dismissed, `load(_:)` and `pause()` are not called, the current group is unchanged, focus returns to the player, and Menu is consumed (0015/AC-3 does not fire).

### AC-11 Favorite toggle
Given focus on `overlay.favorite` for a channel that is not a favorite
When the user presses select
Then a `FavoriteRecord` for the channel exists in the container (0013/AC-10 defines its fields), `overlay.favorite` has label "Remove from favorites", and `overlay.group.0`'s count is one higher; pressing again removes that record (0013/AC-9), the label returns to "Add to favorites" and the count returns to its previous value.

### AC-12 Favorites group
Given favorites per 0013/AC-8
When the Favorites group is selected
Then the channel column lists the resolved favorites in that order with the AC-5 row anatomy.

### AC-13 Empty Favorites group
Given no resolvable favorites
When the Favorites group is selected
Then the channel column shows `overlay.emptyGroup` reading "No favorites yet. Press the star on a channel to add it.", the panel is empty, and swiping right from the group does not move focus.

### AC-14 Start over is hidden
Given any focused channel
When the panel is rendered
Then `overlay.startOver` is absent and the focus order in the panel is `overlay.watch` then `overlay.favorite`. Superseded when the catch-up spec is accepted.

### AC-15 Clock
Given the overlay is open
When the injected clock crosses a minute boundary
Then `overlay.clock` shows the new time in the user's locale short time style within one second and is not focusable.

### AC-16 Large channel sets
Given 20 000 channels and All channels selected
When the user presses select
Then the first frame with channel rows visible is drawn within one second of the press on an Apple TV 4K (3rd generation); 0013/AC-14 bounds the catalogue build.

### AC-17 Channel column focus on entry
Given focus on group C
When the user swipes right
Then focus is on the playing channel's row if it is in C, else on the first row.

### AC-18 Guide still loading
Given a channel whose `loadingState` is `.loading`
When its row is rendered
Then the row shows "Loading guide…" and `overlay.channel.<rowKey>.progress` does not exist, and changes to the AC-5 or AC-7 rendering within five seconds of `loadingState` becoming `.loaded` or `.noData`.

### AC-19 Panel now section
Given focus on a channel with a current programme
When the panel is rendered
Then `overlay.panel.now` shows the title, start and stop in the locale short time style separated by an en dash, "· " followed by 0008/AC-5's remaining text in `overlay.panel.remaining`, `overlay.panel.progress` with a fraction equal to elapsed over duration within 0.01, and `overlay.panel.summary` exists with the summary text, or does not exist when it is nil.

### AC-20 Panel next section
Given focus on a channel
When the panel is rendered
Then `overlay.panel.next` lists up to three programmes from 0014/AC-5 after the current programme's stop, or after now when there is no current programme, each with its locale short start time and title; the section is absent when there are none.

### AC-21 Programme boundary while open
Given the overlay is open and the focused channel's current programme ends
When the injected clock passes the stop time
Then within five seconds the row and panel show the programme now current, or the AC-7 rendering when none covers now.

### AC-22 Current group commit
Given the overlay was opened with current group G and focus has moved to group C
When the user tunes from C's column (select or Watch)
Then the current group becomes C (0008/AC-15a); when the user presses Menu instead, it stays G.

### AC-23 Search entry
Given focus on `overlay.search`
When the user presses select
Then the overlay is dismissed, the shell shows the Search tab (0015/AC-14) with `search.field` focused, the engine state is unchanged, and `overlay.root` is not presented again when Menu is pressed in Search.

## Edge cases and failure modes

- Duplicate channel ids: rows are keyed by 0013/AC-11's `RowKey`; both are listed.
- A group name used by two sources is shown twice in source order (0013/AC-2).
- Logo requests are cancelled when a row leaves the visible area; the fallback tile shows until the image arrives.
- Source with a missing credential contributes no channels (0004/AC-10) and its groups are absent.
- Overlay opened while the engine is `.loading` or `.failed`: the overlay opens over whatever the player shows; AC-9 and AC-9a govern select.
- Removing a favorite while Favorites is selected removes its row; focus moves to the next row, else the previous, else `overlay.emptyGroup` per AC-13 with focus on the Favorites group.
- Select while the entry pill (0008/AC-10) is visible is ignored.
- Very long names truncate with an ellipsis; the programme title on the row gives way to the name first.
- `Channel.streamURL` is never logged, never used in an identifier or label, and never shown (ADR-0003).
- Reduce Motion: the overlay appears without the slide animation.
- VoiceOver: a row reads number, name, programme title and remaining time as one element.
- Catalogue or favorites change while open: columns and counts refresh in place; focus stays on the same `rowKey` when it still exists, else on the first row; if the selected group no longer exists, All channels is selected and focus moves to its first row.
- Play/pause while open toggles the engine as it would without the overlay; the overlay stays open.
- Swipes past the edge of a column (left from groups, right from the favorite button, up from the first item, down from the last) do not move focus and do not close the overlay.

## Test plan

Catalogue behaviour is tested in 0013, guide queries in 0014 and the remaining-time formatter in 0008. UI tests run on the tvOS simulator with a fake engine that records `load(_:)` calls to a file in the test's temp directory (nothing derived from `streamURL` is set on any accessibility attribute), a fixture catalogue, a fake `GuideStore` and an injected clock. Identifiers: `overlay.root`, `overlay.groups`, `overlay.group.<index>`, `overlay.channelsHeader`, `overlay.channels`, `overlay.channel.<rowKey>`, `overlay.channel.<rowKey>.logo`, `overlay.channel.<rowKey>.progress`, `overlay.channel.<rowKey>.catchup`, `overlay.panel`, `overlay.panel.logo`, `overlay.panel.badges`, `overlay.panel.now`, `overlay.panel.progress`, `overlay.panel.remaining`, `overlay.panel.summary`, `overlay.panel.next`, `overlay.watch`, `overlay.startOver`, `overlay.favorite`, `overlay.clock`, `overlay.search`, `overlay.emptyGroup`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (fake engine state) | TBD |
| AC-2 | ui (two Givens) | TBD |
| AC-2a | ui | TBD |
| AC-2b | ui | TBD |
| AC-3 | ui | TBD |
| AC-4 | ui | TBD |
| AC-5 | ui (frame and fraction) | TBD |
| AC-6 | ui (failing image URL, accessibility value) | TBD |
| AC-7 | ui (fake GuideStore, parameterised states) | TBD |
| AC-8 | ui | TBD |
| AC-9 | ui (fake engine load log) | TBD |
| AC-9a | ui (fake engine, five states) | TBD |
| AC-10 | ui | TBD |
| AC-11 | integration (in-memory ModelContainer) + ui | TBD |
| AC-12 | ui | TBD |
| AC-13 | ui | TBD |
| AC-14 | ui | TBD |
| AC-15 | ui (injected clock) | TBD |
| AC-16 | device | manual on Apple TV 4K with a 20k fixture |
| AC-17 | ui | TBD |
| AC-18 | ui (fake GuideStore state change) | TBD |
| AC-19 | ui | TBD |
| AC-20 | ui | TBD |
| AC-21 | ui (injected clock) | TBD |
| AC-22 | ui | TBD |
| AC-23 | ui | TBD |

## Open questions

- Should All channels be hidden above a channel count, as TiviMate users do by hand, or rely on AC-16?
- Long press on a row for a context menu (favorite, hide, move) or everything through the panel?
- Remember the last selected group across launches (0008/AC-15c resets it on cold launch)?
