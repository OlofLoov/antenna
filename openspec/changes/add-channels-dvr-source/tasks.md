# Tasks

## 1. Address and status

- [ ] 1.1 Tidy a typed address and turn down embedded credentials, other schemes and missing hosts, and verify core tests over the address table
- [ ] 1.2 Add the status check with distinct starting, not-Channels-DVR, needs-password, server-error, unreachable and offline outcomes, and verify core tests per outcome
- [ ] 1.3 Send the proxy username and password with every request when set and turn down unusable usernames, and verify core tests with and without a password

## 2. Lineup

- [ ] 2.1 Add the title-first name option and minor channel numbers to the playlist parser, and verify m3u-playlists tests
- [ ] 2.2 Map the lineup to channels with display name, call-sign fallback, major and minor number, group, logo and stream, and verify core tests
- [ ] 2.3 Derive channel identity from the lineup only, and verify a core test that home and remote addresses give the same ids
- [ ] 2.4 Handle full, empty, web-page, blank and server-error lineups, and verify a core test per case
- [ ] 2.5 Order and show channel numbers as major and minor in the catalogue, and verify channel-catalogue tests

## 3. Loading with other sources

- [ ] 3.1 Report a source as waiting for its credential, failed on an unreadable credential, or loaded without touching the Keychain, and verify integration tests for the three states
- [ ] 3.2 Show an unreachable server as failed without asking for its lineup or guide while other sources load, and verify an integration test with mixed sources

## 4. Guide

- [ ] 4.1 Work out the guide address from the source when no hand-set link exists and send the proxy password, and verify guide-data tests
- [ ] 4.2 Match every guide channel to exactly one Antenna channel, and verify a core test against a lineup and guide fixture from one server

## 5. Secrets

- [ ] 5.1 Redact the username, password, encoded credentials and port from every printed source, credential and error, and verify core tests that print each

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
