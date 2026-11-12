# Tasks

## 1. Shared pieces from other changes

- [x] 1.1 Parameterise the Apple TV guide layout by column, block and channel widths, and verify the tvOS layout tests still pass with 370, 40 and 300
- [x] 1.2 Make the shell navigator build on every platform with a current-group setter, and verify a test that Guide and Live share the group
- [x] 1.3 Add a stable row identifier token with no stream link, and verify a UI test that no guide identifier contains a fixture stream's scheme, host or query

## 2. Grid on iPad and Mac

- [x] 2.1 Build the grid with pinned channel names and time labels, the now line and the toolbar, and verify core layout tests and a UI test at 21:34
- [x] 2.2 Add zoom by buttons, keys and pinch with four steps kept per device, and verify integration and UI tests including a relaunch
- [x] 2.3 Add the channel filter with Command-F, and verify core matching tests and a UI test of the header count
- [x] 2.4 Swap grid and list on size changes, keeping group, day and details, and verify a UI test

## 3. Rows on iPhone

- [x] 3.1 Build the per-channel rows with group and day chips, the NOW card and gap cards, and verify core and UI tests
- [x] 3.2 Add the now-playing bar above the tab bar, and verify a UI test that tapping it returns to Live

## 4. Days and time

- [x] 4.1 Add day chips, crossing midnight, Now and the scroll limits, and verify core tests including the 2027-03-28 clock change fixture
- [x] 4.2 Move the now line and NOW marker as time passes and on clock or time zone changes, and verify a test with a simulated clock

## 5. Details and watching

- [x] 5.1 Add programme details as popover or sheet with keyboard and VoiceOver access, and verify UI tests
- [x] 5.2 Add Watch and channel-name taps that open Live and start, resume or keep playback, and verify UI tests against the fake engine's call log
- [x] 5.3 Add opening at a programme from Search, with the fallback to now, and verify UI tests

## 6. Missing data and empty states

- [x] 6.1 Add row text for loading, missing and failed guides and the failed-guide and waiting-login banners, and verify core and UI tests
- [x] 6.2 Add the loading, all-failed and empty-group states, and verify UI tests
- [ ] 6.3 Measure first rows and scrolling with 20 000 channels over seven days on iPhone 15 and iPad (M1), and record the result
  Open: needs an iPhone 15 and an M1 iPad, and none is available here. The grid builds only the rows and half hours in view plus one each way (`GuideViewport`), and the rows are lazy.

## 7. Verify

- [x] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
  Open: verify finds every requirement implemented and tested, and reports task 6.3 as the one open item.
