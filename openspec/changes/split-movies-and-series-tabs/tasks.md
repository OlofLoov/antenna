## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate split-movies-and-series-tabs --strict`
- [x] 1.2 Draw `iPhone-Profile-Menu`, redraw the iPhone tab bar on every board that shows it, `iPhone-Movies` and `iPhone-Series` without the switch, the Settings boards as a sheet, and the search tab on `TV-Shell-TabView`

## 2. iPhone tab bar and profile button

- [x] 2.1 Split `CompactTabs` into Live, Guide, Movies, Series and the search role tab; drop the Settings tab; restore and launch into Series by the sidebar's rules
- [x] 2.2 Make `ShelfCompactScreen` one screen per kind with the section name and the profile button, and remove `ShelfView.KindSwitch` and the section search button on iPhone
- [x] 2.3 Add `ProfileMenuButton` and `ProfileCornerLabel` with a preview, on the group row of Live and the Guide, over whole-screen messages and on the Movies and Series bar
- [x] 2.4 Open Settings as a sheet with Close, route `ShellNavigator` and the reminder banner through it, and show the banner over the sheet
- [x] 2.5 Give Series `play.rectangle.on.rectangle` in the tab bar and the iPad and Mac sidebar
- [x] 2.6 Add "Switch profile" in every catalog language
- [x] 2.7 UI tests on iPhone citing `live-tv-on-iphone-ipad-mac/the-iphone-tab-bar`, `live-tv-on-iphone-ipad-mac/settings-from-the-profile-button`, `profiles/switching-profile` and `movies-and-series-browsing/search-from-the-section`; move every test that opened the Settings tab or the Series switch to the profile button and the Series tab

## 2a. Genres behind one button on iPhone

- [x] 2a.1 Add `Shelf.genres(_:matching:)` in AntennaCore with tests citing `movies-and-series-browsing/pick-a-genre-from-a-list-on-iphone`
- [x] 2a.2 Replace the iPhone genre chips with `ShelfGenreButton` and `ShelfGenreSheet`, built from `Browse.GroupButton` and `Browse.GroupChoiceRow`, with "Search genres" and "Opens the list of genres" in every catalog language
- [x] 2a.3 Draw `iPhone-Movies-Genres` and the genre button on the `iPhone-Movies*` boards
- [x] 2a.4 iPhone UI test: no chips at the top, the button opens the sheet, search narrows it, a pick shows the grid and closes the sheet

## 3. Apple TV search tab

- [x] 3.1 Give the Apple TV Search tab the search role with a magnifying glass label, keeping `shell.tab.search`
- [ ] 3.2 Run the Apple TV shell and search UI tests citing `tvos-shell/the-tabs-in-order`

## 4. Verify

- [ ] 4.1 Run the touched UI test classes on iPhone, iPad and Apple TV simulators with `-testLanguage en -testRegion US`
- [ ] 4.2 Each requirement in the delta specs has a test citing `<capability>/<requirement-slug>`
- [ ] 4.3 `/opsx:verify` passes
