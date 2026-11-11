# Design

## Context

See proposal.md for why. Search reads channels from `channel-catalogue`, programmes from `guide-data` and titles from `xtream-vod-client`.

Boards, under `openspec/specs/design-system/boards/`: `TV-Search.dc.html`, `iPad-Search.dc.html`, `iPhone-Search.dc.html`, `TV-Search-Recents.dc.html`, `iPhone-Search-Recents.dc.html`, `iPhone-Search-Empty.dc.html`, `iPad-Search-OneCharacter.dc.html`, `iPad-Search-Loading.dc.html`, `iPad-Search-GuideLoading.dc.html`, `iPad-Search-Capped.dc.html`.

Not drawn: the "Later" row under what is on next on `iPad.dc.html` and the "Later:" line on `iPhone.dc.html`, both on the Live boards.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channels without a logo show initials”, “One search across everything”, “Accessibility identifiers follow the board”, “Text meets contrast minimums”.

User flow: the user opens Search and the field is ready, with recent searches listed when empty. From the second letter, results appear under Channels, In the guide, and Movies & series with counts. Chips under the field narrow to one section on iPad, Mac and iPhone. On Apple TV, swiping down from the keyboard reaches the first result.

## Goals / Non-Goals

**Goals:**
- 20 000 channels, seven days of guide for 2 000 channels and 10 000 titles index within 1 500 ms, a query within 300 ms, at most 150 MB resident, in a debug `swift test` on the same baseline as the catalogue. Not CI-gated.

**Non-Goals:**
- Searching descriptions, fuzzy matching, and syncing recents.

## Decisions

- `SearchIndex(channels:programmes:titles:)` is built from whatever is loaded. `results(for:now:)` works out on-air state and the seven-day horizon at query time, or the guide's end if sooner. Without guide data the guide section is absent.
- Matching: trim, collapse spaces, fold with `.diacriticInsensitive` and `.caseInsensitive`, split on spaces. Every token must be a substring of one field. Highlight each token's first occurrence. Queries are cut to 100 characters. Empty names are not indexed. Leading zeros are stripped as in the catalogue.
- Channel ranking bands: name starts with the whole query, a word starts with the first token, other name match, number prefix, group only; then name, number, source `sortOrder`. Programmes tie on channel number.
- Results update 300 ms after the last keystroke on an injected clock. The Live filter calls the same matcher with no delay.
- Recents go through an injected store (production: standard `UserDefaults`), never a SwiftData record, because per-device state stays out of sync.
- Result ids use the channel's row key, the programme's guide key plus start, or the Xtream title id, never a stream URL. Identifier prefix `search.`.
- Board deviations: “Channel rows share one anatomy” and “A current programme always shows its progress” do not apply to result rows; “Text stays above the platform caption floor”, the NOW and SERIES badges sit 2 to 4 pt under the caption floor; “Targets are large enough to hit”, chips and recent rows get a 44 pt hit area; “Live video keeps playing under overlays”, video keeps playing behind Search on Apple TV for 30 seconds, then the shell's pause rule takes over.
- Apple TV uses the system search screen and keyboard. Menu from a result returns to the keyboard. One swipe down from the keyboard reaches the first result. iPhone's Cancel returns to the previous tab, or Live.
- Caps: Channels shows 500 rows. In the guide shows four outside its chip. Day labels use the user's calendar and time zone, injected in tests.

## Risks / Trade-offs

- [Guide requirements depend on guide data being present] → without it the guide section is absent and those tests run against fixture programmes.
- [Substring matching across 20 000 channels on every keystroke] → the 300 ms debounce and the index budget keep it in check.

## Implementation decisions

Calls made while building, recorded here instead of asked.

- The index reads the guide's own snapshot (`SearchIndex(channels:guide:titles:now:)`) rather than a list of programmes per channel. The guide already stores each repeated title once per source, so the index names a text by where the guide keeps it and folds each distinct title once. Building from programme lists took 1.5 s in a debug build; this takes 0.97 s. UI test scripts and previews make their guide with `GuideIndex(programmes:)`, now public for that.
- The index keeps programmes from its build time to eight days ahead. A query still applies the seven days from its own `now`, so an index stays good for a day. Screens build it again whenever channels, the guide or titles change.
- Programmes are kept in result order at build time (start, then channel rank) and a query builds a result row only when the row is read. A query that matches 185 000 programmes answers in 0.16 s in a debug build instead of 4 s.
- A programme is a result once per guide, under the lowest-numbered channel that uses that guide. Two channels with their own guides that show the same programme still give two rows.
- A programme matches on its title or on its episode title, each a field of its own, so every word has to be in one of them.
- Channels found by number sort by number, so typing 104 lists 104, 1040, 1041 in that order. The other ranks sort by name, as the decisions above say.
- Benchmark, `SearchBenchmarkTests`, Apple M1, debug `swift test`: 20 000 channels, half-hour programmes for seven days on 2 000 of them (672 000) and 10 000 titles index in 0.97 s and use 47 MB; the slowest of ten queries takes 0.16 s.
- One `SearchModel` per window root keeps the query, chip and results across tabs, layouts and the title page. It builds the index off the main actor whenever a cheap signature of its inputs changes (channel count and ends, guide programme count and horizon, title count, source states, the day), so a finished source or guide is in the next results without a rebuild on every keystroke.
- Movies and series load the first time Search opens, as they do the first time their section opens, so titles are searchable without visiting Movies first.
- A series picked in Search opens its page over Search on every platform (a new page origin, `search`), and Back returns to Search with the query. The Movies and Series sections ignore a page opened from Search. Leaving Search closes such a page.
- iPhone Cancel empties the field and returns to the tab Search was opened from.
- Apple TV puts the system search field and keyboard (`searchable` in a navigation stack) under the shell's tab bar. tvOS gives no way to move focus onto that keyboard from code (`searchFocused` and `searchable(isPresented:)` are unavailable there), so selecting the Search tab leaves the highlight on the tab and one swipe down reaches the keyboard, as in a system tab bar. Menu from a result goes to the tab bar as it does from any tab's content, not back to the keyboard as decided above; one swipe up from the first row of results reaches the keyboard. A channel or a programme on now plays full screen through the shell's overlay pick, which also handles a channel outside the overlay's group. A later programme opens the Guide at it through the shell navigator.
- Escape on iPad uses `onKeyPress` in the field and a cancel shortcut elsewhere. The simulator does not deliver Escape to UI tests, so Escape needs a check with a hardware keyboard; Command-F, the arrows and Return are UI tested.
- The "Later" line (not drawn on the boards) is a row under Up next on iPad and Mac, with "Later" in the accent color in the time column, and a "Later: <day> <time> · <title>" line under the now-playing line on iPhone. The Live model keeps the picked programme and drops it when another channel tunes; the view hides it once the programme ends. Identifier `browse.later`, since it sits on the Live boards.
- From the Movies and Series sections (task 5.3 of `add-movies-and-series-browsing`): on iPhone a round search button in the section's top bar (`movies.search`, `series.search`) opens the Search tab set to that kind with the cursor in the field; on iPad and Mac the 220 pt toolbar field (same identifiers) hands its first keystroke to Search, which opens set to that kind with the text and the cursor in its own field. The window root gives the sections an `openSearch` environment value; Apple TV gives none, so its sections show no way into Search.
- Result rows scale their board sizes with the text size (`ScaledMetric` relative to body), so rows grow and the highlight follows at large sizes.
- Recent searches use the synced store that change `add-watch-progress-sync` already built (`ActivityStore.recentSearches`, `recordSearch`), read through `ShelfActivity`. See the spec conflict below.

### Spec conflict

This change's proposal and its decision above say recent searches stay on the device in `UserDefaults`, with syncing left to `add-watch-progress-sync`. That change has shipped its part: recent searches are synced SwiftData records, and the `search.recents` key in `UserDefaults` is carried over once and removed. Search writes to and reads from that synced store. The `search/recent-searches` requirement says nothing about where searches are kept, so it holds either way; the proposal's "kept on this device only" line and the `UserDefaults` decision are out of date and are left for the owner to reconcile when archiving.
