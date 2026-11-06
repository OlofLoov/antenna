# Tasks

## 1. Source loading

- [ ] 1.1 Add the app-layer loader that loads one source at a time in the user's order, tags channels and feeds the catalogue and guide, and verify an integration test with three fixture sources
- [ ] 1.2 Keep the last load time per source on this device and reload on schedule when the app returns to the front, and verify tests for a due source, a fresh source and manual only
- [ ] 1.3 Keep loaded channels and playback when a refresh fails, and verify an offline refresh test
- [ ] 1.4 React to sources added, edited, reordered or deleted on another device, and verify a test that unchanged sources do not reload
- [ ] 1.5 Load a source when its login arrives through iCloud, and verify a test with a delayed Keychain item
- [ ] 1.6 Verify a 50 000-channel M3U loads within 10 seconds off the main thread in debug CI

## 2. Source list

- [ ] 2.1 Build the source list with one status line per state on every platform, and verify a UI test for each state and that no link is shown
- [ ] 2.2 Add reordering by drag and by Move up and Move down on Apple TV, and verify a test that the channel order follows on every device without a reload
- [ ] 2.3 Add Refresh now and Refresh all, and verify a test that channels stay available while loading

## 3. Source details

- [ ] 3.1 Build the details form with the hidden password, and verify a UI test that the saved password appears in no field or log
- [ ] 3.2 Check a changed link or login against the server before saving, and verify integration tests for a change that works, one that fails, a bad link and a duplicate
- [ ] 3.3 Add Sign in on this Apple TV for Xtream sources, and verify a UI test that the source loads and stops waiting

## 4. Delete

- [ ] 4.1 Add delete with confirmation on every platform, removing the login, favorites, guide and channels, and verify an integration test across two stores
- [ ] 4.2 Return to onboarding after the last source is deleted, and verify a UI test

## 5. Preferences

- [ ] 5.1 Add the preferences record with defaults and duplicate handling, and verify a test that showing preferences inserts nothing
- [ ] 5.2 Build the Preferences and About rows on every platform and apply each change on this device, and verify an integration test for each preference

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
