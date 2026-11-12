# Tasks

## 1. Catch-up details and addresses

- [x] 1.1 Parse `catchup`, `catchup-source` and `catchup-correction` in the M3U parser, and verify with a core test citing `m3u-playlists/catch-up-style-source-and-correction`
- [x] 1.2 Map `tv_archive` to the Xtream style, read the server time zone once per load and again on first need, and verify with core and integration tests citing `xtream-live-source/archive-channels-use-xtream-catch-up` and `xtream-live-source/server-time-zone`
- [x] 1.3 Build catch-up addresses for every style with the refusal rows and a DST fixture, and verify with a core test citing `timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects`

## 2. Buffer

- [ ] 2.1 Build the timeshift window and buffer actor with the limits, writing only at start points, and verify with integration tests on a simulated clock citing `timeshift-catch-up-and-start-over/when-the-buffer-runs-out`
- [ ] 2.2 Start a fresh buffer per channel, delete the old one off the main path and clear leftovers at launch, and verify with an integration test citing `timeshift-catch-up-and-start-over/changing-channel-starts-fresh`
- [ ] 2.3 Handle unrecordable streams, short storage and partway failures with their notices, and verify with integration, UI and device tests citing `timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded`

## 3. Moving in time

- [ ] 3.1 Pause and resume from the buffer with the behind text and marker, and verify with integration and UI tests citing `timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off`
- [ ] 3.2 Add skip, scan and drag on each platform, and verify with integration and UI tests citing `timeshift-catch-up-and-start-over/skip-scan-and-drag`
- [ ] 3.3 Add back to live by hold, LIVE tap or reaching now, and verify with integration and UI tests citing `timeshift-catch-up-and-start-over/back-to-live`
- [ ] 3.4 Track user pauses and handle background, calls, sleep and tab changes, and verify with integration and UI tests citing `timeshift-catch-up-and-start-over/leaving-the-app-calls-and-other-interruptions`

## 4. Start over

- [ ] 4.1 Decide visibility with the start-over planner and re-evaluate on changes, and verify with core, integration and tvOS UI tests citing `timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work`
- [ ] 4.2 Play catch-up with the badge, coalesced skips and return to live, or jump the buffer, and verify with integration and UI tests citing `timeshift-catch-up-and-start-over/start-the-programme-from-the-beginning`
- [ ] 4.3 Fall back to the live buffer when catch-up fails, and verify with integration and UI tests citing `timeshift-catch-up-and-start-over/when-the-provider-s-catch-up-fails`

## 5. Privacy

- [ ] 5.1 Keep catch-up fields in memory only and redact every address in logs, and verify with a log, hierarchy and in-memory store scan citing `timeshift-catch-up-and-start-over/logins-stay-private`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `timeshift-catch-up-and-start-over/<requirement-slug>`, and the added parser and Xtream requirements are cited too
- [ ] 6.2 `/opsx:verify` passes
