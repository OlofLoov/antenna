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

### Progress saves

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
| Sort 100 000 by Title | 1.51 s on main | |
| Sort 100 000 by Year | 1.81 s on main | |
