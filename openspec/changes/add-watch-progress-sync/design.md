# Design

## Context

Boards: none, no UI. `add-movies-and-series-browsing` and `add-search` show Continue watching, My list, resume and recent searches.

Design-system requirements that apply: none.

## Goals / Non-Goals

**Goals:**
- One store that the movies, series and search screens share, so neither invents its own rules.
- Pure merge, threshold, fold and cap rules in AntennaCore, testable without SwiftData.

**Non-Goals:**
- Any screen.
- Pruning history by age.
- Removing records on this device in response to a deletion seen elsewhere.

## Decisions

- Three SwiftData records in `Apps/Shared/Persistence`, each with `id: UUID = UUID()`: progress (title id, series id, source id, position, duration, updated-at), list entry (title id, source id, added-at), recent search (query, updated-at). As CloudKit sync requires, every property is optional or defaulted, with no unique attribute, no relationships and no `URL` column. Additive, lightweight migration.
- Each of the three records also carries `profileID: UUID?` (change `add-profiles`); nil means the first profile. Reads and duplicate resolution are per profile.
- Value types and the pure rules live in AntennaCore. One `ActivityStore` on the main context maps records to them and serves the movies and search screens. Search injects a `RecentSearchesStore` protocol. Every read resolves duplicates and never writes. Every write resolves first and deletes the losers in the same save.
- Keys: `xtream-vod-client` title ids plus source id. Ties: progress by latest updated-at, then higher position, then lower id string. List by earliest added-at, then lower id. Searches by fold (trim, collapse whitespace, case and diacritic insensitive). A local progress write sets updated-at to the later of now and the survivor's time plus one millisecond.
- Secrets: no record or snapshot holds a credential, a URL or a path. Title ids carry the host only. Writes refuse title ids containing `://` or `@`. The store logs nothing.
- A failed save rolls back and the call returns normally. The next read does not show it.
- Fetching one title's progress or list state uses a predicate fetch, not the whole table. Budgets: resolve over 5,000 progress rows under 500 ms, a point read over 20,000 rows under 500 ms, reading all of 5,000 rows under 250 ms. They are a benchmark suite run with `ANTENNA_BENCHMARKS=1`, not gated in CI, like the guide's: on a shared CI simulator a 250 ms bound on SwiftData reads would fail on load, not on code. An iPhone 17 simulator on an M-series Mac takes 11 ms, 125 ms and 2 ms. Reading all of 20,000 rows takes 460 ms there, so a screen that shows all history should not read it on every change.
- Migration reads `UserDefaults` key `search.recents` (`[String]`, newest first), spaces migrated timestamps one second apart, merges with the cap in one save, then removes the key. A missing key means nothing to migrate.
- The change stream yields after any save on the container (local saves and CloudKit imports), a new stream per subscriber, nothing on creation.
- `source-management`'s delete path calls the source removal after deleting the Keychain item and the source record, as `guide-data` does for the guide. Extra copies from sync are deleted on the next save.
- Malformed records (empty title id, missing source, negative or non-finite position or length) are skipped by reads and never deleted. A bad length reads as unknown.
- No clamp on how far ahead another device's clock may be. A save on this device stamps just after the copy it replaces, so the user's latest save wins however far ahead the other clock ran; a clamp would only matter for copies nobody saves over, and those show the other device's answer on every device anyway.
- The rules are `WatchProgress`, `ListEntry` and `RecentSearch` in `AntennaCore/Activity`, each with a `resolve` that returns the winners and the indices a write deletes.

## Risks / Trade-offs

- Open question: the thresholds are 2% and 95% with no absolute floor, so a title left at 94% stays in Continue watching. "Watched when fewer than n minutes remain" would change the threshold requirement.
- Open question: a title with no known length never resumes. Resuming from the saved position instead would change the threshold requirement.
- Open question: progress includes the source in its identity, as movies and series browsing does. Matching on the title alone would survive deleting and re-adding a source, and would change the source deletion requirement.
- Open question: recent searches sync account-wide. Keeping them per device would stop an Apple TV showing what was typed on an iPhone, and would change the recent searches and account requirements.
- Open question: clearing watch history is out with no follow-up yet, and history is never pruned. The owner may want a minimal "clear all" in scope here, which would add a requirement.
- [Two devices saving the same title without syncing in between] → the one whose clock runs ahead wins.
- [CloudKit cannot run in CI] → the account requirement is checked by hand on several devices.
