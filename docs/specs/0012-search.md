# 0012. Search across channels, guide, movies and series

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005
- Builds on specs: 0007, 0009, 0010, 0011, 0013, 0014, 0015, 0016
- Needs from other specs: 0010 shows a programme picked in Search as a "Later" line under what is on next (AC-8). The matching of AC-2 also drives 0010's list filter.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-21

## Summary

For anyone with more channels and titles than they can scroll through. Once this ships, one search field finds a channel by name or number, a programme on now or in the coming week, and a movie or series, without the user choosing where to look first. Results appear as they type, grouped and with the matching letters highlighted, and picking one plays it or opens the guide at that programme. It does not search descriptions, cast or genres, does not guess at misspellings, and keeps recent searches on this device (0029 shares them across devices).

## Design

Boards: `docs/design/boards/TV-Search.dc.html`, `docs/design/boards/iPad-Search.dc.html`, `docs/design/boards/iPhone-Search.dc.html`, `docs/design/boards/TV-Search-Recents.dc.html`, `docs/design/boards/iPhone-Search-Recents.dc.html`, `docs/design/boards/iPhone-Search-Empty.dc.html`, `docs/design/boards/iPad-Search-OneCharacter.dc.html`, `docs/design/boards/iPad-Search-Loading.dc.html`, `docs/design/boards/iPad-Search-GuideLoading.dc.html`, `docs/design/boards/iPad-Search-Capped.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-8, DR-10, DR-11, DR-13.
Not drawn: the "Later" row under what is on next on `docs/design/boards/iPad.dc.html` and the "Later:" line on `docs/design/boards/iPhone.dc.html` (AC-8), both on the 0010 boards.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

With hundreds of channels and thousands of titles, typing is faster than browsing, and better search is on TiviMate users' wish lists. Antenna has no search. One field has to find a channel, a programme later tonight and a movie.

## Scope

In:
- One search field per platform: the Search tab on Apple TV with the system's search screen, a Search section with a toolbar field on iPad and Mac, and a Search tab on iPhone.
- Searching channel names, numbers and groups; programme titles and episode titles for the next seven days; movie and series titles.
- Results as the user types, in three sections with counts and the matched text highlighted.
- Picking a result: watch the channel, open the guide at the programme, or play the title.
- On iPad, Mac and iPhone, chips that narrow results to Channels, Guide, Movies or Series. Apple TV always shows every section.
- Recent searches, kept on this device only.
- What Search shows with no results, while sources load, and when there are too many results to list.
- Keyboard use on Mac and on iPad with a keyboard.
- With no source at all, onboarding (0006) shows and Search cannot be reached.

Out (explicitly):
- Searching descriptions, cast or genre.
- Voice search beyond the keyboard's own dictation.
- Setting a reminder from a future programme.
- Syncing recent searches between devices (0029).
- Matching misspellings. Only case and accents are ignored.

## User flow

1. The user opens Search. The field is ready for typing; with nothing typed, recent searches are listed.
2. From the second letter, results appear: Channels, In the guide, and Movies & series, each with a count.
3. On iPad, Mac and iPhone, chips under the field narrow to one section. On Apple TV, swiping down from the keyboard moves to the first result.
4. Picking a channel, or a programme on now, plays that channel. Picking a later programme opens the guide at it on Apple TV; elsewhere the channel plays and the programme shows as coming up later. Picking a movie or series plays it as in 0011.

## Acceptance criteria

### AC-2 Find things the way you type them
Given channels "Northern News" and "Nordic One" (group "Northern Report"), a programme "True North" and a movie "Northbound"
When the user types "north", "NÖRTH" or "north news"
Then "north" and "NÖRTH" find all four, ignoring case and accents, and "north news" finds only "Northern News", because every word must appear in the same name, group or title; a channel found only by its group says "Matches <group>".

### AC-3 Find a channel by its number
Given channel 104, a movie "1917" and a programme titled "104"
When the user types "19", then "104"
Then "19" finds the movie "1917" but not channel 104; "104" finds channel 104 and every channel whose number starts with 104, ignoring leading zeros, and the programme "104" by its title.

### AC-4a Results grouped, best first
Given results of every kind
When the user looks at them
Then they appear under Channels, In the guide, and Movies & series, in that order, each with its count, and a section with nothing in it is left out; channels whose names start with what was typed come first, programmes run in start order so what is on now leads, titles starting with what was typed come first, and the matched letters are highlighted in every row.

### AC-6c Pick a channel or title to watch
Given a channel, movie or series in the results
When the user picks it
Then a channel starts playing, full screen on Apple TV, and in Live elsewhere, switching to All channels if it is not in the current group, with the search kept for when the user comes back; a movie or series plays as in 0011.

### AC-8 Pick a programme
Given a programme in the results
When the user picks it
Then a programme on now plays its channel as in AC-6c; a later one opens the guide at that programme on Apple TV (0009), and elsewhere plays its channel and shows the programme as "Later" with its day, time and title beneath what is on next, until the user changes channel or the programme ends.

### AC-10 Narrow to one kind
Given results on iPad, Mac or iPhone
When the user taps the Channels, Guide, Movies or Series chip
Then only that kind of result shows, with every guide match listed; each chip shows its count, All shows the total, a chip with nothing to show is greyed out and reads "0", and All brings every section back; Movies and Series chips appear only when Movies and Series do (0011).

### AC-11 Recent searches
Given the user has searched and picked a result more than ten times
When the field is empty on iPhone or Apple TV, or at any time on iPad and Mac
Then the ten latest searches are listed newest first, with searches that differ only in case listed once; a search is remembered when the user picks one of its results; picking a recent search runs it again.

### AC-12a Clear the field
Given a search with results on iPhone, iPad or Mac
When the user taps clear
Then the field empties and stays ready for typing, and iPhone shows recent searches again.

### AC-13 Nothing found
Given a search that finds nothing after every source has loaded
When the user looks at the results
Then they read "No results for “<query>”" with the hint "Check the spelling or try a channel number."

### AC-18 Seven days of guide
Given programmes that have ended, programmes in the next seven days, and programmes further out
When the user searches for them
Then only programmes on now or starting within seven days are found, each marked "NOW" or with its day and start time, its channel, and a catch-up mark when the provider offers catch-up.

### AC-20a Search with a keyboard
Given a Mac, or an iPad with a keyboard
When the user presses Command-F, the arrow keys, Return or Escape
Then Command-F puts the cursor in the field, the down arrow moves into the results and the arrows move between them, Return picks the focused result, and Escape clears the field, or with an empty field moves to the recent searches.

### AC-22 Very long result lists
Given a search with 600 matching channels and more than four matching programmes
When the user looks at the results in the All view
Then Channels lists the first several hundred and ends with "Showing <shown> of <total>" while its count shows the total, and In the guide shows the first few with "See all n", which lists the rest in place; Apple TV lists every programme.

## Edge cases

- A single letter shows no results yet.
- Before any source has loaded, Search says "Channels are still loading"; if some have not, the no-results message adds "Some sources are still loading."; while the guide loads, its section says so.
- When a source or its guide finishes loading while Search is open, the next keystroke includes it.
- A programme that starts or ends while results are open updates within a few seconds.
- A source whose login has not reached this device adds no channels or titles.
- A programme on air on one channel and later on another shows twice, on-air first.
- Two sources with the same channel name or number both show.
- Offline, search still covers everything already loaded; missing logos and posters get their stand-ins.
- Large text sizes grow the rows; highlights follow the text.
- VoiceOver reads section headers as headings and each result as its section, name and second line.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-2 | core |
| AC-3 | core |
| AC-4a | core + ui |
| AC-6c | ui |
| AC-8 | ui |
| AC-10 | ui |
| AC-11 | integration + ui |
| AC-12a | ui |
| AC-13 | ui |
| AC-18 | core |
| AC-20a | ui |
| AC-22 | core + ui |

## Open questions

- Decided: programme descriptions are not searched, not even behind a setting.
- Decided: channels rank by how well they match and then alphabetically, not by how often the user watches them (AC-4a).

## Notes for the plan

- `SearchIndex(channels:programmes:titles:)` is built from whatever is loaded; `results(for:now:)` works out on-air state and the seven-day horizon at query time (or the guide's end, if sooner). Until 0014 delivers guide data the guide section is absent and its criteria are blocked, not failed.
- Matching: trim, collapse spaces, fold with `.diacriticInsensitive` and `.caseInsensitive`, split on spaces; every token must be a substring of one field. Highlight each token's first occurrence. Queries are cut to 100 characters; empty names are not indexed. Leading zeros are stripped as in 0013.
- Channel ranking bands from the dropped AC-4b: name starts with the whole query, a word starts with the first token, other name match, number prefix, group only; then name, number, source `sortOrder`. Programmes tie on channel number.
- Results update 300 ms after the last keystroke on an injected clock. 0010's filter calls the same matcher with no delay.
- Budget from the dropped AC-14: 20 000 channels, seven days of guide for 2 000 channels and 10 000 titles index within 1 500 ms, a query within 300 ms, at most 150 MB resident, debug `swift test`, same baseline as 0013, not CI-gated.
- Recents go through an injected store (production: standard `UserDefaults`), never a SwiftData record.
- Result ids use the channel's row key, the programme's guide key plus start, or the 0016 title id, never a stream URL (ADR-0003). Identifier prefix `search.`.
- Board deviations: DR-6 and DR-7 do not apply to result rows; DR-4, the NOW and SERIES badges sit 2 to 4 pt under the caption floor; DR-5, chips and recent rows get a 44 pt hit area; DR-1, video keeps playing behind Search on Apple TV for 30 seconds, then 0015 takes over.
- Apple TV uses the system search screen and keyboard; Menu from a result returns to the keyboard; one swipe down from the keyboard reaches the first result. iPhone's Cancel returns to the previous tab, or Live.
- Caps: Channels shows 500 rows; In the guide shows four outside its chip. Day labels use the user's calendar and time zone, injected in tests.

## Dropped

- Moved to the implementation plan: AC-6a, AC-9a, AC-12b, AC-12d, AC-14, AC-15, AC-17.
- Merged into AC-2: AC-1, AC-16.
- Merged into AC-4a: AC-4b, AC-4c, AC-4d, AC-5.
- Merged into AC-6c: AC-6b, AC-9b.
- Merged into AC-13: AC-21.
- Merged into AC-18: AC-7.
- Merged into AC-20a: AC-12c, AC-20b, AC-20c.
- Merged into AC-22: AC-19.
