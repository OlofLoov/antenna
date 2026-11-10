# Tasks

## 1. Snapshot and sections in AntennaCore

- [ ] 1.1 Add the versioned snapshot, item ids from SHA-256 and version 5 UUIDs, and the link format, and verify core tests including FIPS 180-4 vectors
- [ ] 1.2 Map a snapshot to sections for favorites with programme on now, favorites with no guide left, Continue watching, one empty row and the empty shelf, and verify a core test per case
- [ ] 1.3 Reject damaged or outdated snapshots, and verify a core test that they give no content

## 2. Writer in the app

- [ ] 2.1 Write the snapshot and tile images to the shared area with an atomic rename and no fetching, and verify an integration test that the files hold no link, identity, username or password
- [ ] 2.2 Batch writes after favorites, playback, source deletion, guide refresh, a source finishing loading and six hours, flush on background, and wait while a source loads, and verify integration tests with a simulated clock
- [ ] 2.3 Clear the summary when the unlock lapses and keep the previous shelf on a failed write, and verify integration tests

## 3. Extension

- [ ] 3.1 Add the Top Shelf extension target, App Group and URL scheme in `project.yml`, and verify the tvOS build
- [ ] 3.2 Provide sectioned content from the snapshot with no network requests, dropping missing tiles and empty sections, and verify tests in the Apple TV test bundle

## 4. Selecting a tile

- [ ] 4.1 Tune or resume from a shelf link while running and at launch, holding the request until the source loads, and verify tvOS UI tests with a recording navigator
- [ ] 4.2 Open Antenna as it was for a stale, empty or damaged link, and verify a UI test per case
- [ ] 4.3 Show the paywall or setup first and drop the tile's channel afterwards, and verify UI tests

## 5. The current profile's shelf

- [ ] 5.1 Write the snapshot for the current profile only, and rewrite it on a profile switch, and verify with a test citing `top-shelf/the-shelf-shows-the-current-profile`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
