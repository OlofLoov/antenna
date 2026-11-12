# Tasks

## 1. Server check and sign-in

- [x] 1.1 Add the server-info check that sends no password and accepts addresses with or without a path, and verify core tests against fixture answers
- [x] 1.2 Add sign-in with the per-device id and the session store, sending only the key after the first sign-in, and verify core tests that the password is sent once
- [x] 1.3 Map turned-down, forbidden, unreachable, server-error and untrusted-certificate answers to their own errors, and verify a core test per case that the saved key is kept
- [x] 1.4 Add the single renewed sign-in on a turned-down key, discarding the key after a second refusal, and verify core tests for both paths

## 2. Channels

- [x] 2.1 Load channels in pages up to the reported total or 100 pages, and verify core tests for 2 345 channels and the 100 000 ceiling
- [x] 2.2 Map channel rows to catalogue channels with name, whole number, "Radio" group, logo and host-only identity, and verify core tests across ports and schemes
- [x] 2.3 Skip and count broken rows, and fail web pages and non-list answers as reading errors that quote nothing, and verify core tests with broken fixtures

## 3. Streams and logos

- [x] 3.1 Build stream addresses with the key and logo addresses without it, with and without a server path, and verify core tests

## 4. Guide

- [x] 4.1 Fetch programmes in channel batches over the requested window, including programmes already on air, and verify core tests for 120 channels and for an empty request
- [x] 4.2 Let the guide take programmes from the client in batches with batch progress, and verify a guide-data test that no XMLTV download happens

## 5. Secrets

- [x] 5.1 Redact the username, password, key, port and path from every printed source, credential and error, and verify core tests that print each

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
