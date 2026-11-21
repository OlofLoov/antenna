# Design

## Context

Search had its own component for each kind of result in `Apps/Shared/Components/Search/`: `SearchRow.Channel`, `SearchRow.Programme`, `SearchRow.Title` and `SearchRow.Person`, all on one `RowLook` (a 0.06 surface with a 10 pt corner on iPhone, iPad and Mac, the system bordered button on Apple TV). Each one copied a part of the app and drifted from it.

Screenshots on an iPhone 17 Pro simulator with the `-ui-testing-shelf titles` fixtures, Search next to Live and Movies, and the code side by side for iPad and Apple TV, found these differences:

| Part | Search before | Rest of the app |
|---|---|---|
| Channel row height | 56 iPhone, 66 iPad, 112 Apple TV | Live list 60 iPhone, 64 iPad; channel list 92, 100 focused, on Apple TV |
| Channel row surface | 0.06 gray rounded rectangle on every row | none; 0.12 only on the playing row |
| Channel number | first in the second line, "1 · Now: Morning News" | trailing the name in muted tabular digits |
| What is on | "Now: " prefix, no progress bar | the title alone with a 3 pt (4 pt on iPad and Apple TV) accent bar under it, "Loading guide…" or "No programme information" otherwise |
| Catch-up mark | missing on channels | clock arrow at the trailing edge |
| Apple TV channels | 340 by 112 cards in a sideways row, 84 by 56 tiles | full-width rows with number, 76 by 50 tile, name 29 pt and title 22 pt on one line |
| Programme surface | 0.06, 10 pt corner (iPhone, iPad); system gray bordered platter on Apple TV | guide cards 0.08 with the small corner (8 pt); guide blocks 0.08 and the white focus card on Apple TV |
| NOW badge | 10 pt, 3 pt vertical padding | 11 pt, 1 pt vertical padding |
| Programme on now | no progress | 3 pt accent bar along the card's foot |
| Programme title | 15 pt | 14 pt in the iPhone guide |
| Poster size | 108 by 162 iPhone, 132 by 198 iPad, 180 by 270 Apple TV | 110 by 165, 132 by 198, 212 by 318 |
| Poster corner on Apple TV | 8 pt (the iPhone shelf metrics leaked in: the screen never set them) | 12 pt |
| Poster name | in the accent color (the borderless button tinted it), 13 pt | Continue watching names 13 pt in #D7DEE8 under the art; plain rows show none |
| SERIES badge | 10 pt on a 0.72 scrim, no border | `ShelfBanner.Badge`, size from the shelf metrics, 1.5 pt muted border, on the same scrim |
| Poster menu | none | More info on a movie, Add to or Remove from My list |
| Placeholder art | `PosterTile` name tile | same; unchanged |
| People | a row with a 34 to 56 pt initials circle, name and count line, 56 tall | the title page's Cast and crew chips: bordered capsule, 44 tall, name with a muted trailing word |
| Keyboard cursor (iPad, Mac) | 0.12 surface in place of 0.06 | Live list: 2 pt ring in the Text color, no fill |

Glass: none of these parts used glass, before or after. Every result is a plain surface or the system bordered style alone (design-system/controls-use-system-styles).

## Boards

- `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-Capped`, `iPad-Search-GuideLoading` and `TV-Search` redraw channels, programmes, posters and people as described below.
- Boards copied from: `iPhone` (Live list rows), `iPad` (regular rows), `TV-Overlay-New` (channel list rows), `iPhone-Guide` (programme cards), `TV-Guide` (blocks), `iPhone-Movies`, `iPad-Movies`, `TV-Movies` (posters), `iPhone-Title-Cast` and `TV-Title-About` (cast chips).
- Not redrawn: `iPhone-Search-Recents`, `iPhone-Search-Empty`, `iPad-Search-Loading`, `iPad-Search-OneCharacter`, `TV-Search-Recents` (no result cards on them), and the Live and Groups search boards, which search the channel list itself.

Design-system requirements followed: `design-system/channel-rows-share-one-anatomy`, `design-system/a-current-programme-always-shows-its-progress`, `design-system/controls-use-system-styles`, `design-system/focus-is-the-lifted-white-card`, `design-system/channels-without-a-logo-show-initials`, `design-system/apple-tv-content-stays-in-the-safe-area`.

## Decisions

### Reuse the components, not their sizes

Options considered:
- Change `SearchRow`'s numbers to match (rejected): the next change to the Live row or the poster card would drift again, which is how the copies got here.
- Draw each result with the rest of the app's component (chosen). Search keeps only what has no counterpart: the programme row with its channel line, the bell, recent searches and the keyboard cursor.

What each result is now:

| Result | iPhone | iPad and Mac | Apple TV |
|---|---|---|---|
| Channel | `Browse.ChannelRow`, `.compact` | `Browse.ChannelRow`, `.regular`, three across | `ChannelOverlay.ChannelRow`, two across |
| Programme | `SearchRow.Programme` on `FocusCardStyle(.small, resting: 0.08)` with `GuideBoard.NowBadge` and `GuideBoard.ProgressTrack` | same | same, so focus is the guide's white card |
| Movie or series | `ShelfView.PosterCard`, `.phone`, with `ShelfView.MoreInfoMenuItem` and `MyListMenuItem` | `.pad` | `.tv` |
| Person | `TitlePage.Chip`, `.phone` | `.pad` | `.tv`, the focus card capsule |

The Search screens now set `shelfMetrics` and `browseMetrics` for the whole screen, which also fixes the Apple TV poster corner.

### Small value parameters on the shared components

- `Browse.ChannelRow` and `ChannelOverlay.ChannelRow` take `nameRanges` and `detailRanges`, empty by default, drawn with `SearchRow.Highlighted`. `ChannelOverlay` has a `SearchRow` of its own (the overlay's search field), so `ChannelOverlay.swift` reaches Search's through a file-private alias.
- `ShelfView.PosterCard` takes `badged: Set<ShelfTitle.Kind>`, the kinds that wear their badge, and an `identifier` that defaults to `<prefix>.card.<id>`. Rows in Movies and Series hold one kind and pass nothing. A set of kinds, not a `Bool`, so no flag picks a layout and the badge text stays localized without an optional `LocalizedStringResource` (Xcode 26.6 compatibility).
- `TitlePage.Chip` takes the name, `nameRanges` and a trailing `@ViewBuilder` drawn muted, instead of a `CastChip`. The title page passes "Director"; Search passes the count line. The caller sets the VoiceOver label.
- `GuideBoard.NowBadge(size:)` is the guide card's NOW, now shared.

### The name under a Search poster

Plain poster rows in Movies show no name. Search keeps one because the matched letters must be highlighted in every result (search/results-grouped-best-first). It is drawn the way Continue watching draws its caption: caption size, #D7DEE8, one line, the poster's width, under the button on every platform so the focus lift on Apple TV moves only the art. VoiceOver reads it from the poster's label.

### Channel rows read the Live list's line

`SearchFeed.onNow` returned a title. It is now `line`, the `GuideLine` the Live list and the channel list read, so Search shows the same "Loading guide…" and "No programme information" and the same progress. A channel found by its group says "Matches <group>" in the programme's place, without a bar (`SearchText.channelRowLine` in AntennaCore). VoiceOver keeps reading "Channels, <name>, <number> · Now: <title>".

### Apple TV channels two across

The channel list's row is a full-width row with the name and the programme on one line. In a sideways row of 340 pt cards it would truncate both. Two across, like the programmes under it, gives each row 870 pt, about the overlay's width, and keeps one focus grid.

### Keyboard cursor

The 0.12 surface no longer works once channels have no surface. Every result takes the Live list's ring (`SearchRow.CursorRing`) in its own shape: the medium corner on channels, the small corner on programmes, a capsule on people. Posters keep their 3 pt ring.

### Identifiers

Unchanged: `search.result.channel.<n>`, `search.result.programme.<n>`, `search.result.programme.<n>.remind`, `search.result.title.<n>`, `search.person.<n>`. The poster card's identifier comes from its new parameter, so no `movies.card.*` appears in Search. The poster's menu items keep the shelf's identifiers under the `search` prefix: `search.menu.info` and `search.menu.myList`.

## Risks

- A poster's menu in Search opens More info as a page over Search with origin `.search`, the same route a series pick takes, so Back returns to Search.
- `SearchTitleResult` reads `ShelfLibrary` and `ShelfActivity` from the environment for the menu. Every Search screen already provides both.
