# Design

## Context

See proposal.md for why. What exists on 2026-11-19:

- The provider's cast and director arrive from `get_vod_info` and `get_series_info`, one call per title, as free text with no ids (`xtream-vod-client/vod-info`). The app makes that call for the banner's titles, for each title the Apple TV highlight rests on, and for each title page. Answers stay in memory for the 100 most recent titles (`ShelfModel.keptLimit`).
- The list calls `get_vod_streams` and `get_series` are what the shelf index is built from. The decoder reads no names from them. The fixtures under `Packages/AntennaCore/Tests/AntennaCoreTests/Fixtures/Xtream/` carry none either: `vod_streams.json` and `series.json` have ids, names, posters, dates, ratings and categories only, and `vod_info.json` has no cast. Many panels do send `cast`, `director` and `genre` on `get_series` rows, and a few send `cast` or `director` on `get_vod_streams` rows; nothing in the repo relies on either.
- Playlists (M3U) carry a name, a logo and a group per entry. They have no cast, so playlist titles show no names and appear on no person page.
- The title page shows "Cast …" and "Director …" as two cut text lines (`TitlePage.Credits`), and the About page repeats them.
- `ShelfLibrary.page` holds one title page at a time, shown over its section or over Search.
- Search shows Channels, In the guide, and Movies & series, with chips to narrow on iPhone, iPad and Mac.

Boards, under `openspec/specs/design-system/boards/`:
- `iPhone-Person.dc.html`, `iPad-Person.dc.html` (iPad and Mac), `TV-Person.dc.html`: the person page, with initials, the count line and the note.
- `iPhone-Title-Cast.dc.html` and `TV-Title-Cast.dc.html`: cast and directors as chips.
- `iPhone-Search-People.dc.html`: the People section.
- Follows: `iPhone-Title`, `iPad-Title`, `TV-Title`, `iPhone-Movies-Rows`, `iPad-Movies-Rows`, `TV-Movies-Rows`, `iPhone-Search`, `iPad-Search`, `TV-Search`.
- Not drawn: the chips on iPad and Mac (the iPhone chips under the description in the content column), People on iPad, Mac and Apple TV Search (a section after Movies & series in each platform's result layout, rows as the iPhone board), and the empty person page (the header and one line of muted text).

Design-system requirements that apply: "Focus is the lifted white card", "Targets are large enough to hit" (44 pt chips), "Channels without a logo show initials" (the same initials tile for a person), "One search across everything", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled".

## Goals / Non-Goals

**Goals:**
- Movies and series by actor or director with no provider request beyond what the app already makes.
- Never a title the user cannot play.
- Works with no server of ours.

**Non-Goals:**
- A full person profile or photos.
- A complete filmography for providers that send names only in details answers.

## Decisions

### 1. No lookup service for now (owner, 2026-11-19)

Options considered:
- **Wait for the title-info server** and build the change as first written: TMDB filmographies matched against the catalogue, photos, People from TMDB in Search. Complete pages, but nothing ships until the server, the TMDB agreement and `add-title-metadata` land.
- **Match by provider names now, keep the TMDB part for later (chosen).** The owner decided on 2026-11-19 not to run the server for now. Provider names give useful pages today on panels that send names in their lists, and pages that fill out with use elsewhere. The TMDB part stays in tasks.md under "Later" and the change is not archived while those tasks are open.

When the server comes, TMDB's credits replace provider names on matched titles and the person page gains a photo and the full filmography (see "Later" below). The provider-name index stays as the fallback for unmatched titles and with lookups off.

### 2. Where the names come from

The shelf index has only catalogue fields, and the per-title info call is the only place every panel sends cast. A filmography from the info call alone would need a request per title.

Options considered:
- **(a) Names from info answers the app already gets, kept and grown as the user browses.** No extra requests. A person's page lists only titles the user has looked at, which is thin at first.
- **(b) Names from the list rows.** Free, catalogue-wide, and complete for panels that put `cast` and `director` on `get_series` or `get_vod_streams` rows. Nothing for panels that do not.
- **(c) A bounded background fetch** of `get_vod_info` for, say, 200 titles a day. Panels rate-limit and ban accounts for bursts of info calls, the user did not ask for the traffic, and 200 a day covers a 40,000-title catalogue in half a year. Ruled out; it would also break `browse-by-person/a-person-s-page-never-asks-the-provider`.

Chosen: **(b) and (a) together.** The decoder reads `cast` (else `actors`) and `director` on both row kinds (`xtream-vod-client/names-on-list-rows`), carried on `ShelfTitle.cast` and `ShelfTitle.director`. Every info answer the app receives adds its names to `LearnedCredits`, keyed by `ActivityKey`, whichever screen asked. `browse-by-person/a-person-s-page-never-asks-the-provider` stands as written: the page reads the index and never calls the provider.

A title page prefers the info answer's names, and falls back to the row's when the answer has none.

Learned names are kept in `Caches/people/credits.json`: per title the source id, title id, names, year and the date learned; entries older than 30 days dropped on load, at most 20,000 titles with the oldest dropped first, entries of deleted sources dropped when the library's sources change. Written at most every five seconds while names arrive. A file that fails to decode reads as empty. Names are provider text, not secrets or stream links. Caches, not UserDefaults, because 20,000 entries is too large for defaults and losing them only thins the pages.

### 3. How names are normalized and matched

`PersonName` in AntennaCore:

- **Splitting.** A provider field is split at `,`, `/`, `|`, `;`, `·` and line breaks. "&" and "and" are not separators: a duo credit is rare and splitting would invent people.
- **Cleaning each part.** Trimmed; a trailing part in brackets dropped ("Jonas Reeve (voice)"); runs of spaces made one.
- **Junk.** Dropped when, once folded, the part is empty, has no letter, is longer than 60 characters (a description pasted into the field), or is one of `n/a`, `na`, `none`, `null`, `unknown`, `nil`, `-`, `tba`, `tbd`, `various`.
- **Key.** `TitleName.folded` (case and accents ignored), then dots and apostrophes removed and hyphens made spaces, so "J.J. Abrams" and "JJ Abrams" meet, and "Zoë" meets "ZOE".
- **"Last, First".** Not reordered. In a comma list, "Holt, Mira" cannot be told from two single-name people, and reordering would merge strangers. A provider that writes names last-first everywhere still matches itself.
- **Display.** The spelling of the first title in source order that names the person.
- **Repeats.** A name listed twice in one title counts once; a person who acts and directs in one title shows in both rows.
- **Limits.** At most 15 chips: the first 14 cast names when there are directors, then up to the remaining room of directors (at least one), else 15 cast names. The index keeps every name.
- **Collisions.** Two different people with the same name merge. Without ids there is no way to tell them apart; the risk is accepted and written down here.

`PeopleIndex` maps keys to people with their credits (`ActivityKey`, kind, role). Built off the main actor with `@concurrent` from both shelves' titles and the learned names, rebuilt when either shelf's index or `LearnedCredits` changes, with the same newest-build-wins rule as `ShelfIndex`.

### 4. The person page

`PersonPage` in AntennaCore (the rows and words), `PersonPageLayout` (components: `Phone`, `Pad`, `Television`) and `PersonScreen` (screen). Header `person.header`: an initials circle, the name, and "Acting · 9 in your sources" (`person.count`), where the department is Directing when the person has more directing credits than acting ones. Rows `person.row.movies` (acted, movies), `person.row.series` (acted, series), `person.row.directed` (directed, both kinds), posters drawn with `ShelfView.PosterCard` at the section's poster size, identifiers `person.row.<row>.card.<title id>`. Back is `person.back`, the whole page `person.root`. Order: newest first by the year from the info answer or the year in the name (`TitleName.clean`), then by added date, undated last in source order. A title on two sources shows once per source, as Movies does.

The note `person.note`, muted under the rows: "Only titles whose cast your provider has sent are here. More appear as you browse." It shows when a loaded title of either kind has no names known yet, which is true for any panel that sends names only in details. The empty page (`person.empty`): "Nothing with <name> in your sources."

People's names are provider text: never in the string catalog, wrapped in a first-strong isolate inside localized lines, and laid out with the reading direction of their own script.

### 5. Navigation

`ShelfLibrary.page` becomes a stack, `stack: [LibraryPage]` with `LibraryPage` either `.title(TitleRoute)` or `.person(PersonRoute)`. `page` and `person` read the top. The stack's first entry sets the section and origin, and every later entry shows in the same place: over Movies, Series or Search. `closePage()` pops one level; `closeAll()` empties it (a deleted source, switching section, Top Shelf links, App Intents). Every check that meant "no title page shows" reads `stack.isEmpty`. A title page under a person page keeps its `TitleModel`, so going back shows it without loading. `returningPerson` holds the key of the name that opened a person page, so the chip takes focus on Apple TV and scrolls into view elsewhere when the page closes. The stack is not capped; each level is one user action.

On iPhone the person page shows in place of the title page inside the Movies or Series tab and the tab bar stays. On iPad and Mac it replaces the content column. On Apple TV it is its own screen with the tab bar hidden, as `tvos-shell/the-tab-bar-stays-hidden-on-a-title-page` does for title pages.

### 6. Chips on the title page

`TitlePage.CastChips` replaces the cut Cast and Director text lines on iPhone, iPad, Mac and Apple TV; the About page keeps the full text. The chips are the provider's names only. Names a database match fills in (`add-title-metadata`) stay in the About text and get no chips, since the people index has none of them and their pages would be empty. Heading "Cast and crew", one horizontally scrolling row of 44 pt capsule chips (`title.cast.<index>`), the director chips last with a muted "Director" after the name. On Apple TV the row sits under the buttons, its own focus section, with the lifted white focus card. VoiceOver reads "Mira Holt, button" and "Sanna Weiss, Director, button". More now opens only when the description is cut, since the names no longer cut.

### 7. People in Search

`PeopleIndex.search(_:)` takes a `SearchQuery` and returns up to three people for whom every typed word starts a word of the folded name, ordered by title count, then name. Shown as `search.section.people` after Movies & series in the All view only (on Apple TV, which has no chips, always), rows `search.person.<index>` drawn by `SearchRow.Person` with initials, name and the count line, on every platform's result layout. The section follows Search's own 300 ms pause and two-letter minimum, and a person alone counts as a result, so the no-results message stays away. Picking a person opens their page over Search; Back returns to Search with the query kept. Nothing leaves the device, so no lookups switch applies.

## Later: with the lookup service

Waits on the title-info server; kept here from the first design so the work is not lost.

- `/v1/person/{id}` on the lookup service returns name, department, photo path and `combined_credits` reduced to `{tmdbID, kind, title, original title, year, role}`, newest first, capped at 500. The app matches it against the loaded catalogue with the Trending matcher from `add-discover-rows` (provider TMDB id first, else `TitleName.clean` plus year within one, ambiguous names skipped). A matched title's chips carry TMDB person ids and open the TMDB filmography; unmatched titles keep provider names.
- Photo from TMDB's image CDN at `w185` through the poster cache, and "Filmography from TMDB" under the name.
- Filmographies in `Caches/people/<tmdb id>.json` for seven days, at most 200 files, deleted when lookups are turned off; offline shows what was kept or "You're offline" with Retry; a failure shows "Could not load this filmography" with Retry.
- `/v1/people?query=` calls TMDB `/3/search/person`, keeps the five most popular with their credits. The app sends the query after 500 ms without a keystroke and three characters, never with lookups off or offline, and merges those people with the provider-name ones.
- What leaves the device is typed text. The Settings footer from `add-title-metadata` becomes "Titles and people you open, and names you search for, are looked up in TMDB.", and the Privacy Policy (`antenna-website/the-privacy-policy-rules-out-tracking`) names person pages and names typed in Search among what the movie info service receives. The service logs nothing, so "Data Not Collected" holds. The first version of this change already wrote that footer line on `iPhone-Settings-Lookups` and `TV-Settings-Lookups`; it stays, since the footer ships only with the lookup service.
- Owner's open questions from the first design still apply then: People from TMDB in Search given it sends typed text (recommend yes, behind the switch), and no biography.

## Risks / Trade-offs

- Pages are thin on panels that send names only in details. The note says so, and the page fills out with use.
- Two people with the same name merge. Accepted until TMDB ids arrive with the lookup service.
- Names in a script the provider transliterates differently across titles do not meet.
- 20,000 learned titles at about 200 bytes each is a 4 MB cache file. It is read once per launch, off the main actor.
- Building the index for 50,000 titles with names is a few hundred thousand dictionary inserts; it runs off the main actor and only when a shelf or the learned names change.

## Migration Plan

Additive. One new cache file. No SwiftData change.

## Open Questions

None for the provider-names part. The owner's choice of no server is recorded in decision 1.
