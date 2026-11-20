# Tasks

## 1. Change and boards

- [x] 1.1 Proposal, delta specs, design and tasks
- [x] 1.2 `iPhone-Settings-Adult`, `iPad-Settings-Adult`, `TV-Settings-Adult`, `iPhone-Groups-Adult`, `iPad-Groups-Adult`, `TV-Groups-Adult`

## 2. Detection and filter in AntennaCore

- [x] 2.1 `AdultContent.isAdultName` and `isAdultRating`, with `Fixtures/Adult/names.json` (adult-content/adult-groups-are-found-by-name)
- [x] 2.2 The provider's flags: Xtream `is_adult` on live, movie and series rows and categories, Stalker `censored`, Jellyfin XXX and AO, into `Channel.isAdult` and `ShelfTitle.isAdult` (adult-content/the-provider-s-adult-flag-counts)
- [x] 2.3 `GroupRules.adultMarks` and `showsAdult`; `CataloguePolicy` hides adult groups and entries by default; `isAdultHidden`, `isAdult`, `hidesAdultGroups` (adult-content/hidden-everywhere-by-default, adult-content/correct-a-group)
- [x] 2.4 `ShelfIndex` takes `showsAdult` and keeps `withheldTitle`; `visible(showsAdult:)`; Siri lookups and the `adultHidden` reply in every language

## 3. Storage and the switch

- [ ] 3.1 `ProfileRecord.showsAdult`, `Profile.showsAdult`, `ProfileStore.setShowsAdult`; `showsAdultContent` in the environment from `ProfileGate`
- [ ] 3.2 `GroupRecord.adult`, `GroupStore.setAdult`, `GroupStore.rules` reads marks and the switch; `GroupRulesFeed` and the intents host pass them
- [ ] 3.3 "Show adult content" in Settings on every platform, asking for the passcode to turn on, or to set one

## 4. Every screen follows

- [ ] 4.1 `ShelfModel` rebuilds the index when the switch changes; an adult movie or episode playing closes when it leaves the index
- [ ] 4.2 The Groups screen: the "Adult content" switch, the ADULT badge, adult groups listed only while shown, the note while hidden
- [ ] 4.3 `GroupLockPrompt` covers a hidden adult channel that plays; the right passcode turns the switch on
- [ ] 4.4 `AdultGate` for title links from Top Shelf and Siri
- [ ] 4.5 Siri's background titles and suggestions go through `visible(showsAdult:)`; Top Shelf follows the filtered catalogue and index
- [ ] 4.6 Strings in sv, de, es, fr, pt-BR and ar

## 5. Tests

- [ ] 5.1 App unit tests for `GroupStore` marks and `ProfileStore.setShowsAdult`
- [ ] 5.2 `-ui-testing-adult` scripted sources; `AdultContentUITests` on iPhone and Apple TV: hidden by default, the passcode to show, hidden again when switched off

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `adult-content/<requirement-slug>`, `profiles/what-each-profile-keeps` or `group-management/changes-follow-you-to-every-device`
- [ ] 6.2 The UI test classes touched pass on local iPhone and Apple TV simulators with `-testLanguage en -testRegion US`
- [ ] 6.3 `/opsx:verify` passes
