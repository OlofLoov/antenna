# Design

## Context

See proposal.md for why. What exists on 2026-11-13:

- The provider's cast and director arrive only from `get_vod_info` and `get_series_info`, one call per title, as a comma-separated string with no ids (`xtream-vod-client/vod-info`). Some panels also put `cast` on `get_series` rows; it is not decoded. Plain playlists have no cast.
- `add-title-metadata` matches a title when its page opens and brings TMDB credits (top 15 cast and the directors) with person ids.
- `add-discover-rows` adds a matcher from a list of TMDB entries to the loaded catalogue for Trending.
- Search shows Channels, In the guide, and Movies & series, with chips to narrow on iPhone, iPad and Mac.

Boards, under `openspec/specs/design-system/boards/`:
- New: `iPhone-Person.dc.html`, `iPad-Person.dc.html` (iPad and Mac), `TV-Person.dc.html`: the person page. `iPhone-Title-Cast.dc.html` and `TV-Title-Cast.dc.html`: cast and crew as chips on a matched title's page. `iPhone-Search-People.dc.html`: the People section.
- Follows: `iPhone-Title-Scores`, `iPad-Title-Scores`, `TV-Title-Scores`, `iPhone-Movies-Rows`, `iPad-Movies-Rows`, `TV-Movies-Rows`, `iPhone-Search`, `iPad-Search`, `TV-Search`.
- Not drawn: the cast chips on iPad and Mac (the iPhone chips under the plot in the content column), People on iPad, Mac and Apple TV Search (a section after Movies & series in each platform's existing result layout), and the person page's empty and offline states (the header with one line of muted text, and Retry where the design system's error pattern puts it). Draw these before task group 4.

Design-system requirements that apply: "Focus is the lifted white card", "Targets are large enough to hit" (44 pt chips), "Channels without a logo show initials" (the same initials tile for a person without a photo), "One search across everything", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled" (the page lists only the user's own titles; TMDB photos are fetched, never bundled).

## Goals / Non-Goals

**Goals:**
- Movies and series by actor with no provider requests beyond what the app already makes.
- Never a title the user cannot play.

**Non-Goals:**
- A full person profile. Browsing people with lookups off.

## Decisions

### 1. Cast for whole catalogues comes from TMDB filmographies, not provider details

Options considered:
- **Call `get_vod_info` for every title** to collect cast strings. A 40,000-title source means 40,000 requests; panels rate-limit and ban accounts for less. Ruled out.
- **Collect cast as the user opens pages.** No extra requests, but a person's page would list only titles the user had already opened, which is the opposite of discovery.
- **Decode `cast` on Xtream series rows.** Free for series on panels that send it, nothing for movies or playlists, and names without ids collide ("Chris Evans").
- **Ask TMDB for the person's filmography and match it locally (chosen).** One request per person page. `/v1/person/{id}` on the lookup service returns name, department, photo path and `combined_credits` reduced to `{tmdbID, kind, title, original title, year, role}`, sorted newest first. The app matches it against the loaded catalogue with the same matcher as Trending: provider TMDB id first, else `TitleName.clean` plus year within one, skipping ambiguous names. A title on two sources shows once, from the first source in the user's order.

Limits: one person request per page open, none while a kept answer is under seven days old; credits capped at 500 entries per person on the service (enough for prolific actors, keeps the answer under about 60 KB); at most 15 names on a title page.

### 2. Where the names come from

A matched title's page shows TMDB's credits: cast in billing order up to 14, then the first director, as chips. Identifiers `title.cast.<index>`, each opening `person.root` with the TMDB person id. An unmatched title keeps the provider's text line from `title-detail-and-episode-picker/what-the-title-is-about`. Matching a provider name to a TMDB person by name alone was rejected: common names collide and the page would show someone else's films.

### 3. The person page

`PersonPage` in `Apps/Shared/Views/` owns the request and the match; `PosterRow` from the Movies screen draws the rows. Rows: `person.row.movies` (acting, movies), `person.row.series` (acting, series), `person.row.directed` (directing, both kinds). A title in two rows (acted in and directed) shows in both. Header: `person.header`, photo from TMDB's image CDN at `w185` through the existing poster cache, initials otherwise. "Filmography from TMDB" sits under the name as the credit for this page.

Navigation: pushed on the Movies or Series stack on iPhone, replaces the content column on iPad and Mac, its own screen on Apple TV with the tab bar hidden, as `tvos-shell/the-tab-bar-stays-hidden-on-a-title-page` does for title pages. Back restores the title page or Search with the picked name focused or in view. A title page opened from a person page and then another person page stack; the stack is not capped, since each level is one user action.

### 4. People in Search

`/v1/people?query=` on the service calls TMDB `/3/search/person`, keeps the five most popular, and returns each with their credits in the same reduced form. The app matches each person's credits against the catalogue and keeps up to three with at least one match, ordered by match count. It sends the query after 500 ms without a keystroke and at least three characters, cancels on the next keystroke, and never with lookups off or offline. The section is `search.people`, rows `search.person.<index>`.

What leaves the device is typed text. The Settings footer from `add-title-metadata` says so ("Titles and people you open, and names you search for, are looked up in TMDB."), edited in that change's delta and boards in this PR, and the Privacy Policy names it. The service logs nothing, so "Data Not Collected" holds by the same reasoning as `add-title-metadata` decision 1.

Options considered: matching people locally from cached filmographies (only finds people the user already opened), and a People chip (adds a fifth chip on iPhone for a section that holds three rows).

### 5. Kept on the device

`Caches/people/<tmdb id>.json` with the reduced credits and the fetch date, used for seven days, at most 200 files with the oldest removed first, deleted when lookups are turned off. Matches are recomputed on each open, so a source that gains a title shows it the next time without a new request.

## Risks / Trade-offs

- Name matching misses titles whose provider names are in another language than TMDB's title and original title. They are left out rather than guessed.
- Search text reaches the lookup service. It is the one place user-typed text leaves the device; the delay, the minimum length and the switch keep it to deliberate searches.
- A person with hundreds of credits and a large catalogue means matching 500 entries against tens of thousands of titles; the catalogue's name index from `add-discover-rows` keeps it to dictionary lookups.

## Migration Plan

Additive. New cache folder only.

## Open Questions

Open questions for the owner, each with a recommendation:

1. **People in Search at all, given it sends typed text?** Recommend yes, behind the same switch, with the pause and three-letter minimum.
2. **Directors only, or writers too?** Recommend directors only for now; writers rarely drive what people pick.
3. **Biography on the person page?** Recommend no: the page is for finding something to watch, and a biography is one more TMDB field to cache and translate.
