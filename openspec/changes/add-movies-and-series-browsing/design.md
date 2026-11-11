# Design

## Context

See proposal.md for why. The sections read titles and categories through `xtream-vod-client` and store progress and My list as change `add-watch-progress-sync` decides.

Boards, under `openspec/specs/design-system/boards/`: `TV-Movies.dc.html`, `iPad-Movies.dc.html`, `iPhone-Movies.dc.html`, `TV-Movies-Rows.dc.html`, `iPad-Movies-Rows.dc.html`, `iPhone-Movies-Rows.dc.html`, `TV-Movies-Grid.dc.html`, `iPad-Movies-Grid.dc.html`, `iPhone-Movies-Grid.dc.html`. The Series section reuses the Movies boards with series data.

Not drawn: loading rows per source, empty, error, banner, alert, the poster menu, and the More info button that does nothing yet.

Design-system requirements that apply: “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Movies and series open content first”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”, “Loading shows real progress per step”.

On Apple TV the user picks Movies in the tab bar. The banner moves through up to four new titles while nothing in it is focused, and swiping past its buttons pages it. Below come Continue watching, My list, Recently added, a row per category and a row of genre chips. Selecting a poster plays the movie or the next unwatched episode; a long press opens the poster's menu.

On iPad and Mac, Movies in the sidebar shows a toolbar with search and sort, the banner and the rows. Under Genres the sidebar lists My list, All movies and each category with its count.

On iPhone the Movies tab shows the Movies | Series switch, a tall banner with genre chips over the artwork, then the rows. Swiping the banner pages it.

## Goals / Non-Goals

**Goals:**
- With 20 000 items in 400 categories, the banner and three rows on screen within two seconds on Apple TV 4K (3rd generation) and iPhone 15.
- The poster cache stays under 50 MB in memory and 500 MB on disk.

**Non-Goals:**
- A setting for the banner's rotation.
- A detail page. More info stays inert until change `add-title-detail-and-episode-picker`.

## Decisions

- Storage, duplicates and merge rules follow change `add-watch-progress-sync`. Records hold title ids and `sourceID`, never URLs. Removing from My list deletes every matching record.
- The poster cache keys on a hash of the URL and its disk entries never contain the URL. Playable URLs are built on demand from the Keychain credential and never logged.
- In progress means 2% to under 95% of a known duration. Records with no duration are left out. Resume seeks before the first frame. Series play picks the first episode in the Xtream client's order below 95%.
- Banner: four newest by `added`, eight seconds each, paused while focus, touch or pointer is inside, filled from provider order when fewer than four have dates. Length reads "2 h 08 min" or "<m> min". The 4K and age badges follow Badge rules below.
- Recently added holds 50 items and its header counts items added in the last 30 days. Undated items follow dated ones. Items with no category appear only in Recently added and the All grid.
- Board deviations: “Focus is the lifted white card” for the banner's Play button and the focused poster shadow, “One accent color” for the accent eyebrow, “Text stays above the platform caption floor” for outlined badges and the eyebrow up to 2 pt under the caption floor, “Loading shows real progress per step” for placeholder posters only until a source answers.
- Identifier prefixes are `movies.` and `series.` with the same element names.
- A position saved on another device updates Continue watching within five seconds of the local store change.
- When to save is `PositionSaving` in AntennaCore: 30 seconds of wall time while playing, counted again from each play, and at once on pause, stop, background and end. The end saves the full length so the title counts as watched. Live positions are never saved. The player screen feeds it the engine's positions and states and writes what it returns through `ActivityStore.saveProgress`.
- The tvOS tab bar shows Movies and Series for any Xtream source, so the `tvos-shell` tab requirement changes with this.
- The rules live in `AntennaCore/Shelf`: `ShelfTitle` (a movie or series from any source), `Shelf.banner` and `Shelf.rows`, `ContinueWatching` and `ShelfText`. Screens map Xtream rows to `ShelfTitle` and read progress from `ActivityStore`.
- Continue watching keeps a series whose latest episode is finished as "Next episode" until its episode list shows nothing unwatched, so the row does not load every series' episodes up front. Selecting a series whose episodes are all finished starts the first from the beginning.

## Implementation decisions

Made while building the screens, without the user available. Each can be revisited in review.

- **Loading.** Each section loads its titles from every Xtream source the first time it opens, and keeps them while the app runs. Options were loading at launch, which costs every launch a catalogue fetch the user may never look at, or loading on each open, which makes switching tabs slow. A source waiting for its login is tried again when the section opens, when the app returns to the foreground and every five seconds while it waits, as Live does.
- **Banner details.** The list calls carry no year, length or description, so the banner asks the provider's info call for the title on show and the next one, once each. Until it answers, the banner shows the name and category. The art is the first backdrop from that call, else the poster.
- **iPhone banner text.** `iPhone-Movies` draws no description, but the requirement asks for one, so the iPhone banner shows it on two lines under the facts.
- **Eyebrow.** "Recently added · <category>" for movies and series alike, as the boards draw it.
- **Paging.** iPhone and iPad page the banner with a sideways swipe of 40 pt; the dots also show a title when tapped, and VoiceOver adjusts the pager. On Apple TV, moving right from My list or left from Play pages it. Focus on any banner button, a finger on the banner or the pointer over it holds the title. Paging wraps at both ends with or without Reduce Motion.
- **Status.** `ShelfStatus` in AntennaCore decides between loading, offline, "Could not load movies", "Nothing here yet" and titles. Loading shows until any source has titles; once one has, titles show and the others report through the banner or a waiting note.
- **Identifiers.** Rows and genres use a slug of the category name (`movies.row.kids-family`, `movies.genres.kids-family`) instead of a category id, because a merged row has one id per source. Posters are `movies.card.<title id>`. The banner's parts are `movies.hero`, `.hero.title`, `.hero.play`, `.hero.info`, `.hero.myList` and `.hero.pager`. States are `movies.loading`, `.error`, `.empty`, `.retry`, `.failure` (the failed-source banner) and `.waiting.<source id>`. The iPhone switch is `movies.kind` with `movies.kind.movies` and `movies.kind.series`. Series uses the same names under `series.`.
- **Apple TV focus.** The banner's Play button takes the shell's content focus, so opening the tab lands on Play and swiping up from it reaches the open tab. The `tvos-shell` stand-in requirement changes with this change, since Movies and Series are no longer stand-ins.
- **Year sort.** The list calls carry no year, so Year reads it from the title's name, the last number from 1900 to 2099 standing alone ("Dune (2021)", "Dune - 2021"). Titles without one follow by name. Asking the info call for thousands of titles was the other option and is too slow.
- **Grids.** Picking a genre or All in the iPad and Mac sidebar keeps the current order; Title or Year with no grid open shows All. On iPhone the chips sit over the banner's art and the banner stays above the grid. On Apple TV the Genres row starts with an All movies chip, the grid replaces the rows under the tab bar, and Menu closes it with focus back on the banner's Play button.
- **Both sections load together.** Opening Movies or Series loads both, because Continue watching mixes movies and series in each section.
- **Continue watching captions.** A series card loads its series' episode list once it shows on screen, to read "S2 E4" and to drop a series with nothing left to watch. Until then it shows the minutes left, or "Next episode" for a finished episode. The cards crop the poster to 16:9, since the list calls carry no wide artwork.
- **My list.** The row and the iPad and Mac sidebar entry count only loaded titles of the section's kind. The poster menu is the system context menu: a long press on iPhone and Apple TV, a secondary click on iPad and Mac. On Apple TV the Genres row starts with My list, then All movies.
- **UI tests.** `-ui-testing-shelf <scenario>` seeds Home (M3U) and the Xtream sources Cabin and Office with scripted titles (and for `watching`, saved positions and My list entries), and `-ui-testing-reduce-motion` makes the banner act as with Reduce Motion on.

## Badge rules

- "4K" shows when the movie's `name` contains "2160p", "4K" or "UHD", ignoring case.
- The age badge shows only when `ageRating` is one of: the digits 0 to 21, "U", "PG", "12", "12A", "15", "18", "R18", "G", "PG-13", "R", "NC-17", "TV-Y", "TV-Y7", "TV-G", "TV-PG", "TV-14", "TV-MA". Any other value shows no age badge.
- A series in the banner shows neither badge.

## Risks / Trade-offs

- [Storage for progress and My list is undecided] → the change is blocked on the storage decision in change `add-watch-progress-sync`. No requirement here changes with that choice.
- Open question: should Series get its own boards instead of reusing the Movies boards? Can be decided during implementation.
