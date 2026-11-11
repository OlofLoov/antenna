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
