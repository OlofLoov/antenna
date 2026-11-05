# 0029. Sync of watch progress, My list and recent searches

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- Builds on specs: 0004, 0011, 0012, 0013, 0016
- Needs from other specs: 0011 reads and writes progress and My list through this store and uses these thresholds; 0012 stores recent searches here with the 100-character cap; 0004's delete path removes the source's progress and My list entries.
- Blocked on: an ADR adding watch progress, My list entries and recent searches to the iCloud sync of ADR-0002, together with 0027's reminders, and fixing the conflict rule (the most recent change wins). The criteria assume that outcome.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-20

## Summary

For people who watch movies and series on more than one device. Once this ships, stopping a film on the iPad means the Apple TV offers to resume it, a series added to My list on the Mac shows up on the iPhone, and a search typed on one device appears under recent searches on the others. This spec defines what is stored and how two devices that disagree settle it; the screens that show it belong to 0011 (movies and series) and 0012 (search). It adds no screen, no way to clear history, and no progress for live TV.

## Design

Boards: none, no UI. 0011 and 0012 show Continue watching, My list, resume and recent searches.
Design rules that apply: none.

## Problem

0011 saves how far into a movie or episode the user got and lets them add titles to My list, and 0012 keeps recent searches, but nothing stores any of them yet, and 0012's recent searches stay on the device that typed them. Someone who stops a film on the iPad expects the Apple TV to offer to resume it, and syncing between devices tops the TiviMate wish list (`docs/research/tivimate-user-sentiment.md`). This spec gives 0011 and 0012 the storage and the rules so they do not have to invent them.

## Scope

In:
- Three kinds of synced record: how far into a title the user is, a My list entry, and a recent search.
- One shared rule set for "in progress" and "watched" that 0011's rows rely on.
- Settling disagreements between devices so every device ends up showing the same thing.
- Recent searches capped at ten, matching regardless of case and accents, shared across the account.
- Removing a source's progress and list entries when the user deletes that source on this device.
- Working offline and without iCloud.
- Moving recent searches that an earlier build kept on the device into the synced store, once.
- Telling the screens when something changed, including changes arriving from another device.

Out (explicitly):
- Any screen, including "mark as watched" or "clear history".
- When positions are saved during playback (0011).
- Building Continue watching rows, ordering them and choosing the next episode (0011).
- Search matching and the recent searches screen (0012).
- Progress for live TV, catch-up or timeshift.
- Progress for M3U, Stalker, Jellyfin or Channels DVR titles; their source specs add it.
- Trakt or any outside watch history service.
- Merging progress across two sources that point at the same provider.
- A device removing records on its own when it sees a source deleted elsewhere; the deleting device's removals sync instead.
- Clearing watch history or removing one title from Continue watching. Until a later spec adds it, the user cannot erase watch history.

## User flow

Nothing here is visible on its own; the user sees it through 0011 and 0012.

1. The user watches half a film on the iPhone and stops. Within a minute the Apple TV's Continue watching row shows the film with its progress bar, when both are online.
2. The user adds a series to My list on the Mac. It appears in My list on the iPad.
3. The user searches "north" on the Apple TV. The iPhone lists "north" under recent searches.
4. The user deletes a source on the iPhone. Its progress and My list entries go away on every device; recent searches stay.

## Acceptance criteria

### AC-2 Progress is saved and read back
Given a movie or episode from a source, on a device with or without a network or iCloud
When the screen saves the user's position, and later saves a new one
Then asking for that title's progress returns the latest position and length, and the store holds one entry for the title; nothing stored holds a link, username or password.

### AC-3a Devices that disagree settle on the same answer
Given two devices saved different progress for one title, added the same title to My list, or recorded the same search, before syncing
When both copies arrive on a device
Then the screens see one answer, the same on every device: the most recently saved progress, one My list entry, one recent search with the latest spelling; a position saved on this device after reading always replaces what it read.

### AC-4a In progress and watched mean the same everywhere
Given a title with a known length
When the screen asks whether it is in progress or watched, and where to resume
Then under 2% watched is neither and resumes at the start, from 2% up to 95% is in progress and resumes at the saved position, and 95% or more is watched and resumes at the start; a title with no known length is never in progress or watched and resumes at the start, and watching a finished title again reopens it.

### AC-5a A series shows progress for each of its episodes
Given progress saved for a movie and for two episodes of one series
When the screen asks for the progress within that series
Then it gets both episodes, most recent first, and not the movie.

### AC-6 Deleting a source removes its progress and list entries
Given progress and My list entries from two sources, and some recent searches
When the user deletes one source on this device
Then that source's progress and My list entries are removed on every device once synced, the other source's are untouched, and recent searches stay.

### AC-7 Progress waits for a source that has not synced yet
Given progress and My list entries arrived from iCloud before the source they belong to
When the screens read them, or save progress for another title
Then nothing is thrown away, so the user's history is there once the source arrives.

### AC-8a Add and remove from My list
Given a title from a source that is not in My list
When the screen adds it, and later removes it
Then the title is in My list after the first and gone after the second, including any duplicate copies from another device.

### AC-8c My list shows movies and series separately
Given My list holds movies, series and entries of other kinds
When the screen asks for the movies, or for the series
Then each list holds only that kind, most recently added first, and entries of other kinds are kept but appear in neither.

### AC-9a Recent searches stay short and tidy
Given the user has searched before
When a new search is recorded
Then recent searches list it first, treat the same words in different case or accents as one search keeping the latest spelling, ignore blank searches, cut very long ones to 100 characters, and keep only the ten newest.

### AC-11a Recent searches from an earlier build carry over
Given a device that kept recent searches locally from an earlier build
When the app starts with this store for the first time
Then those searches join the synced list in their old order, merged with any that arrived from other devices and capped at ten, and they are moved only once, even if the app was killed halfway.

### AC-13a Changes from another device show up without reopening the screen
Given a screen is watching the store for changes
When anything is saved, on this device or arriving from another
Then the screen is told, and reading again shows the change; every screen watching is told.

### AC-18 Progress follows the iCloud account
Given an iPhone, an Apple TV and a Mac on one iCloud account, and an iPad signed out of iCloud
When a film is half watched on the iPhone, a title added to My list and a search typed, and the devices are online
Then the Apple TV and the Mac show the same progress, list and recent searches once they are online, including writes the iPhone made offline after it reconnects, and the iPad keeps working with its own data and syncs nothing.

## Edge cases

- Offline or signed out of iCloud: every save works locally; sync catches up when possible.
- Progress can arrive before its source, or before the title list loads; it is kept and shown once the title is known (AC-7).
- Login not yet synced: progress and list entries are still stored and returned; 0011 decides what the screen shows.
- Two devices saving the same title without syncing in between: the one whose clock runs ahead wins.
- Two sources for the same provider keep separate progress. Deleting and re-adding a source starts its progress fresh.
- A title the player reports no length for always starts from the beginning.
- Credits skipped at 94%: the title stays in Continue watching.
- Years of history: thousands of titles. Nothing is pruned by age.
- Each Apple TV profile has its own progress, list and searches (ADR-0002).
- A source deleted on another device: its removals sync here; this device removes nothing on its own.
- Damaged or incomplete records from sync are ignored, never deleted, and never crash the app.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-2 | integration |
| AC-3a | core + integration |
| AC-4a | core |
| AC-5a | integration |
| AC-6 | integration |
| AC-7 | integration |
| AC-8a | integration |
| AC-8c | core + integration |
| AC-9a | core + integration |
| AC-11a | integration |
| AC-13a | integration |
| AC-18 | device (CloudKit cannot run in CI; manual multi-device check) |

## Open questions

- The thresholds are 2% and 95% with no absolute floor, so a title left at 94% stays in Continue watching. "Watched when fewer than n minutes remain" would change AC-4a.
- A title with no known length never resumes. Resuming from the saved position instead would change AC-4a.
- Progress includes the source in its identity, as 0011 does. Matching on the title alone would survive deleting and re-adding a source, and would change AC-6.
- Recent searches sync account-wide. Keeping them per device would stop an Apple TV showing what was typed on an iPhone, and would change AC-9a and AC-18.
- Saves use the device clock. Clamping how far ahead another device's time may be (for example 24 hours) can be decided in the plan.
- Clearing watch history is out with no follow-up spec yet, and history is never pruned. The owner may want a minimal "clear all" in scope here; that would add a criterion.

## Notes for the plan

- Three SwiftData records in `Apps/Shared/Persistence`, each with `id: UUID = UUID()`: progress (title id, series id, source id, position, duration, updated-at), list entry (title id, source id, added-at), recent search (query, updated-at). ADR-0002 rules: every property optional or defaulted, no unique attribute, no relationships, no `URL` column. Additive, lightweight migration.
- Value types and the pure merge, threshold, fold and cap rules live in AntennaCore (ADR-0005); one `ActivityStore` on the main context maps records to them and serves 0011 and 0012 (0012 injects a `RecentSearchesStore` protocol). Every read resolves duplicates; reads never write. Every write resolves first and deletes the losers in the same save.
- Keys: 0016 title ids plus source id. Ties: progress by latest updated-at, then higher position, then lower id string; list by earliest added-at, then lower id; searches by fold (trim, collapse whitespace, case and diacritic insensitive). A local progress write sets updated-at to the later of now and the survivor's time plus one millisecond.
- Secrets: no record or snapshot holds a credential, a URL or a path; title ids carry the host only. Writes refuse title ids containing `://` or `@`. The store logs nothing (ADR-0003).
- A failed save rolls back and the call returns normally; the next read does not show it.
- Fetching one title's progress or list state uses a predicate fetch, not the whole table. Budgets from the old draft: resolve over 5 000 progress rows under 500 ms in CI; a point read over 20 000 rows under 500 ms in CI; reading all progress under 250 ms in CI.
- Migration reads `UserDefaults` key `search.recents` (`[String]`, newest first), spaces migrated timestamps one second apart, merges with the cap in one save, then removes the key. A missing key means nothing to migrate.
- The change stream yields after any save on the container (local saves and CloudKit imports), a new stream per subscriber, nothing on creation.
- 0012 stores recents through the injected protocol. 0004's delete path calls the source removal after deleting the Keychain item and the source record, as 0014 does for the guide. Extra copies from sync are deleted on the next save.
- Malformed records (empty title id, missing source, negative or non-finite position or length) are skipped by reads and never deleted; a bad length reads as unknown.

## Dropped

- Split earlier (kept for history), so a failure names the rule it broke: AC-1 into AC-1a, AC-1b and AC-1c; AC-5 into AC-5a and AC-5b; AC-13 into AC-13a and AC-13b; AC-14 into AC-14a, AC-14b, AC-14c and AC-14d. Also the write half of AC-3b went to AC-3c, the toggle half of AC-8b to AC-8f, the ordering of AC-8c to AC-8d and its non-deletion to AC-8e, and the write half of AC-10 to AC-10b.
- Trimmed earlier: AC-12's 100 ms bound and AC-16's "no change within one second" were timing assertions that flake; AC-22's "streams finish when the store goes away" was flaky.
- Merged into AC-2: AC-12, AC-17.
- Merged into AC-3a: AC-3b, AC-3c, AC-8b, AC-10, AC-10b, AC-20.
- Merged into AC-4a: AC-4b, AC-4c.
- Merged into AC-5a: AC-5b.
- Merged into AC-8a: AC-8f.
- Merged into AC-8c: AC-8d, AC-8e.
- Merged into AC-9a: AC-9b, AC-9c, AC-9d.
- Merged into AC-11a: AC-11b, AC-11c.
- Merged into AC-13a: AC-13b, AC-22.
- Moved to the implementation plan: AC-1a, AC-1b, AC-1c, AC-14a, AC-14b, AC-14c, AC-14d, AC-15, AC-16, AC-19, AC-21, AC-23, AC-24.
