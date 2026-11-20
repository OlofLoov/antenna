## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate split-movies-and-series-tabs --strict`
- [x] 1.2 Draw `iPhone-Profile-Menu`, redraw the iPhone tab bar on every board that shows it, `iPhone-Movies` and `iPhone-Series` without the switch, the Settings boards as a sheet, and the search tab on `TV-Shell-TabView`

## 2. iPhone tab bar and profile button

- [ ] 2.1 Split `CompactTabs` into Live, Guide, Movies, Series and the search role tab; drop the Settings tab; restore and launch into Series by the sidebar's rules
- [ ] 2.2 Make `ShelfCompactScreen` one screen per kind with the section name and the profile button, and remove `ShelfView.KindSwitch` and the section search button on iPhone
- [ ] 2.3 Add `ProfileMenuButton` and `ProfileCornerLabel` with a preview, on the group row of Live and the Guide, over whole-screen messages and on the Movies and Series bar
- [ ] 2.4 Open Settings as a sheet with Close, route `ShellNavigator` and the reminder banner through it, and show the banner over the sheet
- [ ] 2.5 Give Series `play.rectangle.on.rectangle` in the tab bar and the iPad and Mac sidebar
- [ ] 2.6 Add "Switch profile" in every catalog language
- [ ] 2.7 UI tests on iPhone citing `live-tv-on-iphone-ipad-mac/the-iphone-tab-bar`, `profiles/switching-profile` and `movies-and-series-browsing/search-from-the-section`; move every test that opened the Settings tab or the Series switch to the profile button and the Series tab

## 3. Apple TV search tab

- [ ] 3.1 Give the Apple TV Search tab the search role with a magnifying glass label, keeping `shell.tab.search`
- [ ] 3.2 Run the Apple TV shell and search UI tests citing `tvos-shell/the-tabs-in-order`

## 4. Verify

- [ ] 4.1 Run the touched UI test classes on iPhone, iPad and Apple TV simulators with `-testLanguage en -testRegion US`
- [ ] 4.2 Each requirement in the delta specs has a test citing `<capability>/<requirement-slug>`
- [ ] 4.3 `/opsx:verify` passes
