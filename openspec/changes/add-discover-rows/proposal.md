# Proposal

## Why

From the owner's list: "Trending; Recents; Categories ny serie movies channel". "Ny" is Swedish for "new", so the third item is read as a New category for series, movies and channels.

> As a movie and series watcher, I want to see which of the films everyone is talking about this week my subscription has.

> As a movie and series watcher, I want to get back to something I watched last week, even if I finished it.

> As a living-room viewer, I want to find the channels my provider added without scrolling through 400 of them.

Today Movies and Series have Continue watching, My list, a New titles banner, Recently added and one row per category. Recents in Live lists channels only, per device. Nothing shows what is popular, a finished film disappears from every row, the Recently added row cannot be opened as a grid, and a new channel is buried in All channels.

After this change Movies and Series gain a Trending row (TMDB's weekly list, only the titles the user's sources have), a Recently watched row per profile, and See all on Recently added. Live gains a New group of channels first seen in the last seven days.

## What Changes

- Trending row in Movies and Series: TMDB's trending list for the week, matched on the device against the user's catalogue, at most 20, hidden below three matches or with lookups off. The request carries no title or anything about the user.
- Recently watched row in Movies and Series, from the profile's synced watch progress, finished titles included.
- See all on Recently added, opening the newest-first grid.
- A New group in Live and the Apple TV overlay, after Recents, for channels this device first saw in the last seven days. A source's first load on a device counts as known.

Out of scope:
- A Home or For you tab mixing channels and titles (open question in design.md).
- Syncing channel Recents between devices.
- Merging provider categories such as "EN | Action" and "DE | Action" into common genres. Movies and series by category already exist; merging well needs a genre for every title, which means matching whole catalogues.
- A "new episodes" mark on series the user watches. The provider's last-changed date also moves for edits that add no episode.
- Rank numbers on Trending posters, and trending channels.
- Removing a title from Recently watched.

## Capabilities

### New Capabilities
- `new-channels`: the New group in Live and the Apple TV overlay, and what the device remembers to build it.

### Modified Capabilities
- `movies-and-series-browsing`: Trending, Recently watched and See all on Recently added, and the row order.

## Impact

- AntennaCore: matching a trending list against the catalogue (`TitleMatch` from `add-title-metadata`), the Recently watched list from progress, the seen-channels memory and the New group.
- Apps: the Movies and Series rows, the Live group list on iPhone, iPad and Mac, the Apple TV overlay groups.
- The lookup service gains `/v1/trending`.
- Boards: new `iPhone-Movies-Discover`, `iPad-Movies-Discover`, `TV-Movies-Discover`, `iPhone-Live-New`, `iPad-Live-New`, `TV-Overlay-New`.
- Depends on `add-title-metadata` for Trending only: the lookup service, the TMDB agreement, the lookups switch and the matching rule.
- Ships without external data: Recently watched, See all on Recently added and the New channels group. Task groups 2 and 3 can merge before `add-title-metadata` is built.
