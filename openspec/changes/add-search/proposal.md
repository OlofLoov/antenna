# Proposal

## Why

With hundreds of channels and thousands of titles, typing is faster than browsing, and better search is on TiviMate users' wish lists. Antenna has no search. One field has to find a channel, a programme later tonight and a movie.

User stories served:
- "As a user, I want one search across channels, guide programmes, movies and series, so I do not have to know where something lives."

## What Changes

- One search field per platform: the Search tab on Apple TV with the system's search screen, a Search section with a toolbar field on iPad and Mac, and a Search tab on iPhone.
- Search covers channel names, numbers and groups; programme titles and episode titles for the next seven days; movie and series titles.
- Results come as the user types, in three sections with counts and the matched text highlighted.
- Picking a result watches the channel, opens the guide at the programme, or plays the title.
- On iPad, Mac and iPhone, chips narrow results to Channels, Guide, Movies or Series. Apple TV always shows every section.
- Recent searches, kept on this device only.
- States for no results, sources still loading, and too many results to list.
- Keyboard use on Mac and on iPad with a keyboard.
- With no source at all, onboarding shows and Search cannot be reached.

Out of scope:
- Searching descriptions, cast or genre, even behind a setting.
- Voice search beyond the keyboard's own dictation.
- Setting a reminder from a future programme.
- Syncing recent searches between devices (change `add-watch-progress-sync`).
- Matching misspellings. Only case and accents are ignored.
- Ranking channels by how often the user watches them.

## Capabilities

### New Capabilities
- `search`: one search across channels, guide programmes, movies and series on every platform, with recent searches.

### Modified Capabilities
None.

## Impact

- A search index and matcher in the core package; Search screens on every platform.
- The Live screen on iPhone, iPad and Mac uses the same matcher for its filter, and shows a later programme found in Search and watched from the guide as a "Later" line under what is on next.
- Depends on: `channel-catalogue`, `guide-data`, `tvos-shell`, `xtream-vod-client`, change `add-tv-channel-overlay`, change `add-tv-guide-grid`, change `add-live-tv-on-iphone-ipad-mac`, change `add-movies-and-series-browsing`.
