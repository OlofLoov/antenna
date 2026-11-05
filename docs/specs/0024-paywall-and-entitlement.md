# 0024. Paywall and entitlement: one App Store unlock, Family Sharing, restore

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Follow-up ADR: one App Store record for every platform, so one purchase also unlocks Apple TV. The Apple TV app has its own bundle id today; this spec assumes it moves onto the shared one. Until then the Apple TV paywall is tested only against the local StoreKit configuration file, and AC-34 waits.
- Builds on specs: 0006, 0010, 0015 (fills the "no purchase" branch that 0006 and 0015 leave to this spec)
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-26

## Summary

For anyone who installs Antenna. The app does nothing until it is paid for, as ADR-0006 decides: the first screen is a paywall offering a one-time Lifetime purchase and a Yearly subscription, at the prices the App Store shows for the user's region. One purchase unlocks Antenna on every iPhone, iPad, Mac and Apple TV on the same Apple Account and for everyone in the buyer's Family Sharing group, and Restore purchase finds it again on a new device. If a subscription ends or a purchase is refunded, the app locks again the next time it is opened, but keeps every source and favorite. There is no free tier, no trial of the app's own, no device limit and no subscription management inside the app.

## Design

Boards: `docs/design/boards/TV-Paywall.dc.html`, `TV-Paywall-Purchasing.dc.html`, `TV-Paywall-Restored.dc.html`, `TV-Paywall-Unavailable.dc.html` (tvOS); `iPad-Paywall.dc.html`, `iPad-Paywall-Purchasing.dc.html`, `iPad-Paywall-Restored.dc.html`, `iPad-Paywall-Unavailable.dc.html` (iPadOS, macOS); `iPhone-Paywall.dc.html`, `iPhone-Paywall-Purchasing.dc.html`, `iPhone-Paywall-Restored.dc.html`, `iPhone-Paywall-Unavailable.dc.html` (iOS).
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14.
Not drawn: the launch splash; prices loading; the lapsed paywall with its reason line; the status line (waiting for approval, failed, nothing found, offline, purchases turned off, not sold here); Restore while it runs; "Welcome back" for a Yearly or unshared purchase; the Yearly line with an introductory offer.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

ADR-0006 says Antenna does nothing without a purchase, and every screen spec since (0006, 0015, DR-14) assumes something checks for one. Nothing does. Without this spec the first thing a buyer sees on Apple TV is undefined, a refund or an ended subscription silently leaves the app open, and the two complaints TiviMate users make most about paying, a five-device limit and a separate companion app, have no stated answer.

## Scope

In:
- Two App Store products, both shared through Family Sharing: Lifetime (pay once) and Yearly (renews every year). The Yearly product may carry an App Store introductory offer, such as a free first month; the app only shows it.
- The paywall on every platform, shown before onboarding.
- Buying, with the outcomes the App Store can give: success, cancel, waiting for a parent's approval (Ask to Buy), failure, and purchases turned off on the device.
- Restore purchase, and redeeming an offer code on iPhone, iPad and Mac.
- Remembering the purchase on the device, so the app opens with no network and an ended subscription stays locked across relaunches.
- Locking again when a subscription ends, a purchase is refunded or Family Sharing stops sharing it, while keeping every source, favorite and login.
- Paywall wording that passes App Review: no provider names or channel promises, the subscription's price, period, renewal and how to cancel, any introductory price, and links to the Terms of Use and Privacy Policy.
- The piece every other screen asks "is the app unlocked?", including a stand-in that 0006 and 0015 use in their tests.

Out (explicitly):
- The prices, trial length and the Terms and Privacy addresses (set in App Store Connect and the store listing).
- Moving the Apple TV app onto the shared App Store record (the follow-up ADR).
- Managing or cancelling the subscription inside the app, and a Settings row showing what was bought.
- Promotional and win-back offers, and price-increase consent.
- Checking purchases on a server; the app reads them on the device.
- Onboarding and the Apple TV shell after the paywall (0006, 0015).
- Apple's ready-made store screens; the paywall follows the boards.
- Redeeming offer codes on Apple TV.

## User flow

1. First launch. A short splash waits briefly for the App Store, then the paywall shows its title, a sentence on what Antenna is, and the two products while their prices load.
2. If the App Store already knows a purchase (a reinstall, a second device, a family member), the app opens without a tap.
3. Otherwise the user picks a product. On Apple TV focus starts on Lifetime. The system purchase sheet appears and the rest of the screen waits.
4. Success: the paywall goes, and onboarding or the app appears. Cancel: the paywall is as before. Waiting for approval: a line says so, and the app unlocks whenever the approval comes, even days later.
5. Restore purchase: either "Welcome back" with what was found and a Continue button, or a line saying no purchase was found for this Apple Account.
6. No network and nothing remembered: a panel says the App Store cannot be reached, with Try again and Restore purchase.
7. Returning user: the app opens straight away and checks with the App Store in the background. If the purchase has ended, the next time the app is opened or brought back the paywall says the app is locked again and why.

## Acceptance criteria

Ids keep their numbers from the earlier draft, so some numbers are missing.

### AC-4 A purchase counts while it is paid up
Given purchase records for this Apple Account
When the app decides whether it is unlocked
Then Lifetime unlocks it for good, Yearly unlocks it until its end date or through the App Store's billing grace period (the days Apple keeps a subscription active while it retries a failed payment), a refunded purchase counts for nothing, and owning both counts as Lifetime.

### AC-11 Nothing works before the app is unlocked
Given a device with no purchase on its Apple Account
When the app launches
Then the paywall is the only thing shown, and no source, playlist or guide is contacted.

### AC-12 A buyer goes straight in
Given a device that has already seen a valid purchase on this Apple Account
When the app launches without a network
Then onboarding or the app appears without the paywall ever showing.

### AC-13 Prices come from the App Store
Given the App Store answers with the two products
When the paywall shows
Then each product shows the App Store's price for the user's region, exactly as given, Yearly says it is per year and renews until cancelled, and an introductory offer is described with its price and length.

### AC-15 Buy once and you're in
Given the paywall with prices shown
When the user buys either product and the App Store confirms it
Then the paywall leaves and onboarding or the app appears.

### AC-17 Waiting for a parent's approval
Given a family member under Ask to Buy
When they buy a product and the purchase waits for approval
Then the paywall says it is waiting for approval, and the app unlocks without a tap as soon as the approval arrives, also when that happens after a relaunch.

### AC-20 Restore your purchase
Given a purchase made on another device or by a family member
When the user chooses Restore purchase
Then the paywall says "Welcome back", names what was found and whether it came through Family Sharing, and Continue opens the app.

### AC-23 The App Store cannot be reached
Given no network or an App Store that does not answer, and no remembered purchase
When the paywall loads
Then a panel says the App Store cannot be reached, with Try again and Restore purchase, and a late answer replaces the panel with the products.

### AC-24 When access ends, the app locks and keeps your data
Given an unlocked app with sources, favorites and saved logins, and the App Store has reported that the subscription ended, the purchase was refunded, or Family Sharing stopped sharing it
When the app is opened or brought back to the front
Then playback does not resume, no source is contacted any more, the paywall says "Antenna is locked again" with the reason and date, it stays that way across relaunches and offline, and buying or restoring brings back everything as it was.

### AC-28 Honest paywall wording
Given the paywall on any platform
When the user reads it
Then it names no provider, channel count or content, says Antenna includes no channels, and links to the Terms of Use and Privacy Policy (shown as text on Apple TV, where there is no browser).

### AC-34 One purchase on every device
Given a purchase on an iPhone
When the same Apple Account opens Antenna on an iPad, Mac or Apple TV
Then the app opens there without buying or restoring.

### AC-35 Family members unlock without buying
Given a purchase by the organizer of a Family Sharing group
When another member of the group opens Antenna
Then the app opens without a purchase, and nothing in the app counts devices or members.

## Edge cases

- A cancelled purchase leaves the paywall as it was; a failed one adds a line asking the user to try again; only one purchase or restore runs at a time.
- Restore finds nothing: the paywall says so and suggests checking purchase sharing in Family Sharing.
- Restore finds only an ended subscription: the paywall says when it ended and shows the products.
- Antenna not sold in the user's region: the panel says so and offers no Try again.
- Slow App Store at launch: a returning user on a new device does not see the paywall flash before the app opens.
- Access ends while a programme is playing: it keeps playing, and the app locks at the next return to the app, never mid-programme.
- Offline with a remembered Yearly purchase: the app stays open up to 16 days past the end date, then locks.
- Signed out of the Apple Account, or a new Apple TV that has not synced: the first empty answer from the App Store is not trusted; the app locks only if the next launch also finds nothing.
- A refund while the app was closed: it may take one more launch before the app locks.
- Purchases turned off by Screen Time: the paywall says so and only Restore purchase works.
- The device clock set far ahead: a remembered Yearly purchase may lock early, until the App Store answers.
- A user whose only source is still waiting for its login sees the same paywall as anyone else.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-4 | core |
| AC-11 | ui |
| AC-12 | integration |
| AC-13 | integration |
| AC-15 | integration |
| AC-17 | integration |
| AC-20 | integration |
| AC-23 | integration |
| AC-24 | integration |
| AC-28 | core |
| AC-34 | device |
| AC-35 | device |

## Open questions

- Is 16 days of offline grace for a remembered Yearly purchase right, also for a cancelled one? 28 days or none are the alternatives. Changes the edge case, not a criterion; can be decided in the plan.
- Restore asks for a Continue tap so the user sees what was found, while a purchase leaves without one. Can be decided in the plan.
- The lapsed title "Antenna is locked again" and its two reason lines are drafts for the owner. Can be decided in the plan.

## Notes for the plan

- The previous revision of this spec (git history) holds the agreed copy: titles, body, product lines, status lines, the lapsed lines, the unavailable panel, and the copy key per line. UI tests match on identifiers and copy keys, never on display text.
- Product ids `se.codecrave.antenna.lifetime` (non-consumable) and `se.codecrave.antenna.yearly` (auto-renewable, subscription group `Antenna`); none other is hard-coded.
- Core (Foundation only, ADR-0005): an `EntitlementProvider` protocol with `current()` and an `updates` stream; states unknown, entitled (kind, expiry, family-shared, verified at) and not entitled (never purchased, expired on a date, revoked); a pure resolver over purchase evidence; and a `FixedEntitlementProvider` that 0006 and 0015 inject. Each new stream starts at the next change.
- The StoreKit provider lives in `Apps/Shared/Entitlement/`, listens to transaction updates from launch, ignores and never finishes unverified transactions, and answers `current()` from the cache without waiting on StoreKit. It asks the App Store again in the background after a remembered launch.
- Cache: JSON in standard `UserDefaults` under `paywall.entitlement`, versioned, holding the verdict and any lapse but never a transaction id, signed receipt or Apple Account. The suite is an init parameter so an app group can take over later.
- An empty App Store answer while the cache says entitled sets an "unconfirmed" mark on the first answer of a launch; a second launch with an empty answer revokes.
- `AppRootView` replaces `RootView` as the window root and decides splash, paywall, onboarding (0006), shell (0006, 0015) in that order, on every scene activation. A lapse found while the scene is active is applied at the next activation. While a restore runs or "Welcome back" shows, the paywall stays until Continue.
- Starting values from the earlier draft: the splash waits up to 750 ms; the App Store counts as unreachable after 10 seconds.
- Terms and Privacy addresses come from Info.plist keys `AntennaTermsURL` and `AntennaPrivacyURL`; a missing or bad value asserts in debug and shows plain text in release. UI-test launch arguments `-antenna.entitlement` and `-antenna.store` exist only under `#if DEBUG`.
- No trial logic of the app's own: no trial counter or start or end date anywhere in the diff (ADR-0006).

## Dropped

- Moved to the implementation plan: AC-1, AC-1b, AC-1c, AC-2, AC-2b, AC-8, AC-9, AC-9b, AC-13c, AC-17b, AC-20b, AC-20c, AC-22, AC-26b, AC-26c, AC-26d, AC-27, AC-27b, AC-29c, AC-30, AC-31, AC-31b, AC-31c, AC-31d, AC-32, AC-32b, AC-33, AC-33b, AC-26, AC-36, AC-38, AC-39.
- Moved to Edge cases: AC-16, AC-18, AC-19, AC-21, AC-23e, AC-37.
- Merged into AC-4: AC-3, AC-4b, AC-5, AC-6, AC-6b.
- Merged into AC-12: AC-10, AC-12b.
- Merged into AC-13: AC-14.
- Merged into AC-17: AC-17c.
- Merged into AC-23: AC-23b, AC-23c, AC-23d.
- Merged into AC-24: AC-24b, AC-24c, AC-25.
- Merged into AC-28: AC-29, AC-29b.
- Merged into AC-35: AC-7.
