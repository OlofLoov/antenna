# Tasks

## 1. Entitlement in AntennaCore

- [ ] 1.1 Add the entitlement states, the resolver over purchase evidence and the fixed stand-in provider, and verify core tests for Lifetime, Yearly, grace period, refund and owning both
- [ ] 1.2 Add the offline grace rule for a remembered Yearly purchase, and verify a core test at 16 days past the end date
- [ ] 1.3 Add the paywall copy table with no provider, channel or content wording, and verify a core test over every line

## 2. StoreKit provider and cache

- [ ] 2.1 Add the StoreKit provider that listens from launch and ignores unverified transactions, and verify integration tests against the local StoreKit configuration
- [ ] 2.2 Add the versioned cache that holds the verdict and lapse only, and verify a test that an offline launch after a purchase opens the app
- [ ] 2.3 Add the two-launch rule for an empty App Store answer, and verify an integration test

## 3. Paywall screen

- [ ] 3.1 Build the paywall on every platform with App Store prices, renewal wording and any introductory offer, and verify an integration test
- [ ] 3.2 Handle purchase success, cancel, failure, Ask to Buy and purchases turned off, and verify an integration test for each outcome
- [ ] 3.3 Add Restore purchase with "Welcome back", nothing found and an ended subscription, and verify integration tests
- [ ] 3.4 Add the unreachable and not-sold panels, and verify a test that a late answer replaces the panel
- [ ] 3.5 Add offer code redemption on iPhone, iPad and Mac, and verify it is absent on Apple TV

## 4. App root and locking

- [ ] 4.1 Replace the window root with one that decides splash, paywall, onboarding and shell on each activation, and verify a UI test that no source is contacted before unlock
- [ ] 4.2 Lock at the next activation after access ends, keeping sources, favorites and logins, and verify an integration test that restoring brings them back
- [ ] 4.3 Gate the Apple TV shell on the unlock, and verify a UI test with the stand-in provider

## 5. Devices and family

- [ ] 5.1 Check on real devices that one purchase opens Antenna on iPad, Mac and Apple TV on the same Apple Account, once the shared App Store record exists
- [ ] 5.2 Check on real devices that a Family Sharing member opens Antenna without buying

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
