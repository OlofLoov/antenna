# 0010. Live TV browsing on iPhone, iPad and Mac

- Status: Draft (two spec-reviewer rounds; remaining findings listed in the PR)
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS
- Builds on specs 0013 (catalogue: groups, order, initials, favorites), 0014 (guide queries), 0012 (matching function for the local filter; adds `browse.laterProgramme`), 0011 (Movies and Series presence rule).
- Supersedes 0004/AC-14 on these platforms: a channel plays inline, nothing is pushed. Supersedes 0005/AC-1 and AC-2 on these platforms: Favorites becomes a group inside Live, not a tab. On acceptance, 0005's status line gains "AC-1 and AC-2 superseded by 0010/AC-12 on iOS, iPadOS and macOS" and its README row says the same; 0005/AC-3 and AC-4 stay in force. Renames the Channels tab of 0004/AC-8 and AC-9 to Live. Answers 0004's open question "where does the AC-11 error get rendered": `browse.banner` (AC-21).
- Blocked on the playback engine spec (not yet written) for `EngineRouter`-provided inline playback with an observable state and PiP capability (AC-6, AC-13, AC-17); tested with a fake engine until then.

## Design

Boards: `docs/design/boards/iPad.dc.html` (iPadOS and macOS, regular width), `docs/design/boards/iPhone.dc.html` (iOS and any compact width).
Design rules that apply: DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13, DR-15. Deviations: DR-6, on touch and pointer platforms the number trails the name (logo, name, number, programme, bar) because the logo tile is the primary scan target; DR-7, the compact now-playing row has no bar because the player's programme progress bar sits directly above it.
States on the boards: sidebar with the app mark, Live selected and the Sport group selected, channel list with header and the selected row, inline player with controls (pause, programme progress, clock, LIVE, PiP, full screen) and the panel with the favorite star and up-next list; iPhone with the pinned player (pause, progress, clock 13 pt, LIVE, PiP 32 pt, full screen), now-playing row with star, group chips (Favorites, All channels, Sport, …; no counts), list and tab bar.
State boards, one file per state beside the two above:
- Loading rows (`browse.loading`, 15 pt name on iPhone and 16 pt on iPad, muted 15 pt count or indeterminate ring) with the nothing-selected player: `iPad-Loading.dc.html`, `iPhone-Loading.dc.html`.
- Nothing selected (`browse.player` in the ground colour with the mark and "Select a channel" muted 15 pt, `browse.panel` hidden): `iPad-NothingSelected.dc.html`; the compact version is the player on `iPhone-Loading.dc.html`.
- Every source failed (`browse.error`, 17 pt title, 15 pt muted body, `browse.retry` 44 pt): `iPad-Error.dc.html` with "Could not load channels" and a waiting-for-login line; `iPhone-Error.dc.html` with the offline wording split into title and body.
- Some sources failed (`browse.banner`, 15 pt, Retry and dismiss as 44 pt targets, above the list header on iPad and above the chips on iPhone): `iPad-Banner.dc.html`, `iPhone-Banner.dc.html`. The iPhone board also shows the AC-24 waiting-for-login banner under it.
- Sources loaded, no channels (`browse.empty`, muted 15 pt centred, waiting-for-login line, `browse.retry`): `iPad-Empty.dc.html`.
- Empty Favorites group (`browse.emptyGroup`, muted 15 pt centred): `iPhone-EmptyFavorites.dc.html`.
- Waiting-for-login sidebar row (`browse.group.waiting.<sourceId>`, muted 15 pt after the last group): `iPad-Banner.dc.html`, `iPad-Error.dc.html`, `iPad-Empty.dc.html`.
- Collapsed widths (AC-1): `iPad-Collapsed.dc.html` at 800 pt with `browse.toggleSidebar` in the list header; `iPad-Collapsed-Narrow.dc.html` at 600 pt with `browse.toggleSidebar` and `browse.toggleList` above the player.
- Full screen (AC-17): `iPhone-FullScreen.dc.html`, 844 by 390, controls on the bottom edge, the full-screen control shows the exit glyph.
- Hardware-keyboard focused row (AC-14): `iPad-Focus.dc.html`, a 2 pt inset ring in the Text colour with no fill, on a row other than the selected one.
Not drawn: nothing. The boards are exports of the design canvas; the canvas still needs the same states.

## Problem

On a phone or a desk the user browses with a finger or a pointer while a channel plays in the corner. Antenna's tab bar and pushed player stop the picture on every navigation. The three-column layout from TiviMate's channel list maps onto a sidebar, a list and a player on iPad and Mac, and onto a pinned player with a list on iPhone.

## Scope

In:
- Regular width (iPadOS, macOS): sidebar with sections and groups, channel list with local filter, inline player with controls, now-playing panel, up-next list. Column collapse rules for narrow windows and Split View.
- Compact width (iOS, iPad in a compact Split View): player pinned at the top, now-playing row, group chips, channel list, tab bar with Live, Guide, Movies, Search, Settings. Series is reached from inside Movies at compact width (0011/AC-1).
- Selecting a channel plays it inline through `EngineRouter`.
- Group filter, including Favorites and All channels.
- Local filter field over the current group by name and number.
- Favorite toggle from the panel (regular) and row (compact).
- Player controls: play and pause, programme progress, wall-clock time, LIVE badge, Picture in Picture control (iOS, iPadOS), full screen.
- Loading, partial failure, total failure, offline, empty and nothing-selected states.
- Keyboard shortcuts on macOS and iPadOS with a hardware keyboard.
- Accessibility identifiers with prefix `browse.`.
- With no `SourceRecord`, 0006/AC-1 applies and this screen is not shown.

Out (explicitly):
- Guide, Movies, Series and Search screens (specs 0009, 0011, 0012; the sidebar and tab bar only navigate to them).
- Sources and Settings screen content.
- Playback engine selection, buffering and error UI inside the player (playback spec, ADR-0001).
- Picture in Picture behaviour and automatic PiP on leaving the app (playback spec; both need the audio background mode and a PiP-capable layer on `PlaybackEngine`). This spec only places the control.
- Background audio.
- Catch-up and timeshift. The player's progress bar is programme progress (DR-7).
- Reloading channels when sources change (0004 known gap; source refresh spec).
- Session restore of the last played channel (later spec).
- Reordering favorites or groups.

## User flow

iPadOS and macOS, regular width:
1. The Live section is selected in the sidebar under the app mark. Below the sections, the groups list shows Favorites, All channels and every source group with counts.
2. The middle column shows the selected group's channels with a header (group name, count) and a filter field. Typing filters the list on each keystroke.
3. Selecting a row plays the channel in the right column's player. The row is highlighted. The panel under the player shows logo, programme title, times, channel, remaining time, description, a favorite star and the next three programmes.
4. The player controls appear on tap or while the pointer is over the player.
5. The star in the panel toggles the favorite.

iOS and compact width:
1. The Live tab shows the player pinned under the status bar, the now-playing row with the star, group chips (Favorites, All channels, then groups), and the channel list for the selected chip. No list header.
2. Tapping a row plays the channel in place; the list stays. The full-screen control, or rotating an iPhone to landscape, enters full screen.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Regular-width columns
Given a horizontal size class of regular on iPadOS or macOS
When the Live section is shown
Then with at least 904 pt available three columns are visible: sidebar (232 pt), channel list (352 pt) and the player with its panel (the rest, never under 320 pt); between 672 and 904 pt the sidebar is collapsed behind `browse.toggleSidebar` and list and player are visible; below 672 pt the list is also behind `browse.toggleList` and only the player with its panel is visible. The list is never placed above or below the player.

### AC-2 Compact-width layout
Given a horizontal size class of compact
When the Live tab is shown
Then the frame of `browse.player` spans the full width at a 16:9 height, followed by `browse.nowPlaying`, the group chips and the channel list, with the tab bar at the bottom listing Live, Guide, Movies, Search and Settings; Movies is present under 0011/AC-1.

### AC-3 Sidebar contents
Given sources with groups per 0013/AC-2
When the sidebar is rendered at regular width
Then it lists, under the app mark, Live, Guide, Movies, Series, Search in that order (Movies and Series under 0011/AC-1), then a Groups header with Favorites, All channels and every group with its count, then Sources & Settings at the bottom.

### AC-4 Group selection filters the list
Given group "Sport" with 42 channels
When the user selects it in the sidebar or taps its chip
Then the list shows those channels in 0013/AC-6 order, the previously selected channel keeps playing, and the filter field is cleared; at regular width `browse.listHeader` reads "Sport" and "42 channels"; at compact width the Sport chip is shown selected, no header exists and chips carry no counts.

### AC-5 Channel row anatomy
Given a channel with number, logo, name, current programme and progress
When its row is rendered
Then it shows the logo tile (56 by 36 pt regular, 52 by 34 compact; initials per 0013/AC-7 when no logo), name, number right-aligned in the muted colour, programme title, and a 3 pt accent progress bar; the frame of `browse.row.<rowKey>` is 64 pt (regular) or 60 pt (compact).

### AC-6 Inline playback on selection
Given a channel row
When the user selects it
Then the channel list remains visible and interactive, the row is highlighted, the engine obtained through `EngineRouter` has received `load(channel.streamURL)` exactly once (fake engine in tests) and its state is `.playing`, and the now-playing panel (regular) or row (compact) shows that channel.

### AC-7 Local filter
Given the "Sport" group is selected and 20 000 channels are loaded in total
When the user types into `browse.filter`
Then the list shows only channels of the current group matched by name (0012/AC-2 folding and token rules) or by number digit prefix (0012/AC-3); group text is not matched; results reflect each keystroke on the next frame with no debounce; clearing the field restores the group.

### AC-8 Now-playing panel (regular)
Given a channel with a current programme playing at regular width
When the panel is rendered
Then it shows the logo, programme title, "<start> – <stop>" as locale short time, "<channel> · <number> · <remaining per 0008/AC-5>", the description, `browse.favorite`, and "Up next on <channel>" with the next three programmes (0014/AC-5) and their start times.

### AC-9 Guide states
Given a channel whose 0014 `loadingState` is `.noData`, `.unavailable`, or `.failed` with no previous guide
When it plays
Then the panel (regular), `browse.nowPlaying` (compact) and the list row show "No programme information" in the muted colour with no progress bar, no up-next list and no "Next:" fragment; given `.loading` they show "Loading guide…" (same string as 0008/AC-6b) and switch when the state resolves.

### AC-10a Player controls, contents
Given a channel is playing inline
When the controls are shown
Then they contain `browse.player.playPause`, `browse.player.progress` showing the current programme's elapsed fraction (absent when there is no current programme), `browse.player.clock` with the wall-clock time in the user's locale, `browse.player.live` with the live dot, `browse.player.pip` on iOS and iPadOS only, and `browse.player.fullscreen`.

### AC-10b Player controls, visibility
Given a channel is playing inline
When the user taps the player
Then the controls appear and hide three seconds after the last touch on the injected clock; on macOS and iPadOS with a pointer they stay visible while the pointer is over the player and hide one second after it leaves.

### AC-11 Favorite toggle
Given the panel or row for a channel that is not a favorite
When the user taps the star
Then `Catalogue.addFavorite(channel)` runs and its snapshot is inserted (0013/AC-10), the star fills, and the sidebar Favorites count increases by one (chips show no count); tapping again applies 0013/AC-9's removal and reverses both.

### AC-12 Favorites group
Given favorites per 0013/AC-8
When Favorites is selected
Then the list shows the resolved favorites in that order with the AC-5 row anatomy and the count equals the listed rows; with none, `browse.emptyGroup` reads "No favorites yet. Tap the star on a channel to add it."

### AC-13 Picture in Picture control
Given a channel is playing inline on iOS or iPadOS
When the controls are shown
Then `browse.player.pip` is present and enabled only when the engine reports PiP support; on macOS it is absent; activation behaviour is the playback spec's.

### AC-14 Keyboard shortcuts
Given a hardware keyboard on macOS or iPadOS
When keys are pressed with focus in the list
Then Up and Down move the focused row (focus ring, distinct from the selected row's fill) without tuning, Return plays the focused row, Space toggles pause from anywhere outside a text field, Command-F focuses `browse.filter`; in full screen Escape exits (AC-17).

### AC-16 Loading state
Given sources are loading
When the Live section is shown
Then `browse.loading` renders in place of the channel list (regular) or of chips and list (compact) with one row per source (`browse.loading.<sourceId>`) showing its name and either an indeterminate indicator or "<n> channels" once loaded; the player shows the AC-23 state.

### AC-17 Full screen
Given a channel is playing inline
When the user activates `browse.player.fullscreen` or rotates an iPhone to landscape
Then the player fills the screen with the AC-10a controls, and exiting returns to the inline layout with no further `load` call and the engine state still `.playing`.

### AC-18 Sources loaded but no channels
Given at least one source loaded without error with zero channels and, optionally, a source whose Keychain item is absent
When the Live section is shown
Then `browse.empty` reads "No channels yet", lists each credential-less source as "<name>: waiting for its login to sync from iCloud", shows `browse.retry` for the loaded-but-empty sources, no loading indicator is shown, and when the credential arrives (fake credential store flips) the source loads without user action. The case where no source has a credential on tvOS is 0006/AC-21.

### AC-19 Now-playing row (compact)
Given a channel with a current programme playing at compact width
When `browse.nowPlaying` is rendered
Then it shows the logo or initials tile, the programme title, "<number> <channel> · <start> – <stop> · Next: <next title>" with locale short times, and `browse.favorite`; no progress bar (DR-7 deviation).

### AC-20 Every source failed
Given every source failed to load, or no source loaded channels and at least one failed
When the Live section is shown
Then `browse.error` reads "Could not load channels", or "You're offline. Connect to the internet and try again." when every failure is a `URLError` with code `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed` (0006/AC-8), with `browse.retry`; credential-less sources are listed as in AC-18; error text from the source is not shown.

### AC-21 Some sources failed
Given one source failed and another loaded
When the Live section is shown
Then the loaded channels are listed and `browse.banner` reads "Could not load <name>" (names joined with commas) with a Retry control that reloads only the named sources while playback continues; the banner is dismissible and does not return until the next load.

### AC-22 Large channel sets
Given 20 000 channels and All channels selected
When the Live section is shown
Then the first frame with rows appears within one second of the section appearing on an iPhone 15 (manual, Instruments), a five-second flick drops no frames in the Core Animation FPS instrument (manual), and filtering the group completes in under 50 ms in a debug `swift test` (benchmark, not CI-gated); group building is 0013/AC-14.

### AC-23 Nothing selected
Given sources loaded and no channel selected
When the Live section is shown
Then `browse.player` shows the ground colour with the Antenna mark and "Select a channel" in the muted colour, no controls, and `browse.panel` and `browse.nowPlaying` are hidden.

### AC-24 Waiting-for-login row
Given one source loaded and another has no credential on this device
When the sidebar is rendered
Then `browse.group.waiting.<sourceId>` reads "<name> · waiting for login" after the last group; at compact width the same text is a `browse.banner`.

## Dropped

- AC-15 (no sources shows onboarding): restated 0006/AC-1 without its entitlement precondition. Kept as a Scope sentence.

## Edge cases and failure modes

- iPad in Split View at compact width uses AC-2; returning to regular width restores AC-1 with the same channel playing.
- Logo loading is cancelled for rows that scroll away; fallback tile per 0013/AC-7.
- Programme boundary: panel, row and list rows update within five seconds.
- A source with a missing credential counts as neither loaded nor failed (AC-18, AC-20, AC-24).
- Dynamic Type at accessibility sizes: rows grow; the number stays trailing; the pinned player keeps 16:9.
- VoiceOver: a row reads name, number, programme and remaining time; the player's controls have labels.
- Audio continues in the background only when the playback spec's PiP is active; this spec adds no background audio.
- Holding an arrow key moves the focus through the list without tuning (AC-14).

## Test plan

Filtering (shared with 0012) and the up-next derivation are pure functions in AntennaCore, with a timing test over a 20 000-channel fixture. Favorites use an in-memory `ModelContainer`. AC-6 and AC-17 use a fake engine injected via launch argument that records loaded URLs to a file in the test's temp directory; nothing derived from `streamURL` is set on any accessibility attribute (ADR-0003). Sizes are read from element frames. Identifiers: `browse.sidebar`, `browse.toggleSidebar`, `browse.toggleList`, `browse.section.<name>`, `browse.group.<index>`, `browse.group.waiting.<sourceId>`, `browse.chips`, `browse.chip.<index>`, `browse.list`, `browse.listHeader`, `browse.filter`, `browse.row.<rowKey>`, `browse.player`, `browse.player.playPause`, `browse.player.progress`, `browse.player.clock`, `browse.player.live`, `browse.player.pip`, `browse.player.fullscreen`, `browse.panel`, `browse.nowPlaying`, `browse.favorite`, `browse.upNext`, `browse.laterProgramme`, `browse.loading`, `browse.loading.<sourceId>`, `browse.error`, `browse.banner`, `browse.retry`, `browse.empty`, `browse.emptyGroup`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (iPad and macOS at three widths) | TBD |
| AC-2 | ui (iPhone, frame of `browse.player`) | TBD |
| AC-3 | ui | TBD |
| AC-4 | ui (iPad and iPhone) | TBD |
| AC-5 | ui (frames) | TBD |
| AC-6 | ui + fake engine log | TBD |
| AC-7 | core (shared matcher) + ui | TBD |
| AC-8 | core (up-next) + ui (iPad) | TBD |
| AC-9 | ui (fake GuideStore states) | TBD |
| AC-10a | ui (iPhone and macOS) | TBD |
| AC-10b | ui (injected clock) | TBD |
| AC-11 | integration + ui | TBD |
| AC-12 | integration + ui | TBD |
| AC-13 | ui (fake engine PiP support) | TBD |
| AC-14 | ui (macOS; iPad `typeKey`) | TBD |
| AC-16 | ui (stubbed sources) | TBD |
| AC-17 | ui (iPhone rotation; fake engine) | TBD |
| AC-18 | ui (stubbed sources, fake credential store) | TBD |
| AC-19 | ui (iPhone) | TBD |
| AC-20 | ui (stubbed failures per code) | TBD |
| AC-21 | ui | TBD |
| AC-22 | device + core benchmark | manual on iPhone 15 |
| AC-23 | ui | TBD |
| AC-24 | ui (iPad and iPhone) | TBD |

## Open questions

- Should the channel list on iPhone offer swipe actions (favorite, hide) or a context menu?
- macOS: does the player get a detachable window, or is full screen enough?
- Should the local filter also match the current programme title?
- Auto-tune after 500 ms of no further arrow key, or Return only?
