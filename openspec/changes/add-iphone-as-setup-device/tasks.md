# Tasks

## 1. Device checks and hosting

- [ ] 1.1 Check on devices whether tvOS offers Handoff to a nearby iPhone, whether SwiftData posts CloudKit export events, and whether the TV target needs the associated domain, and record the answers in design.md
- [ ] 1.2 Publish the association file and the plain fallback page on the chosen host, and verify the page has no scripts, images or third-party content

## 2. Setup link

- [x] 2.1 Add the setup link and Handoff data holding only a version and a random code, and verify a core test that a new code is made each time and nothing else is carried

## 3. Apple TV QR card

- [x] 3.1 Show the QR card when signed in to iCloud and the keyboard card otherwise, swapping on sign-in changes, and verify UI and integration tests
- [x] 3.2 Watch for a playlist source created after the step was reached and go on to loading, and verify integration tests for old sources, two senders and typed text being discarded
- [x] 3.3 Fill in and lock Name and the server or portal for an arrived Xtream source or Stalker portal and save the typed login or MAC address for it, and verify a UI test that no second source is added
- [x] 3.4 Show the two-minute hint, with the update wording for a source the card cannot set up, and verify an integration test
- [x] 3.5 Keep typing on the TV working and drop the card once Connect succeeds, and verify an integration test

## 4. iPhone, iPad and Mac

- [ ] 4.1 Open the "Set up Apple TV" form from the link or Handoff on any screen, once per code, and verify UI tests including a damaged link, a newer link and the paywall
- [ ] 4.2 Turn the form into the sending screen on Connect, and verify a UI test that it cannot be swiped away
- [ ] 4.3 Show "Not sent yet" after 30 seconds or at once without iCloud, and "Handed to iCloud" on confirmation, and verify integration tests

## 5. Verify

- [ ] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 5.2 `/opsx:verify` passes
