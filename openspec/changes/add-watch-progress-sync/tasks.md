# Tasks

## 1. Rules in AntennaCore

- [x] 1.1 Add the value types and the merge rules for progress, list entries and searches, and verify core tests for each tie-break
- [x] 1.2 Add the in-progress and watched thresholds and the resume position, and verify core tests at 1.9%, 2%, 94.9%, 95% and unknown length
- [x] 1.3 Add the search fold, the 100-character cut and the cap of ten, and verify core tests for case, accents, blanks and overflow

## 2. Records and store

- [x] 2.1 Add the three synced records and the store that resolves on read and deletes losers on write, and verify integration tests that one entry remains and no record holds a link or credential
- [x] 2.2 Add per-series progress and My list by kind, and verify integration tests for ordering and other kinds kept but hidden
- [x] 2.3 Keep records whose source has not arrived and skip malformed ones, and verify integration tests that nothing is deleted
- [x] 2.4 Roll back a failed save, and verify an integration test that the next read does not show it
- [x] 2.5 Meet the read and resolve budgets, and verify the CI benchmarks

## 3. Source deletion

- [x] 3.1 Remove a deleted source's progress and list entries from the delete path, and verify an integration test that the other source and recent searches stay

## 4. Recent searches migration

- [x] 4.1 Move locally kept recent searches into the synced list once, and verify integration tests for order, merge, the cap and a kill halfway

## 5. Change notifications

- [x] 5.1 Add the change stream for local saves and imports, and verify an integration test with two subscribers

## 6. Sync on devices

- [ ] 6.1 Check progress, My list and searches across an iPhone, an Apple TV, a Mac and a signed-out iPad, including offline writes, by hand

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
