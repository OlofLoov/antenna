## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-browse-by-person --strict`
- [x] 1.2 Draw `iPhone-Person`, `iPad-Person`, `TV-Person`, `iPhone-Title-Cast`, `TV-Title-Cast` and `iPhone-Search-People`
- [x] 1.3 Revise the change for provider names with no lookup service (owner, 2026-11-19), and update the six boards: initials only, no TMDB credit, the note on the person page, chips for any title with names

## 2. Names and the people index

- [x] 2.1 Decode `cast`, `actors` and `director` on Xtream movie and series rows and carry them on `ShelfTitle`, citing `xtream-vod-client/names-on-list-rows`
- [x] 2.2 Add `PersonName` (split, clean, junk, key) and the chip limit, citing `browse-by-person/the-same-person-across-titles` and `browse-by-person/pick-someone-in-the-cast`
- [x] 2.3 Add `LearnedCredits` with its 30-day, 20,000-title file format, citing `browse-by-person/names-the-provider-sent-are-kept`
- [x] 2.4 Add `PeopleIndex` and the person page model (rows, order, count, department, note), citing `browse-by-person/a-person-s-page`, `browse-by-person/only-titles-your-sources-have` and `browse-by-person/a-person-s-page-never-asks-the-provider`

## 3. Cast chips and the person page

- [ ] 3.1 Turn the library's title page into a stack of title and person pages, with Back popping one level on every platform
- [ ] 3.2 Record names from every info answer into `LearnedCredits`, save it to `Caches/people/credits.json`, and build the people index in the library
- [ ] 3.3 Show cast and directors as chips on the title page on iPhone, iPad, Mac and Apple TV, with previews
- [ ] 3.4 Add the person page on every platform with previews, and copy in every app language
- [ ] 3.5 Add cast to the UI-testing shelf and UI tests on iPhone and Apple TV: pick a name, see the rows, open a title, go back to the same chip
- [ ] 3.6 Add journey steps anchored on `person.header` and `title.cast.0`

## 4. People in Search

- [x] 4.1 Add people search to `PeopleIndex`, citing `browse-by-person/find-a-person-in-search` and `search/results-grouped-best-first`
- [ ] 4.2 Add the People section to Search on iPhone, iPad, Mac and Apple TV, with previews and copy in every app language
- [ ] 4.3 UI tests on iPhone and Apple TV: type a name, pick the person

## 5. Verify

- [ ] 5.1 Each requirement of the provider-names part has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 5.2 `/opsx:verify` passes for groups 1 to 4

## 6. Later: with the lookup service (waits on the title-info server)

Not started. The owner decided on 2026-11-19 not to run the server for now; design.md "Later" has the plan. The change is not archived while these are open.

- [ ] 6.1 Add `/v1/person/{id}` to the lookup service, credits reduced and capped at 500
- [ ] 6.2 Generalize the Trending matcher from `add-discover-rows` to any list of database entries and match filmographies against the catalogue
- [ ] 6.3 Keep filmographies in `Caches/people/` for seven days, at most 200, deleted with lookups off, with the offline and failure states and their boards
- [ ] 6.4 Show TMDB credits as chips on matched titles, a photo and "Filmography from TMDB" on the person page
- [ ] 6.5 Add `/v1/people` to the lookup service and People from TMDB in Search, after three letters and a pause, only online with lookups on
- [ ] 6.6 Update the Settings lookups footer, its boards, the Privacy Policy and `WebsiteTests`, citing `antenna-website/the-privacy-policy-rules-out-tracking`
- [ ] 6.7 UI tests with a stubbed service, and `/opsx:verify` for the whole change
