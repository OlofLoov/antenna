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
| Overlay scrim | `rgba(8,10,14,0.72)` over the regular material | tvOS panels over live video (`OverlayMaterial`) |
| Bar scrim | `rgba(8,10,14,0.55)` | Dims the tvOS picture or guide while the highlight is in the tab bar |
| Hero scrim | Ground from `0.85` at the leading edge to `0.72` where the copy ends, `0.3` halfway to the trailing edge, `0` at it; on the iPhone hero, ground from `0` to `0.78` over the 56 pt above the copy | Banner, preview and title page art behind copy. It spans the whole picture with no edge and mirrors in right-to-left languages |
| Surface | `rgba(255,255,255,0.06)` to `0.18` | Rows, cards, chips; `0.08` for dividers, `0.12` is the selected row on touch platforms and the selected-but-unfocused group or tab on tvOS, `0.18` the track of a loading ring |
| Text | `#F2F4F8` | Primary |
| Text secondary | `#D7DEE8` | Body copy and descriptions |
| Text muted | `#A7B0BF` | Captions, metadata, section eyebrows. 9:1 on ground |
| Text muted on focus | `#4B5563` | Muted text on the focused white card. 7.5:1 on `#F2F4F8` |
| Accent | `#5BB8FF` | The app tint. Progress fills, guide now line, NOW and UP NEXT badges, iPhone selected tab, links, and system controls that tint (the prominent button on iPhone, iPad and Mac, switches, selected picker values). Never eyebrows. Text and glyphs on an accent fill, a prominent button's label or a badge, are Ground (`Palette.onAccent`); white on the five accents is under 2.7:1 |
| Live dot | `#FF5F57` | Only the small dot before "LIVE" |
| Logo placeholder | `#26344A`, `#1E3A5F` | Tile with channel initials when no logo has loaded |
| Focus (tvOS) | background `#F2F4F8`, text `#0B0E13`, shadow `0 12px 32px rgba(0,0,0,.45)` | The focused element, always |

Type is the system font in the platform's text styles. A board gives a size
in CSS px, which equals points; the view writes `.font(.boardStyle(size))`,
and `TypeScale` (`Apps/Shared/Components/TypeScale.swift`) picks the style
nearest that size, the larger one on a tie. Nothing on Apple TV is smaller
than Caption 2 (23 pt); nothing on iPhone, iPad or Mac is smaller than
Caption 1 (12 pt). iPad and Mac use the iOS column; the Mac's sizes come
from the system.

| tvOS size | Text style | iOS size | Text style |
|-----------|------------|----------|------------|
| 76 | `.title` (Title 1) | 34 | `.largeTitle` |
| 57 | `.title2` | 28 | `.title` |
| 48 | `.title3` | 22 | `.title2` |
| 38 | `.headline` | 20 | `.title3` |
| 31 | `.callout` | 17 | `.headline` / `.body` |
| 29 | `.body` | 16 | `.callout` |
| 25 | `.caption` | 15 | `.subheadline` |
| 23 | `.caption2` | 13 | `.footnote` |
| | | 12 | `.caption` |

Fixed sizes stay only for the channel number entry (`NumberBox`), subtitles
sized to the picture (`SubtitleOverlay`) and an initial sized to its circle
(`ProfileBadge`). `scripts/check-rules.sh` fails on any other.

Spacing scale (`Metrics.Spacing`): 4, 8, 12, 16, 24, 32, 48, 64, 80.

Corners (`Metrics.Corner`, drawn with `cornerShape(_:)`):

| Corner | Apple TV | iPhone, iPad, Mac | Use |
|--------|----------|-------------------|-----|
| Small | 8 | 8 | Badges, logo tiles |
| Medium | 16 | 12 | Fields, small cards, rows |
| Large | 20 | 26 | Cards, grouped sections, panels |
| Capsule | half the height | half the height | Buttons, chips, the tab bar |

Anything inside a rounded container uses `ConcentricRectangle`. A literal
radius fails `scripts/check-rules.sh`.

Apple TV safe area: 60 pt top and bottom, 80 pt at the sides
(`Metrics.televisionSafeArea`). Full-bleed art, video and scrims may run to
the edge.

Materials:

| Where | Material |
|-------|----------|
| Apple TV panels over live video: channel overlay, zap bar, info panel | `OverlayMaterial`: regular material under the overlay scrim at 0.72 |
| Apple TV full-screen covers | `CoverBackdrop`: ultra thick material under the ground at 0.55 |
| Tab bars, toolbars, controls floating over video or art, the iPhone Movies and Series switch, the reminder banner on iPhone, iPad and Mac | Liquid Glass, from the system or `.glassEffect` |
| Forms and Settings on touch platforms | The system grouped background |
| Content screens | Ground |

Glass alone or a plain surface alone. A view on glass (`.glassEffect`,
`.buttonStyle(.glass)`, `.glassProminent`) takes no background, border,
shadow or stroked overlay; the system draws its edge and highlight. A
surface that needs a fill, a hairline or a shadow does not take glass.
Adjacent glass controls share a `GlassEffectContainer`. A round button over
art or video is the glass button style with the circle shape, never a disc
filled with the scrim tint. `scripts/check-rules.sh` fails on a glass view
whose modifier chain also has `.background`, `.border`, `.shadow` or an
`.overlay` that strokes; files it lets through are named in its exception
list (today only `Apps/Shared/Debug/`).

Controls take system styles: `primaryActionStyle()` (bordered on Apple TV,
glass prominent elsewhere), `prominentStyle(_:)` (glass or bordered
prominent with the Ground label; every prominent button goes through it), `secondaryActionStyle()` (bordered capsule on
Apple TV, glass capsule elsewhere),
`posterButtonStyle()` (card on Apple TV, borderless elsewhere) and
`chipStyle(isPicked:on:)`. The parts the app draws itself share `FocusCard`
and `FocusCardStyle`: guide programme blocks, channel overlay rows and
groups, zap bar sections, multi-view tiles and their actions, passcode
digits and episode rows. A button that only holds focus uses `FocusHolderStyle`.
`scripts/check-rules.sh` fails on a `ButtonStyle` type outside those files.

## 2. Layout patterns

### Apple TV

- Live video is the background of every live screen. Overlays slide over it.
  The player is never torn down to show UI.
- Channel overlay: three columns from the left, groups (320) | channels (700)
  | now and next (rest), scrim width 1600 of 1920. Clock top right.
- Zap bar: bottom strip, 236 tall, identity | now playing with progress |
  badges. Channel digits typed on a hardware keyboard appear top left.
- Guide: PiP player (480 by 270) and programme detail on top, grid below
  with a 300 wide channel column, 365 per 30 minutes, accent now line.
  The page keeps the 80 pt safe edges: 80 + 300 + 4 x 365 + 80 = 1920.
- The shell is the system `TabView`: its glass tab bar, 68 tall and 46
  from the top, holds Live, Guide, Movies, Series, Search and Settings.
  It hides over the full-screen picture and shows on Menu. The bar has no
  mark and no clock; the info bar, the channel overlay, the Guide's header
  and the Movies and Series hero draw the clock top right. The
  `tvos-shell` capability owns the bar and its Menu behavior
  (`TV-Shell-TabView`).
- Sources and Settings: the last tab, an opaque split page, lead column
  (560) | rows. The profile button sits at the top of the lead column with
  two or more profiles.
- Focus is the lifted white card. Nothing else is white-filled.
- Title detail: no tab bar. Art full bleed behind the hero scrim, darkest
  at the leading edge, with the copy column on the hero's left edge. On a series the art stops
  at 520 and the season chips (64) and episode rows (128) sit below it.
- Multi-view: two to four 16:9 tiles on Ground, margin 24 and gap 16, two
  side by side, three as two over one centered, four as a 2 by 2 grid. The
  focused tile has the 5 pt white ring and a white label chip. Only the
  focused tile is audible.

### iPad and Mac

- Three columns: sidebar (232) | list (352) | detail. The sidebar holds the
  sections and, below them, the context list (channel groups, genres,
  recent searches). Sources and Settings sits at the bottom. On Live and
  the Guide a search field heads the channel groups and narrows them by
  name (`iPad-Live-Groups-Search`).
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

- Tab bar: Live, Guide, Movies, Search, Settings. Favorites is a group
  inside Live, not a tab.
- Live: player pinned at the top (16:9), now playing row, the group button,
  channel list. The group button shows the open group's name, its channel
  count and a chevron, and opens the Groups sheet: medium and large
  detents, a search field, the built-in groups first, then every group with
  its count and a checkmark on the open one (`iPhone-Live-Groups`,
  `iPhone-Live-Groups-Search`).
- Guide: the same group button and sheet, day chips, then one row per channel with a header
  line and its own horizontal strip of programme cards. No time grid. Detail
  is a sheet. A now-playing mini bar sits above the tab bar.
- Movies: tall portrait hero, chips laid over the art, copy on the hero scrim
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
  a progress bar along the bottom edge. On tvOS the card button style lifts
  and tilts the focused card, with no ring.
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

Used by the requirement "Accessibility identifiers follow the board".
Prefixes: `onboarding.`, `overlay.`, `zapBar.`, `guide.`, `browse.`, `movies.`, `series.`, `search.`, `shell.`, `player.`, `timeshift.`,
`groups.`, `guideSources.`, `multiView.`, `settings.`, `paywall.`, `title.`,
`episodes.`, `reminders.`, `recents.`, `profiles.`, `topShelf.`, `import.`.
Element names come from the board's comments and labels, for example
`overlay.groups` and `zapBar.progress`.

## 6. How reviewers use this

- Requirements keep their names once code and tests cite them. A rule that no
  longer applies is removed through a change with a REMOVED delta and its
  reason.
- Reviewing a proposed change: a change that describes a screen names its
  boards and the design-system requirements that apply. A described state
  (focused, empty, loading, error) that is not on the board is a finding
  unless the design lists it under "Not drawn" with the text style it uses.
- Reviewing an implementation: for each design-system requirement the change
  names, find the evidence in the diff. Compare the view hierarchy to the
  board's structure and the inline sizes to the type table in section 1. Check identifier
  prefixes against section 5. A mismatch the change did not call out is a
  finding.
- "Live video keeps playing under overlays" is checkable in code:
  no `PlayerView` teardown and no `pause()` when an overlay is presented.
  Search is a tab, and `LiveHold` pauses the channel behind it.

## 7. Right to left

Arabic mirrors every screen. The boards are drawn left to right; read them
mirrored, with these rules. Four boards are drawn in Arabic: `iPhone-RTL`,
`TV-Guide-RTL`, `iPhone-Player-Timeshift-RTL` and `TV-ZapBar-RTL`.

- SwiftUI mirrors what it draws: stacks, `leading` and `trailing`,
  `.offset(x:)`, `.position` and shapes all flip. Logos, posters, artwork,
  the picture and text are not flipped. Never add
  `.flipsForRightToLeftLayoutDirection(true)` to an image.
- Input does not mirror. A touch or pointer location, a drag's translation,
  a tap on one half of the picture, an arrow key and a Siri Remote click
  report the physical side. Convert them with the helpers in
  `Apps/Shared/Components/ReadingDirection.swift` (`fromLeading`,
  `towardTrailing`, `isTrailing(right:)`, `MoveCommandDirection.reading`)
  so input lands on the side the layout draws.
- Progress bars, the scrubber and the timeshift bar fill from the right.
  The guide's channel column is at the right and time runs to the left.
- Play, pause, Picture in Picture, AirPlay, track and start-over glyphs keep
  their shape. Skip back and skip forward swap sides with the layout.
- Uppercase labels and badges use `.letterSpacing(_:)`, which drops the
  spacing in a right-to-left layout: Arabic letters join, and spacing pulls
  them apart.
- The skip keys on a keyboard (left arrow back, right arrow forward) and the
  Mac menu items stay as they are in every language. The guide's arrow keys
  move to what is drawn on that side.
- The boards this applies to most: `TV-Guide`, `TV-Guide-Future`,
  `iPad-Guide`, `iPhone-Guide` (time axis); `iPhone`, `iPad`, `Main` (Live
  list and group button); `TV-ZapBar`, `TV-ZapBar-Timeshift`, `TV-Player`,
  `iPhone-Player`, `iPhone-Player-Timeshift`, `iPad-Player` (progress,
  scrubber and transport); `TV-Shell-TabView`, `TV-Movies-Rows` (tab bar and
  first focus).
