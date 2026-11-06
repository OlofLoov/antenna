# Tasks

## 1. Run as the current user

- [ ] 1.1 Add the user-management entitlement to the Apple TV app only, and verify an integration test that reads both entitlement files
- [ ] 1.2 Keep Keychain queries synchronizable and never user-independent, and verify an integration test on the query
- [ ] 1.3 Confirm launch lands on welcome, channels or sign-in with no profile chooser, and verify a tvOS UI test per setup state

## 2. Several-users hint

- [ ] 2.1 Add the injectable user-separation provider and the hint on the welcome screen, read each time it appears, and verify tvOS UI tests with one and several users
- [ ] 2.2 Keep the hint off every later setup step and off iPhone, iPad and Mac, and verify UI tests for each screen
- [ ] 2.3 Update the onboarding board copy to "for this user only", and verify the boards and strings match

## 3. Per-user state

- [ ] 3.1 Write the last channel at tune time and session state on each change so nothing depends on termination, and verify a tvOS-shell test
- [ ] 3.2 Keep the downloaded guide in per-user storage, and verify a guide-data test
- [ ] 3.3 Run the two-user device checks for own sources, one sign-in each, per-person memory and switching mid-setup on an Apple TV with two users, and record the results

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.2 `/opsx:verify` passes
