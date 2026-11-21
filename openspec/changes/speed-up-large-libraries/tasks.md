## 1. People index

- [ ] 1.1 `PeopleIndex.Rows` reads the row names once per change of titles, caches each cleaned name part, and points at titles by position; `PersonName.split` reads the field's bytes
- [ ] 1.2 `PeopleIndex(rows:learned:)` puts the info answers' names on top, with core tests that the answer's cast and directors replace the row's and that a cancelled build returns nothing
- [ ] 1.3 `ShelfLibrary.people()` shares one row build per change of titles and cancels the one for old titles, with an app test that answers do not read the rows again
- [ ] 1.4 A benchmark pins the build of 130 000 titles with five names each

## 2. Sorted grids

- [ ] 2.1 `Shelf.sorted` sorts by keys computed once per title, with a benchmark at 100 000 movies
- [ ] 2.2 `ShelfModel` builds Title and Year lists off the main actor and the grid shows when its list is ready, with an app test

## 3. Progress saves

- [ ] 3.1 `ActivityStore.saveProgress` updates the surviving record in place and deletes the other copies, with an app test that the record keeps its id
- [ ] 3.2 `ActivityStore.changes` yields only for saves of activity records and coalesces bursts; `ShelfActivity` assigns only what changed, with app tests

## 4. Search

- [ ] 4.1 `ShelfLibrary` keeps one list of movies and series per change of titles for Search, and the Search screens key the corpus by revision
- [ ] 4.2 `SearchModel` skips results equal to those on screen and searches people off the main actor, with app tests

## 5. Pictures and posters

- [ ] 5.1 `PosterCache` trims the folder to 80% of its limit, with a test
- [ ] 5.2 The banner, the Apple TV preview, the title page and the banner prefetch decode backdrops at the window's size
- [ ] 5.3 Each Apple TV poster reads only its own description hint and progress

## 6. Memory and asks

- [ ] 6.1 `loadEpisodes` goes through the once-per-title fetch, and a failed prefetch is not asked again, with app tests
- [ ] 6.2 Episode lists past the kept limit are dropped except for series with progress, with an app test

## 7. Verify

- [ ] 7.1 Each scenario this change adds has a test citing its requirement
- [ ] 7.2 Before and after numbers for 100 000 movies and 30 000 series with cast are in design.md
- [ ] 7.3 The touched UI test classes pass on a local simulator
- [ ] 7.4 /opsx:verify passes
