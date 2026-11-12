# Tasks

## 1. Guide list per source

- [x] 1.1 Replace the single-link resolver in `guide-data` with a guide list per source, with per-guide progress and failures, and verify with core tests citing `guide-data/find-the-guide-for-each-source` and `guide-sources-and-channel-mapping/every-guide-a-playlist-names-is-used`
- [x] 1.2 Route every channel lookup through one function that applies the winning order and hand-picked matches, and verify with core tests citing `guide-data/programmes-land-on-the-right-channels` and `guide-sources-and-channel-mapping/choose-which-guide-wins`
- [x] 1.3 Keep a failing guide from affecting the others and show its status, and verify with an integration test citing `guide-sources-and-channel-mapping/one-broken-guide-does-not-break-the-others`

## 2. Settings record and privacy

- [ ] 2.1 Add the per-source guide settings record with order, flags, added links, matches, tombstones, merge and size cap
- [ ] 2.2 Split added links into Keychain and stored parts and show them redacted, and verify with an integration test citing `guide-sources-and-channel-mapping/passwords-in-guide-links-stay-private`

## 3. Guide sources screen

- [ ] 3.1 Add a guide link with validation, and verify with a UI test citing `guide-sources-and-channel-mapping/add-a-guide-link`
- [ ] 3.2 Turn off and remove guides, and verify with an integration test citing `guide-sources-and-channel-mapping/turn-off-or-remove-a-guide`
- [ ] 3.3 Add the Guide row in each playlist's details and the screen on every platform from the boards

## 4. Channels without a guide

- [ ] 4.1 Work out each channel's reason, and verify with a core test citing `guide-sources-and-channel-mapping/see-why-a-channel-has-no-guide`
- [ ] 4.2 List channels without a guide with counts, reasons, the filter and the collapsed state, and verify with a UI test citing `guide-sources-and-channel-mapping/find-the-channels-without-a-guide`

## 5. Hand-picked matches

- [ ] 5.1 Search guide entries with the search change's folding and pick one, and verify with a UI test citing `guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand`
- [ ] 5.2 Remove a match, and verify with an integration test citing `guide-sources-and-channel-mapping/undo-a-hand-picked-match`
- [ ] 5.3 Keep matches across refreshes and the size cap, and verify with a core test citing `guide-sources-and-channel-mapping/matches-survive-a-playlist-refresh`
- [ ] 5.4 Match channels without a guide id by name at full confidence only, show them under "Matched by name", and undo a match, and verify with core tests citing `guide-sources-and-channel-mapping/channels-matched-by-name`
- [ ] 5.5 Check on two devices that guides, order and matches sync, citing `guide-sources-and-channel-mapping/settings-follow-you-to-every-device`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `guide-sources-and-channel-mapping/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
