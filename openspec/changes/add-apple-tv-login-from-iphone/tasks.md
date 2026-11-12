# Tasks

## 1. Decisions and boards

- [ ] 1.1 Get the owner's answer on the rule change in design.md, and record it there with the date
- [ ] 1.2 Draw the states design.md lists as not drawn yet, and redraw `TV-Onboard-3-QR-Received.dc.html` if its copy changed
- [ ] 1.3 Check `docs/architecture/` and add the sealed delivery to the iCloud edge of the container diagram if it names what crosses it

## 2. Rule and formats

- [ ] 2.1 Update the secrets rule in `openspec/config.yaml` and CLAUDE.md to the confirmed wording
- [ ] 2.2 Add setup link version 2 with the key and source ids, keeping version 1 readable, and verify core tests for every parse error and a v1 link
- [ ] 2.3 Add the payload format with a redacted description and the rule for which sources a code asks for, and verify core tests per source kind, the eight-source cap and Channels DVR without a password

## 3. Sealing and delivery

- [ ] 3.1 Add the sealing and the in-memory receiver key, and verify app unit tests on iOS and tvOS for a round trip, a wrong key, a wrong token and an unknown payload version
- [ ] 3.2 Add the CloudKit delivery store, its sweep and an in-memory fake, and verify integration tests against the fake for create-only saves, delete and the ten-minute sweep

## 4. Apple TV

- [ ] 4.1 Show the QR card on onboarding's sign-in step when signed in to iCloud, and the keyboard card otherwise, and verify a UI test for both and that focus never lands on the code
- [ ] 4.2 Pick up a delivery, check each login and keep the ones that work, ask for the rest with the failure message, and verify integration tests against the fake store for success, one failure, an unreadable delivery, two senders and the ten-minute replacement
- [ ] 4.3 Show the card in a source's details in Settings for that source, and verify a UI test that the source loads after a delivery
- [ ] 4.4 Wait for the login after a source arrives on the setup card, fall back to Sign in here after a minute, and verify an integration test that a login arriving before its source is used

## 5. iPhone, iPad and Mac

- [ ] 5.1 Open the "Sign in your Apple TV" sheet from a v2 link or Handoff, listing ready, missing and absent sources, and verify UI tests for the list, none of the sources, a damaged link and the paywall
- [ ] 5.2 Enter a missing login, checked with the server and kept in the Keychain, and verify a UI test for an accepted and a refused login
- [ ] 5.3 Send, then show picked up, not picked up, offline, not signed in, storage full and already used, and verify integration tests against the fake store
- [ ] 5.4 Send the login from the setup sending screen when the link had a key, and verify an integration test that a playlist source sends nothing

## 6. Accessibility

- [ ] 6.1 Label the code, announce a delivered login on the TV, read rows as one element and show "In progress" with Reduce Motion, and verify UI tests on iOS and tvOS

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 Run the device checklist in design.md's Testing section on an iPhone and an Apple TV on one iCloud account, and record the times and results in design.md
- [ ] 7.3 `/opsx:verify` passes
