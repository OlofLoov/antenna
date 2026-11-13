# Proposal

## Why

> As a buyer, I want to pay once, share the purchase with my family, and restore it on a new device without contacting anyone.

Antenna has no free tier. One purchase unlocks everything, and the app does nothing without it. Every screen change assumes something checks for that purchase. Nothing does. Without this change the first thing a buyer sees on Apple TV is undefined, and a refund or an ended subscription silently leaves the app open. The two complaints TiviMate users make most about paying, a five-device limit and a separate companion app, have no stated answer.

Not reviewed yet.

## What Changes

- Two App Store products, both shared through Family Sharing: Lifetime (pay once) and Yearly (renews every year). Yearly may carry an App Store introductory offer, such as a free first month. The app only shows it.
- A paywall on every platform, shown before onboarding.
- Buying, with every outcome the App Store can give: success, cancel, waiting for a parent's approval (Ask to Buy), failure, and purchases turned off on the device.
- Restore purchase, and redeeming an offer code on iPhone, iPad and Mac.
- The purchase is remembered on the device, so the app opens with no network and an ended subscription stays locked across relaunches.
- The app locks again when a subscription ends, a purchase is refunded or Family Sharing stops sharing it, and keeps every source, favorite and login.
- Paywall wording that passes App Review: no provider names or channel promises, the subscription's price, period, renewal and how to cancel, any introductory price, and links to the Terms of Use and Privacy Policy.
- One place every other screen asks "is the app unlocked?", with a stand-in that onboarding and the Apple TV shell use in their tests.

Out of scope:
- The prices, trial length and the Terms and Privacy addresses, which are set in App Store Connect and the store listing.
- Moving the Apple TV app onto the shared App Store record.
- Managing or canceling the subscription inside the app, and a Settings row showing what was bought.
- Promotional and win-back offers, and price-increase consent.
- Checking purchases on a server. The app reads them on the device.
- Onboarding and the Apple TV shell after the paywall.
- Apple's ready-made store screens. The paywall follows the boards.
- Redeeming offer codes on Apple TV.

## Capabilities

### New Capabilities
- `paywall-and-entitlement`: one App Store unlock shown before anything else, shared through Family Sharing, restorable, and locking again when access ends.

### Modified Capabilities
- `tvos-shell`: the shell opens only once the app is unlocked.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `tvos-shell` and the changes `add-first-run-onboarding` and `add-live-tv-on-iphone-ipad-mac`. This change fills the "no purchase" branch that onboarding and the shell leave to it.
- Blocked on: one App Store record for every platform, so one purchase also unlocks Apple TV. The Apple TV app has its own bundle id today, and this change assumes it moves onto the shared one. Until then the Apple TV paywall is tested only against the local StoreKit configuration file, and the requirement "One purchase on every device" waits.
