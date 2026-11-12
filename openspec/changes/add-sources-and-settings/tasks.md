# Tasks

## 1. Source loading

- [x] 1.1 Add the app-layer loader that loads one source at a time in the user's order, tags channels and feeds the catalogue and guide, and verify an integration test with three fixture sources
- [x] 1.2 Keep the last load time per source on this device and reload on schedule when the app returns to the front, and verify tests for a due source, a fresh source and manual only
- [x] 1.3 Keep loaded channels and playback when a refresh fails, and verify an offline refresh test
- [x] 1.4 React to sources added, edited, reordered or deleted on another device, and verify a test that unchanged sources do not reload
- [x] 1.5 Load a source when its login arrives through iCloud, and verify a test with a delayed Keychain item
- [x] 1.6 Verify a 50 000-channel M3U loads within 10 seconds off the main thread in debug CI

## 2. Source list

- [x] 2.1 Build the source list with one status line per state on every platform, and verify a UI test for each state and that no link is shown The UI test covers loaded, failed and waiting for a login; loading, waiting for iCloud and Stalker lines are covered by the status text tests.
- [x] 2.2 Add reordering by drag and by Move up and Move down on Apple TV, and verify a test that the channel order follows on every device without a reload
- [x] 2.3 Add Refresh now and Refresh all, and verify a test that channels stay available while loading

## 3. Source details

- [x] 3.1 Build the details form with the hidden password, and verify a UI test that the saved password appears in no field or log
- [x] 3.2 Check a changed link or login against the server before saving, and verify integration tests for a change that works, one that fails, a bad link and a duplicate
- [ ] 3.3 Add Sign in on this Apple TV for Xtream sources, and verify a UI test that the source loads and stops waiting Open: built and covered by an integration test; no UI test, since typing a login with the Siri Remote keyboard from a UI test is unreliable.

## 4. Delete

- [ ] 4.1 Add delete with confirmation on every platform, removing the login, favorites, guide and channels, and verify an integration test across two stores Open: built, with an integration test on one store. Removal on the user's other devices needs two devices on one iCloud account.
- [x] 4.2 Return to onboarding after the last source is deleted, and verify a UI test

## 5. Preferences

- [x] 5.1 Add the preferences record with defaults and duplicate handling, and verify a test that showing preferences inserts nothing
- [ ] 5.2 Build the Preferences and About rows on every platform and apply each change on this device, and verify an integration test for each preference Open: every row is built and stored; Guide window is not applied yet because the guide grid's two-hour window is fixed in `GuideTimeline`.

## 6. Stalker portals

- [x] 6.1 Show a Stalker portal's load status in its row and details and offer Refresh now, and verify with a status test citing `sources-and-settings/see-how-each-source-is-doing`
- [x] 6.2 Edit a portal's address, MAC address, login and password in its details with the saved password hidden, check a change with the portal before saving, and verify with integration tests citing `sources-and-settings/your-password-stays-hidden` and `sources-and-settings/fix-a-source-s-link-or-login`
- [x] 6.3 Offer Sign in on this Apple TV for a portal, and verify with an integration test citing `sources-and-settings/sign-in-on-this-apple-tv`

## 7. Verify

- [x] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes Open until 3.3, 4.1 and 5.2 are done.
