# design-system reference

Reference material for the `design-system` capability. The requirements are in
`spec.md` next to this file. This file holds the tokens, type scale, layout
patterns and shared components the requirements point to.

- Canvas (editable, private to the owner):
  https://claude.ai/artifact/T98LnnsYB3oZfBrQQSsFJm
- Board sources: [`boards/`](boards/). One `.dc.html` per screen, exported
  from the canvas. The inline `style` attributes are the measurements:
  sizes, spacing, colors and type are read from there, not guessed.
- Reference apps: TiviMate for live TV layout and remote flow, Netflix and
  Disney+ for content-first movies and series. Patterns, never assets.

## 1. Look

| Token | Value | Use |
|-------|-------|-----|
| Ground | `#0B0E13` | App background on every platform |
| Sidebar / tab bar | `#11151C` | iPad and Mac sidebar, iPhone tab bar |
| Overlay scrim | `rgba(8,10,14,0.88)` | tvOS panels over live video |
| Surface | `rgba(255,255,255,0.06)` to `0.12` | Rows, cards, chips; `0.12` is the selected row on touch platforms and the selected-but-unfocused group on tvOS |
| Text | `#F2F4F8` | Primary |
| Text secondary | `#D7DEE8` | Body copy and descriptions |
| Text muted | `#A7B0BF` | Captions, metadata, section eyebrows. 9:1 on ground |
| Text muted on focus | `#4B5563` | Muted text on the focused white card. 7.5:1 on `#F2F4F8` |
| Accent | `#5BB8FF` | Progress fills, guide now line, NOW badge, iPhone selected tab, links |
| Live dot | `#FF5F57` | Only the small dot before "LIVE" |
| Logo placeholder | `#26344A`, `#1E3A5F` | Tile with channel initials when no logo has loaded |
| Focus (tvOS) | background `#F2F4F8`, text `#0B0E13`, shadow `0 12px 32px rgba(0,0,0,.45)` | The focused element, always |

Type is the system font. Sizes in CSS px on the boards equal points in
SwiftUI.

| Platform | Title | Body | Secondary | Caption, minimum |
|----------|-------|------|-----------|------------------|
| tvOS | 38 to 76 | 29 | 22 to 26 | 18 |
| iPadOS, macOS | 22 to 28 | 16 to 17 | 14 to 15 | 13 |
| iOS | 22 to 34 | 15 to 17 | 13 | 12 |

Radii: 14 (tvOS rows and cards), 10 to 12 (touch rows, cards, fields), 6 to 8
(logo tiles, badges), 999 (chips, tvOS tab bar).

## 2. Layout patterns

### Apple TV

- Live video is the background of every live screen. Overlays slide over it.
  The player is never torn down to show UI.
- Channel overlay: three columns from the left, groups (320) | channels (700)
  | now and next (rest), scrim width 1600 of 1920. Clock top right.
- Zap bar: bottom strip, 236 tall, identity | now playing with progress |
  badges. Channel digits typed on a hardware keyboard appear top left.
- Guide: PiP player (480 by 270) and programme detail on top, grid below
  with a 300 wide channel column, 370 per 30 minutes, accent now line.
- Non-live sections (Movies, Series, Search) use the tvOS top tab bar:
  Live, Guide, Movies, Series, Search, then the settings gear. Clock top
  right. The `tvos-shell` capability owns the bar and its Menu behavior.
- Sources and Settings: full-screen panel over the current tab, list
  (640, from x 64) | detail (1088, from x 768), title top left. Rows on
  the left, the selected row's detail on the right.
- Focus is the lifted white card. Nothing else is white-filled.
- Title detail: no tab bar. Art full bleed behind a 1100 wide left scrim
  with the copy column on the hero's left edge. On a series the art stops
  at 520 and the season chips (64) and episode rows (128) sit below it.
- Multi-view: two to four 16:9 tiles on Ground, margin 24 and gap 16, two
  side by side, three as two over one centered, four as a 2 by 2 grid. The
  focused tile has the 5 pt white ring and a white label chip. Only the
  focused tile is audible.

### iPad and Mac

- Three columns: sidebar (232) | list (352) | detail. The sidebar holds the
  sections and, below them, the context list (channel groups, genres,
  recent searches). Sources and Settings sits at the bottom.
- Live: the detail column is the inline player (16:9) with now and next and
  the upcoming list under it.
- Movies and Search put a toolbar on top of the detail column and scroll
  content below it.
- Guide: sidebar | grid. No list column. A toolbar with filter, day chips,
  Now, zoom and the now-playing chip sits over a time grid with a pinned
  200 pt channel column and the now line. Detail is a popover on the block.
- Title detail replaces the content column and the sidebar stays. Toolbar
  with the back link, art on top (240 tall on a series), buttons, plot,
  cast, then season chips (34) and episode rows (96).
- Multi-view on Mac: the sidebar collapses, the list stays as the picker,
  and the detail column holds a 52 pt toolbar over the tile grid (margin
  16, gap 12). The selected tile has a 3 pt ring in the Text color.

### iPhone

- Tab bar: Live, Guide, Movies, Search, Settings. Favorites is a group chip
  inside Live, not a tab.
- Live: player pinned at the top (16:9), now playing row, scrolling group
  chips, channel list.
- Guide: group chips, day chips, then one row per channel with a header
  line and its own horizontal strip of programme cards. No time grid. Detail
  is a sheet. A now-playing mini bar sits above the tab bar.
- Movies: tall portrait hero, chips laid over the art, copy on a solid scrim
  at the foot of the hero, then rows.
- Title detail is pushed inside the Movies tab: 16:9 art with a round
  back button over it, copy, buttons, then season chips (30) and episode
  rows (84). The tab bar stays.
- Onboarding and add source are sheets. iPad centers the same sheet.

## 3. Shared components

- **Channel row**, every platform, in this order: number (tabular, muted),
  logo tile, name, current programme title, 3 to 4 pt progress bar in
  accent. Catch-up shows a clock-arrow glyph at the trailing edge.
- **Programme progress bar** appears everywhere a current programme is
  shown: rows, now panels, zap bar, player scrubber, continue-watching
  cards.
- **Badges**: 1.5 pt muted outline, uppercase, letter-spaced (`4K`,
  `1080p`, `AAC 5.1`, `CATCH-UP 7D`; `CATCH-UP` alone when the day count
  is unknown). The only filled badges are `NOW` (accent), `UP NEXT`
  (accent, the episode Play would start, from the change
  `add-title-detail-and-episode-picker`) and `LIVE` (surface with the live
  dot). While the picture is behind the live edge, `LIVE` takes the outline
  style with the muted dot and, on touch and pointer platforms, returns to
  live when tapped (change `add-timeshift-catch-up-and-start-over`).
  Resolution and audio badges come from the player and exist only for the
  playing channel. As running text the catch-up fact reads "Catch-up 7 days".
- **Section header**: title plus a muted count or "See all" at the trailing
  edge.
- **Content card**: 2:3 poster for titles, 16:9 for continue watching with
  a progress bar along the bottom edge. Focused card on tvOS gets a 5 pt
  white ring and shadow.
- **Search highlight**: the matched substring gets an accent background at
  35% opacity.
- **Passcode prompt**: lock glyph, title, one muted line naming what is
  locked, four digit boxes (72 by 88 pt on tvOS, 56 by 64 on touch
  platforms) that fill with a dot, an error line in the live-dot color.
  tvOS adds a focusable digit row. The other platforms use the system
  numeric keyboard. Drawn on the `*-Groups-Locked` boards.

## 4. Screens and boards

Each change's `design.md` names the boards it covers in its Context section,
at their path under `openspec/specs/design-system/boards/`. That is the only
mapping. This file keeps no table of it, so changes do not conflict here. A
change lists the states it describes that are not drawn yet under "Not drawn"
in its design.

Capabilities with no screen, such as `channel-catalogue` and `guide-data`,
say "none, no UI" where a change would name boards.

Remote vocabulary on tvOS, used by every capability: *select* is a press of
the touch surface; *swipe* and a directional click on the clickpad are the
same input; *Menu* is the back button; *play/pause* is its own button.

## 5. Accessibility identifier prefixes

Used by the requirement "Accessibility identifiers follow the board" (was
DR-11). Prefixes: `onboarding.`, `overlay.`, `zapBar.`, `guide.`, `browse.`,
`movies.`, `series.`, `search.`, `shell.`, `player.`, `timeshift.`,
`groups.`, `guideSources.`, `multiView.`, `settings.`, `paywall.`, `title.`,
`episodes.`, `reminders.`, `recents.`, `profiles.`, `topShelf.`, `import.`.
Element names come from the board's comments and labels, for example
`overlay.groups` and `zapBar.progress`.

## 6. How reviewers use this

- Requirements keep their names once code and tests cite them. A rule that no
  longer applies is removed through a change with a REMOVED delta and its
  reason. Each requirement carries its old rule number as "(was DR-n)".
- Reviewing a proposed change: a change that describes a screen names its
  boards and the design-system requirements that apply. A described state
  (focused, empty, loading, error) that is not on the board is a finding
  unless the design lists it under "Not drawn" with the text style it uses.
- Reviewing an implementation: for each design-system requirement the change
  names, find the evidence in the diff. Compare the view hierarchy to the
  board's structure and the inline sizes to section 1 here. Check identifier
  prefixes against section 5. A mismatch the change did not call out is a
  finding.
- "Live video keeps playing under overlays" (was DR-1) is checkable in code:
  no `PlayerView` teardown and no `pause()` when an overlay is presented.
