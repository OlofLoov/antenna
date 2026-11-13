# Tasks

## 1. Decisions and boards

- [x] 1.1 Get the owner's answer on the rule change in design.md, and record it there with the date
- [x] 1.2 Draw the states design.md lists as not drawn yet, and redraw `TV-Onboard-3-QR-Received.dc.html` if its copy changed
- [x] 1.3 Check `docs/architecture/` and add the sealed delivery to the iCloud edge of the container diagram if it names what crosses it

## 2. Rule and formats

- [x] 2.1 Update the secrets rule in `openspec/config.yaml` and CLAUDE.md to the confirmed wording
- [x] 2.2 Add setup link version 2 with the key and source ids, keeping version 1 readable, and verify core tests for every parse error and a v1 link
- [x] 2.3 Add the payload format with a redacted description and the rule for which sources a code asks for, and verify core tests per source kind, the eight-source cap and Channels DVR without a password

## 3. Sealing and delivery

- [x] 3.1 Add the sealing and the in-memory receiver key, and verify app unit tests on iOS and tvOS for a round trip, a wrong key, a wrong token and an unknown payload version
- [x] 3.2 Add the CloudKit delivery store, its sweep and an in-memory fake, and verify integration tests against the fake for create-only saves, delete and the ten-minute sweep

## 4. Apple TV

- [x] 4.1 Show the QR card on onboarding's sign-in step when signed in to iCloud, and the keyboard card otherwise, and verify a UI test for both and that focus never lands on the code
- [x] 4.2 Pick up a delivery, check each login and keep the ones that work, ask for the rest with the failure message, and verify integration tests against the fake store for success, one failure, an unreadable delivery, two senders and the ten-minute replacement
- [x] 4.3 Show the card in a source's details in Settings for that source, and verify a UI test that the source loads after a delivery. `SourceSignInTVUITests.testALoginFromTheIPhoneLoadsTheSourceFromItsDetails` waits for the card and the source's channel. Writing it showed the card never appeared: it sat in an empty Group whose task never ran, and it is now in a stack.
- [x] 4.4 Wait for the login after a source arrives on the setup card, fall back to Sign in here after a minute, and verify an integration test that a login arriving before its source is used

## 5. iPhone, iPad and Mac

- [x] 5.1 Open the "Sign in your Apple TV" sheet from a v2 link or Handoff, listing ready, missing and absent sources, and verify UI tests for the list, none of the sources, a damaged link and the paywall
- [x] 5.2 Enter a missing login, checked with the server and kept in the Keychain, and verify a UI test for an accepted and a refused login
- [x] 5.3 Send, then show picked up, not picked up, offline, not signed in, storage full and already used, and verify integration tests against the fake store
- [x] 5.4 Send the login from the setup sending screen when the link had a key, and verify an integration test that a playlist source sends nothing

## 6. Accessibility

- [x] 6.1 Label the code, announce a delivered login on the TV, read rows as one element and show "In progress" with Reduce Motion, and verify UI tests on iOS and tvOS. Labels, the announcement, rows read as one element and the "In progress" text are built, and the labels and rows have UI tests on iOS and tvOS. XCUITest cannot turn on Reduce Motion, so that check is on `docs/release/device-checklist.md`.

## 7. Verify

- [x] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 7.2 Run the device checklist in design.md's Testing section on an iPhone and an Apple TV on one iCloud account, and record the times and results in design.md (needs two real devices on one iCloud account; none were available). The device check is in `docs/release/device-checklist.md`.
- [x] 7.3 `/opsx:verify` passes
