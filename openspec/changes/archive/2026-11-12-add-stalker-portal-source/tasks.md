# Tasks

## 1. Input parsing

- [x] 1.1 Add MAC normalization and portal address checks, and verify core tests for each accepted and rejected form

## 2. Sign-in and session

- [x] 2.1 Add endpoint discovery and sign-in with the optional login, and verify core tests against the request stub for each address form
- [x] 2.2 Map each Connect failure to its own error, and verify core tests that an outage never reads as a wrong address
- [x] 2.3 Derive the serial number, device ids and signature from the MAC, once the CryptoKit decision lands, and verify a core test against the expected values for `00:1A:79:12:34:56`
- [x] 2.4 Share one sign-in between concurrent callers and renew a rejected session once, and verify core tests with two simultaneous requests and a repeat that is also rejected

## 3. Channels

- [x] 3.1 Load genres and channels with numbers, logos, catch-up days and stable ids, skipping the "All" genre and broken rows, and verify core tests including counts of skipped rows
- [x] 3.2 Turn unreadable answers into a reading error that quotes nothing, and verify core tests for HTML, XML and empty bodies
- [x] 3.3 Load Stalker channels into the combined list in source management, and verify the Stalker beside M3U test

## 4. Tuning

- [x] 4.1 Resolve a fresh stream address at tune time, once the tune-time decision lands, and verify core tests for success, a non-portal channel and an answer with no address

## 5. Guide

- [x] 5.1 Use the portal's own guide when the source has no guide link, matching by XMLTV id or portal channel id, and verify core tests for both matches, counted bad rows and the session renewal

## 6. Secrets and Keychain

- [x] 6.1 Redact the MAC, login, password, session key, device ids, stream addresses and portal path from every printed value and error, and verify core tests that print each one
- [x] 6.2 Add the optional login to the Keychain item and read old items unchanged, and verify an integration test for the three item kinds

## 7. Verify

- [x] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 7.2 `/opsx:verify` passes
