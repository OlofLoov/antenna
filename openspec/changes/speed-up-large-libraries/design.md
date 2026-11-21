# Design

## Context

The 2026-11-21 review of Movies, Series, Search and progress saves timed
each path on a Mac with 100 000 movies and 30 000 series whose rows carry
a five-name cast and a director. This change fixes the findings in that
review that were confirmed, one slice per pull request. No board changes;
no screen looks different. Design-system requirements followed: none
change.

Findings left to other work: provider logins in the URL cache, a library
per Mac or iPad window, and Keychain reads on the main actor (another
change), and keeping the catalogue on disk between launches (a feature
that needs its own proposal).

## Decisions

### People index in two parts

Options:
1. Keep one build over every title and memoize the name cleaning only.
2. Merge each new answer into the last index by hand, removing the row's
   names for that title and adding the answer's.
3. Split the index: the names in the list rows, built once per change of
   titles, and the names from info answers, built on top from at most
   20 000 answers each time one arrives.

Chosen: 3. Option 1 still walks 130 000 titles per answer. Option 2 needs
to know which names a title held before, per title, which is the memory
the build was trying to save. In option 3 a person's credits are the row's
credits for titles whose answer did not replace that role, plus the
answers' credits, merged in source order when a page or Search asks.

- `PeopleIndex.Rows` holds the two `ShelfIndex` values it was built from
  (no copy of their titles), each person's spelling and an array of
  32-bit refs: the title's position shifted left once, the low bit set for
  a director. Refs sort in source order with the cast before the director.
- `PersonName.split(_:cache:)` reads the field's UTF-8 bytes and keeps
  each cleaned part by its text, so a name that 40 titles carry is
  cleaned once per build.
- The rows build checks for cancellation every 1 024 titles.
  `ShelfLibrary` keeps one build task per pair of index revisions, shares
  it between Search and a person's page, and cancels it when the titles
  change.
- The spelling shown is the first title's in source order, as before. When
  the row's earliest title for a person was replaced by an answer, the
  row's first spelling still shows; the two only differ when a provider
  spells one person two ways.

### Sorted grids

Options:
1. Keep `localizedStandardCompare` and only move the sort off the main
   actor.
2. Work out a sort key per title once (the name folded for case and
   accents, each run of digits padded to eight places) and compare keys
   with `<`, off the main actor for long lists.

Chosen: 2. The 1.7 million locale-aware compares were most of the cost;
with keys a sort of 100 000 takes about a quarter of a second, and that
still runs away from the screen. Padding keeps "Movie 2" before
"Movie 10", as the Finder-style compare did. Names in scripts other than
Latin now sort by code point after folding instead of by the device's
collation; the spec asks only for case and accents to be ignored.

- `ShelfModel.titles(in:sortedBy:)` returns nil while a list of more than
  2 000 titles has no order for the current index. Shorter lists, such as
  most genres and every preview and UI test fixture, sort in place as
  before. `sort(in:by:)` sorts the long ones in an `@concurrent` function;
  two grids asking for one list share the sort.
- Until the new order is ready the grid keeps the order sorted before the
  titles last changed, so a second source finishing does not empty the
  grid. With no earlier order it shows a spinner, `<prefix>.grid.sorting`,
  under the header with the count from the rows.
- Sorted lists stay arrays of titles. They exist only for orders the user
  opened, on iPad and Mac.

### Progress saves

Options:
1. Keep inserting a new record per save and deleting the old one.
2. Update the winning copy in place and delete only the other copies.

Chosen: 2. Nothing in the records needs a fresh row per save; the insert
and delete came from writing every save the way a first save is written.
Duplicates from two devices still resolve as before: the save stamps the
survivor later than every copy it read, so the other copies lose and are
deleted in the same save, and a damaged copy is still never touched. A
two-hour movie now sends about 240 updates to one CloudKit record instead
of 240 creates and 240 deletes. No schema change.

Reads after a save:
- `ActivityStore.changes` yields for saves that name a progress, My list
  or recent search record, and for every change to the store's history.
  It buffers only the newest change, so a burst becomes one.
- The store's history posts a change for every save, local ones included,
  and names no records. A test on the simulator showed it: a favorite
  saved from another context read the store again. So each read keeps the
  newest history token, and a history change reads only when a
  transaction after that token touched an activity record. An iCloud
  import of progress still reads; the echo of a save this device already
  read, and a favorite or a guide setting, read nothing.
- Each change carries the time it was posted. `ShelfActivity` skips a
  change that a read since has seen, waits 250 ms, and checks again before
  reading. Its own save reads once, directly, as before, so playback and
  tests see the new position at once.
- `reload()` assigns only the lists that changed.

### Search

### Pictures and posters

### Memory and asks

## Measurements

Release build on this Mac (Apple silicon, other builds running), 100 000
movies and 30 000 series, 3 to 5 word names, five cast names and one
director per row from 15 000 people, 20 000 learned answers.

| Path | Before | After |
| --- | --- | --- |
| People index, rows | 7.4 s, +256 MB | 0.64 s, +15 MB, once per change of titles |
| People index, a new answer | 7.4 s (full build) | 46 ms |
| Sort 100 000 by Title | 1.51 s on main | 0.24 s off main |
| Sort 100 000 by Year | 1.81 s on main | 0.25 s off main |
