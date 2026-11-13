## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-browse-by-person --strict`
- [x] 1.2 Draw `iPhone-Person`, `iPad-Person`, `TV-Person`, `iPhone-Title-Cast`, `TV-Title-Cast` and `iPhone-Search-People`, and update the lookups footer on `iPhone-Settings-Lookups` and `TV-Settings-Lookups`

## 2. Filmography matching

- [ ] 2.1 Add `/v1/person/{id}` to the lookup service, credits reduced and capped at 500
- [ ] 2.2 Generalize the Trending matcher to any list of database entries, or build it if `add-discover-rows` group 4 has not landed, with tests citing `browse-by-person/only-titles-your-sources-have`
- [ ] 2.3 Keep filmographies in `Caches/people/` for seven days, at most 200, deleted with lookups off, citing `browse-by-person/a-person-s-filmography-is-kept-on-the-device`

## 3. Person page and cast chips

- [ ] 3.1 Add `PersonPage` on every platform with previews, citing `browse-by-person/a-person-s-page` and `browse-by-person/a-person-s-page-never-asks-the-provider`
- [ ] 3.2 Show cast and crew as chips on a matched title's page and plain text otherwise, citing `browse-by-person/pick-someone-in-the-cast`
- [ ] 3.3 UI tests on iPhone and Apple TV with a stubbed service: pick a name, see the rows, go back to the same chip
- [ ] 3.4 Add journey steps anchored on `person.header` and `title.cast.0`

## 4. People in Search

- [ ] 4.1 Draw the undrawn states listed in design.md
- [ ] 4.2 Add `/v1/people` to the lookup service
- [ ] 4.3 Add the People section with the pause, the three-letter minimum and the switch, citing `browse-by-person/find-a-person-in-search` and `search/results-grouped-best-first`
- [ ] 4.4 Update the Privacy Policy and `WebsiteTests`, citing `antenna-website/the-privacy-policy-rules-out-tracking`
- [ ] 4.5 UI tests on iPhone and Apple TV: type a name, pick the person

## 5. Verify

- [ ] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 5.2 `/opsx:verify` passes
