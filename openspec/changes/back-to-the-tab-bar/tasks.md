# Tasks

## 1. Back on Apple TV

- [ ] 1.1 `ShellBack` leaves Back to tvOS while the highlight is in the bar; `MenuOrigin.bar` and its branch in `ShellModel.menu(from:)` go
- [ ] 1.2 `shellBarFocused` environment value and `scrollsToTopFromTabBar()` on the Movies and Series rows and on Search's results; swiping down from the bar lands on Play
- [ ] 1.3 "Who's watching?" and the loading checklist stop holding on to Back
- [ ] 1.4 `ControlHintScreen`: Back reads "Home Screen" in the bar and "Tab bar" on Live full screen, in place of Play/Pause
- [ ] 1.5 UI tests: Back from the bar over Live and over Movies leaves the app; repeated Back from the overlay and from a genre grid leaves the app; Back on "Who's watching?" leaves the app; Back from the genre chips scrolls Movies to the top; the legend names where Back goes
- [ ] 1.6 Existing tests: drop Back from the ways down from the bar, cite the new requirements, resume a paused video through selecting Live
- [ ] 1.7 `add-focused-title-preview` names this change for Back on the rows

## 2. iPhone and iPad

- [ ] 2.1 A tap on the open tab counts in `CompactTabs` and reaches the tab as `tabTaps`
- [ ] 2.2 Live's list, the Guide's channels, Movies and Search scroll to their top on a tap; Movies closes an open page
- [ ] 2.3 UI test: tapping Movies again scrolls the rows back to the banner

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
