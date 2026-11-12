# Tasks

## 1. Address and status

- [x] 1.1 Tidy a typed address and turn down embedded credentials, other schemes and missing hosts, and verify core tests over the address table
- [x] 1.2 Add the status check with distinct starting, not-Channels-DVR, needs-password, server-error, unreachable and offline outcomes, and verify core tests per outcome
- [x] 1.3 Send the proxy username and password with every request when set and turn down unusable usernames, and verify core tests with and without a password

## 2. Lineup

- [x] 2.1 Add the title-first name option and minor channel numbers to the playlist parser, and verify m3u-playlists tests
- [x] 2.2 Map the lineup to channels with display name, call-sign fallback, major and minor number, group, logo and stream, and verify core tests
- [x] 2.3 Derive channel identity from the lineup only, and verify a core test that home and remote addresses give the same ids
- [x] 2.4 Handle full, empty, web-page, blank and server-error lineups, and verify a core test per case
- [x] 2.5 Order and show channel numbers as major and minor in the catalogue, and verify channel-catalogue tests

## 3. Loading with other sources

- [x] 3.1 Report a source as waiting for its credential, failed on an unreadable credential, or loaded without touching the Keychain, and verify integration tests for the three states
- [x] 3.2 Show an unreachable server as failed without asking for its lineup or guide while other sources load, and verify an integration test with mixed sources

## 4. Guide

- [x] 4.1 Work out the guide address from the source when no hand-set link exists and send the proxy password, and verify guide-data tests
- [x] 4.2 Match every guide channel to exactly one Antenna channel, and verify a core test against a lineup and guide fixture from one server

## 5. Secrets

- [x] 5.1 Redact the username, password, encoded credentials and port from every printed source, credential and error, and verify core tests that print each

## 6. Adding a server in the app

- [x] 6.1 Add the Channels DVR source kind to the app's loader, connector, guide store and playback, and the local network usage description, and verify an iOS build and the integration tests of group 3
- [x] 6.2 Add the Channels DVR card and Server field to onboarding on every platform, with its wording and the local network hint, and verify integration tests citing `first-run-onboarding/add-a-channels-dvr-server`
- [x] 6.3 Add a Channels DVR server from Settings, edit its address in its details, and keep it out of the Apple TV sign-in while it has no password, and verify integration tests citing `sources-and-settings/fix-a-source-s-link-or-login`
- [x] 6.4 Show a number like 6.1 wherever a channel number is shown, and verify the iOS build and the touched UI test classes on a simulator

## 7. Verify

- [x] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 7.2 `/opsx:verify` passes
