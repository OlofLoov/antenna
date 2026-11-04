# 0024. Paywall and entitlement: one App Store unlock, Family Sharing, restore

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- ADR needed: universal purchase requires the tvOS app to share the iOS and Mac bundle id (`project.yml` gives it `se.codecrave.antenna.tv` today); the criteria assume one App Store record, `se.codecrave.antenna`, on every platform.
- Blocked on: that ADR and the `project.yml` change, for AC-34 and for any tvOS test against App Store Connect products. Until it lands the tvOS paywall (AC-13, AC-15, AC-23, AC-35 on Apple TV) runs only against the local `Antenna.storekit` configuration, because in-app products belong to one App Store record. Every criterion can be implemented and tested against that file before the ADR lands.
- Platforms: iOS, iPadOS, macOS, tvOS
- Owns the root chooser's not-entitled branch that 0006 (Scope, AC-1) and 0015 (Scope) leave to "the paywall spec", and the `EntitlementProvider` both inject. Products, prices, trial length and Family Sharing live in App Store Connect and are read at run time; none is hard-coded beyond the two product ids.

## Design

Boards: `docs/design/boards/TV-Paywall.dc.html` (tvOS), `docs/design/boards/iPad-Paywall.dc.html` (iPadOS and macOS, the iPhone column at 390 pt centred over the ground), `docs/design/boards/iPhone-Paywall.dc.html` (iOS). State boards beside them as `<Board>-<State>.dc.html`: `-Purchasing`, `-Restored`, `-Unavailable`. Element identifiers are comments on the boards (DR-11, prefix `paywall.`).
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14. Deviations: DR-2, on tvOS the Lifetime card has initial focus and takes the Focus token; the Yearly card uses the 0.08 surface, so the two cards are never both white. DR-12, the prices on the boards ("$29.99", "$9.99") are layout samples; the app shows `Product.displayPrice` and never a literal. The iPad board stands for macOS too, `paywall.redeem` included (AC-30).
States on the boards:
- Default (`TV-Paywall`, `iPad-Paywall`, `iPhone-Paywall`): mark, `paywall.title` "Unlock Antenna", `paywall.body`, `paywall.product.lifetime` (focused on tvOS) and `paywall.product.yearly`, each with `.price`, `.unit` ("one time" on touch for Lifetime, "per year" for Yearly on every platform; tvOS Lifetime has no unit) and `.line`; on tvOS each card ends with `paywall.product.<kind>.family` "Includes Family Sharing", on touch one `paywall.familyNote` sits under the rows; then `paywall.restore`, `paywall.redeem` (iOS, iPadOS and macOS), `paywall.legal` with `paywall.terms` and `paywall.privacy`. tvOS cards are 520 by 400 pt with a 20 pt eyebrow, 56 pt price, 23 pt line and 20 pt footer; touch rows are 72 pt tall with 17 pt name and price, 13 pt (iPhone) or 15 pt (iPad, Mac) line.
- Purchasing (`-Purchasing`): the selected card or row shows an indeterminate ring and `paywall.product.<kind>.status` "Waiting for the App Store…" in place of its line; the other product sits at 40% opacity (tvOS: 0.04 surface, muted text) and is not selectable; `paywall.restore` and `paywall.redeem` are at 40% opacity and disabled.
- Restored (`-Restored`), drawn for a family-shared Lifetime: `paywall.title` "Welcome back", `paywall.body` "Your purchase was found for this Apple Account.", one `paywall.restored` row with a check tile and `paywall.restored.kind` ("Lifetime · Shared with you through Family Sharing" on tvOS, "Lifetime · Family Sharing" on touch), `paywall.restored.note` "Nothing more to pay. Your sources and favourites are where you left them." in the muted style, and `paywall.continue` as the white button (focused on tvOS).
- Unavailable (`-Unavailable`): `paywall.unavailable` panel with the offline glyph, `paywall.unavailable.title` "Can't reach the App Store" (34 pt tvOS, 17 pt touch), `paywall.unavailable.body` "Check the connection and try again. If you already bought Antenna, Restore purchase finds it once the connection is back.", `paywall.retry` as the white button (focused on tvOS) and `paywall.restore` beside it (tvOS, 0.08 surface pill) or under it (touch, muted text). `paywall.legal` stays.
Not drawn, trivial variants of the drawn boards with the text styles named:
- Launch splash (AC-38): the paywall ground with the mark only, no text, nothing focusable.
- Loading prices (AC-13): both product cards or rows show the 28 pt (touch) or 40 pt (tvOS) ring where the price sits; they keep their size, position and focusability; everything else as the default board.
- Lapsed (AC-24, AC-25): the default board with `paywall.title` "Antenna is locked again" and `paywall.lapsedNote` under `paywall.body` in the body style (30 pt tvOS, 17 pt touch, `#D7DEE8`) reading one of the AC-25 lines.
- `paywall.status` (AC-16 to AC-22, AC-36): one line in the caption style (22 pt tvOS, 15 pt touch), muted for pending and no-purchase, `#FF5F57` for errors. Its slot is marked by a comment on the default boards: on tvOS between the cards and `paywall.restore`, on touch between the rows and `paywall.familyNote`. In the Unavailable state it takes the place of `paywall.unavailable.body`. At most one `paywall.status` exists at a time (AC-17b).
- Restoring (AC-20): `paywall.restore` disabled with the ring at its leading edge, other controls unchanged.
- Restored, Yearly or not shared (AC-20): `paywall.restored.kind` reads "Yearly", with the family suffix only when shared; for Yearly `paywall.restored.note` reads "Renews on <date in the locale's long style>. Your sources and favourites are where you left them." in the same style.
- Free trial and other introductory offers (AC-14): `paywall.product.yearly.line` in the same style as "Renews every year. Cancel any time.".
The boards in the repo are exports; the design canvas needs the same screens.

## Problem

ADR-0006 says Antenna does nothing without an entitlement, and every UI spec since (0006/AC-1, 0015 Scope, DR-14) assumes an entitlement provider that someone else writes. Nobody has written it. Without this spec the first thing a buyer sees on Apple TV is undefined, a refund or a lapsed subscription silently keeps the app open, and TiviMate's five-device and Companion-app complaints (research note, dislikes 2 and 8) have no stated answer.

## Scope

In:
- Two StoreKit 2 products, both Family Sharing enabled in App Store Connect: non-consumable `se.codecrave.antenna.lifetime` and auto-renewable `se.codecrave.antenna.yearly` in subscription group `Antenna`. The yearly product may carry an App Store introductory offer; the app only displays it.
- `EntitlementProvider` protocol, `EntitlementState`, `Entitlement`, `EntitlementLapse`, `EntitlementEvidence`, `EntitlementResolver` and `CachedEntitlement` in `Packages/AntennaCore/Sources/AntennaCore/Entitlement/`. Foundation only (ADR-0005). `FixedEntitlementProvider` test double in the same module so app tests and package tests share it. `PaywallCopy`, the table from string key to en text, lives there too so a core test can scan it (AC-28).
- `CachedEntitlement` takes its `UserDefaults` suite as an init parameter. This spec passes `.standard`; a later spec that adds an app group (an extension reading the entitlement) passes that suite and migrates the key.
- `PaywallModel` (`@MainActor`), the `StoreClient` protocol, and the seams the test plan names: an injected `Clock`, a URL opener, an offer code presenter, a VoiceOver-running flag and a recording root chooser. The apps' test target is added to `project.yml` in the implementing PR if none exists.
- `StoreKitEntitlementProvider` in `Apps/Shared/Entitlement/`: maps `Transaction.currentEntitlements`, `Transaction.updates` and `Product.SubscriptionInfo.Status` onto `EntitlementEvidence` through a `StoreClient` protocol, runs the resolver, applies the provider rules of AC-26 and AC-26b, writes the cache. `current()` returns `CachedEntitlement.verdict(now:)` and never awaits StoreKit.
- `AppRootView` in `Apps/Shared/Views/`, created by this spec's PR, replaces `RootView` as the window root. It evaluates the provider first and the store second: not entitled or unknown shows the paywall (AC-11); entitled hands over to 0006's branches (0006/AC-1, 0006/AC-2, 0006/AC-21 on tvOS, 0010/AC-18 elsewhere, by their own Givens). A root evaluation happens on every `updates` value and on every scene activation, whichever comes first. While a restore runs (AC-20c) or `paywall.restored` is shown the paywall holds the `.entitled` value and leaves only on `paywall.continue` (AC-20); in every other paywall state an `.entitled` value removes the paywall without a tap (AC-15, AC-17, user flow step 2).
- The paywall screen on every platform, shown before onboarding (DR-14).
- Purchase, cancel, pending (Ask to Buy), failure, purchases not allowed, restore (`AppStore.sync()`), offer code redemption on iOS, iPadOS and macOS.
- Local cache so a launch with no network enters the app, and so a lapse survives a relaunch; stale rules for the yearly product.
- Lapse, refund and Family Sharing revocation: return to the paywall at the next root evaluation, stop playback, keep all data.
- Paywall copy that satisfies App Review 5.2.3 and 3.1.2: no provider or service names, no channel counts or content promises, subscription price, period, renewal and cancellation stated, introductory price stated when one exists, Terms of Use and Privacy Policy reachable. The URLs come from Info.plist keys `AntennaTermsURL` and `AntennaPrivacyURL`, read at launch; their values are the store-listing follow-up of ADR-0006.
- Launch arguments `-antenna.entitlement <entitled|none|lapsed>` and `-antenna.store <scenario>` for UI tests, compiled only under `#if DEBUG` (AC-33, AC-33b).
- Accessibility identifiers with prefix `paywall.`.

Out (explicitly):
- Prices, trial length and the Terms and Privacy URL values (App Store Connect and the store-listing follow-up in ADR-0006).
- The change of the tvOS bundle id and the single App Store record (the ADR named in the header; a `project.yml` change in its PR).
- Managing or cancelling the subscription inside the app (Settings spec; `paywall.legal` points at Settings on the device).
- A "manage subscription" or "Antenna is unlocked" row in Settings (Settings spec).
- Promotional offers, win-back offers, price-increase consent sheets (later spec when needed).
- Server-side receipt validation and App Store Server Notifications (none; ADR-0006 reads entitlements on device).
- Onboarding after the paywall (0006) and the tvOS shell (0015); this spec only hands them an entitled state.
- The StoreKit SwiftUI store views (`StoreView`, `SubscriptionStoreView`); the paywall is drawn to the boards.
- Offer code redemption on tvOS (AC-30); codes are redeemed in the App Store app or on another device.

## User flow

All platforms:
1. First launch. The cache is empty. StoreKit is asked for current entitlements and products in parallel. The launch splash shows until entitlements answer or 750 ms pass (AC-38), then the paywall appears with the title, body and two products loading their prices.
2. If StoreKit reports an entitlement (reinstall, second device, family member), the app enters without a tap and 0006 or 0015 takes over. When the answer comes after the splash, the paywall leaves without a tap.
3. Otherwise the prices arrive. On tvOS focus is on Lifetime; swiping right reaches Yearly, down reaches Restore purchase. On touch platforms the rows are tapped; on the Mac they are also reachable with the keyboard.
4. Select or tap a product. The system purchase sheet appears. While it is up the card shows the ring and the rest of the screen is disabled.
5. Success: the sheet closes, the paywall is gone within a second and onboarding (no sources) or the shell (sources exist) appears. Cancel: the paywall is as before. Pending: a muted status line says the purchase waits for approval; the app unlocks whenever the approval arrives, even days later.
6. Restore purchase: the ring on the control, then either the Restored state (Continue enters the app) or a status line saying no purchase was found for this Apple Account.
7. No network and no cache: the Unavailable state with Try again and Restore purchase.

Returning user:
8. A launch with a cached entitlement enters the app directly; StoreKit is checked in the background. A lapse, refund or revocation found there, or arriving later through `Transaction.updates`, stops playback and brings the paywall back at the next root evaluation with the Lapsed title. The lapse is cached, so a relaunch shows the Lapsed title again. Sources, favourites and credentials are untouched, and purchasing or restoring returns the user to the shell with everything in place.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

Quoted copy in a Then is the en value of a `PaywallCopy` key. UI tests never match on display text (`docs/conventions.md`): they assert identifiers, and for `paywall.status`, `paywall.lapsedNote`, `paywall.product.yearly.line` and `paywall.restored.note` the key, which the view exposes as its `accessibilityValue` in debug builds. Integration tests read the model's key and arguments; a core test checks each key's en text against the criterion.

### AC-1 Protocol shape
Given `AntennaCore`
When a test type conforms to `EntitlementProvider`
Then it compiles with exactly `func current() async -> EntitlementState` and `var updates: AsyncStream<EntitlementState> { get }`; `EntitlementState` has the cases `.unknown`, `.entitled(Entitlement)` and `.notEntitled(EntitlementLapse)`; `Entitlement` has `kind` (`.lifetime`, `.yearly`), `expiresAt: Date?`, `familyShared: Bool` and `verifiedAt: Date`; `EntitlementLapse` has `.neverPurchased`, `.expired(Date)` and `.revoked`.

### AC-1c Conformances
Given the types of AC-1
When a test assigns them to `any Sendable & Equatable` and round-trips `Entitlement` and `EntitlementLapse` through `JSONEncoder`
Then both compile and the round trip gives back equal values; `Entitlement/` source files import Foundation and nothing else (checked by a core test reading the import lines).

### AC-1b Evidence shape
Given `AntennaCore`
When `EntitlementEvidence` is constructed
Then it carries `productID: String`, `purchasedAt: Date`, `expiresAt: Date?`, `revocationDate: Date?`, `ownership: Ownership` (`.purchased`, `.familyShared`) and `renewalState: RenewalState?` (`.subscribed`, `.expired`, `.inBillingRetryPeriod`, `.inGracePeriod`, `.revoked`); all are `Sendable`, `Equatable` and Foundation only; `StoreKitEntitlementProvider` maps `Transaction` fields and `Product.SubscriptionInfo.RenewalState` cases onto them one to one and never passes a StoreKit type into the resolver; `.unverified` results from `currentEntitlements` are dropped before the array is built; `renewalState` comes from the `Product.SubscriptionInfo.Status` whose transaction has the same `originalID`, and is `nil` when no status matches. An integration test with a fake `StoreClient` checks each field and the drop.

### AC-2 Test double
Given `FixedEntitlementProvider(state:)`
When a test calls `set(_ state: EntitlementState)`
Then `current()` returns the new state and every stream obtained from `updates` before the call receives it once, in order, so 0006 and 0015 can inject a provider "that reports entitled" or flip it mid-test.

### AC-2b Streams start at the next change
Given a `FixedEntitlementProvider` that has already had `set` called twice
When a test obtains a new stream from `updates` and then calls `set` once more
Then the new stream's first element is the third state, and each access to `updates` returns a distinct stream.

### AC-3 Resolver prefers lifetime
Given evidence for `se.codecrave.antenna.lifetime` with `revocationDate == nil` and live yearly evidence expiring in 10 days
When `EntitlementResolver.resolve(evidence, now:)` runs
Then the result is `.entitled` with `kind == .lifetime`, `expiresAt == nil` and `verifiedAt == now`.

### AC-4 Resolver accepts a live subscription
Given only yearly evidence with `revocationDate == nil`
When the resolver runs
Then the result is `.entitled` with `kind == .yearly` and the evidence's `expiresAt` exactly when `expiresAt > now`, or when `renewalState == .inGracePeriod` and `now < expiresAt + 16 days`; the parameterised test covers `(expiresAt > now, renewalState)` for every `RenewalState` case and `nil`, all accepted because a future `expiresAt` is what Apple's transaction says the user paid for, and `(expiresAt < now, .inGracePeriod)` inside the 16 days. `expiresAt == now` is not accepted.

### AC-4b Several yearly records
Given two or more unrevoked yearly evidence records that AC-4 accepts
When the resolver runs
Then the result is `.entitled(.yearly)` with the latest `expiresAt` among them.

### AC-5 Resolver rejects every other subscription
Given only yearly evidence that AC-4 does not accept
When the resolver runs
Then the result is `.notEntitled(.expired(expiresAt))`; the parameterised test covers `(expiresAt < now, renewalState)` for `.subscribed`, `.expired`, `.inBillingRetryPeriod`, `.revoked` and `nil`, and `(expiresAt < now - 16 days, .inGracePeriod)`; a yearly evidence with `expiresAt == nil` is treated as expired at `purchasedAt`.

### AC-6 Resolver ignores revoked transactions
Given lifetime evidence with a non-nil `revocationDate` and no other evidence
When the resolver runs
Then the result is `.notEntitled(.revoked)`; with a second, unrevoked lifetime transaction the result is `.entitled`.

### AC-6b Revoked lifetime beside a live yearly
Given lifetime evidence with a non-nil `revocationDate` and yearly evidence that AC-4 accepts
When the resolver runs
Then the result is `.entitled` with `kind == .yearly`.

### AC-7 Resolver passes Family Sharing through
Given lifetime evidence with `ownership == .familyShared`
When the resolver runs
Then the result is `.entitled` with `familyShared == true`; with `ownership == .purchased` it is `false`; the verdict is otherwise identical.

### AC-8 Resolver ignores unknown products
Given evidence only for a product id outside the two in Scope, or no evidence at all
When the resolver runs
Then the result is `.notEntitled(.neverPurchased)`. The resolver has no memory; turning that into `.revoked` is the provider's job (AC-26b).

### AC-9 Cache contents
Given an `.entitled` or `.notEntitled` state written through `CachedEntitlement` with a `JSONEncoder` using `.iso8601` dates
When the stored `Data` is decoded as a JSON object
Then its top-level keys are a subset of the schema below; `.notEntitled(.neverPurchased)` and `.unknown` remove the entry; no key or value matches `/transaction|jws|receipt|account/i`; decoding gives back an equal state.

| Key | Present | Value |
|-----|---------|-------|
| `version` | always | `1` |
| `kind` | entitled | `"lifetime"` or `"yearly"` |
| `familyShared` | entitled | Bool |
| `verifiedAt` | entitled | ISO 8601 |
| `expiresAt` | entitled, when non-nil | ISO 8601 |
| `unconfirmedAt` | entitled, set by AC-26b | ISO 8601 |
| `lapse` | lapsed | `"revoked"` or `"expired"` |
| `lapsedAt` | lapse is `"expired"` | ISO 8601 |

### AC-9b Cache versions
Given a stored entry whose `version` is not `1`
When `verdict(now:)` runs
Then the entry is ignored as `.unknown`, so a format change is written as a new version with a migration in the same PR.

### AC-10 Offline verdict from the cache
Given a cached entry and no StoreKit answer
When `CachedEntitlement.verdict(now:)` runs
Then a lifetime entitlement is `.entitled` whatever `now` is; a yearly entitlement is `.entitled` while `now < expiresAt + 16 days` and `.notEntitled(.expired(expiresAt))` after that, whatever its last renewal state was; a lapse entry returns that lapse; a missing entry, or one that fails to decode, is `.unknown`. The asymmetry with AC-5 is deliberate and has its own test: the same yearly record with `renewalState == .expired` at `now = expiresAt + 5 days` is `.notEntitled` from the resolver and `.entitled` from the cache.

### AC-11 Paywall before anything else
Given an injected provider whose `current()` is `.notEntitled` or `.unknown` after the AC-38 splash, any number of `SourceRecord`s, and a credential store in any state
When the app reaches its root view
Then `paywall.root` exists, no `onboarding.*`, `shell.*` or `browse.*` identifier exists, and no request to any source URL has been made (recorded on the injected `URLSession`). This is the branch 0006/AC-1's Given excludes with "0024/AC-11 did not apply".

### AC-12 Cached entitlement enters the app
Given a cache holding a lifetime entitlement and a StoreKit stub that never answers
When the app launches with no network
Then within one second on the injected clock the 0006/AC-1 welcome step (no sources) or the shell (sources) is shown, and `current()` reports `.entitled`.

### AC-12b No paywall on the cached path
Given the launch of AC-12
When the integration test reads the root chooser's recorded branch history
Then it is exactly `[onboarding]` or `[shell]`, with neither `splash` nor `paywall`.

### AC-13 Prices come from the store
Given the paywall with products not yet loaded
When `Product.products(for:)` returns both products
Then `paywall.product.lifetime.price` equals the lifetime `displayPrice` verbatim (a stub returning "299 kr" shows "299 kr"), `paywall.product.yearly.price` equals the yearly `displayPrice` verbatim, `paywall.product.yearly.unit` exists with key `unit.perYear`, on touch platforms `paywall.product.lifetime.unit` exists with key `unit.oneTime` and on tvOS it does not exist, and Lifetime is listed first.

### AC-13c Products before prices
Given the paywall with products not yet loaded
When the user activates either product
Then both products show the ring and stay focusable, the activation is ignored (no `purchase()` call, no Purchasing state, no `paywall.status`), and VoiceOver reads each product with the value key `price.loading` "Loading price".

### AC-14 Introductory offer is shown, never implemented
Given the yearly product and its `isEligibleForIntroOffer`
When the products are shown
Then `paywall.product.yearly.line` uses key `line.freeTrial` "First <period> free, then <displayPrice> per year" for a `.freeTrial` offer, `line.introPrice` "<offer displayPrice> for <period>, then <displayPrice> per year" for `.payUpFront`, `line.introPerPeriod` "<offer displayPrice> per <unit> for <period>, then <displayPrice> per year" for `.payAsYouGo`, and `line.renews` "Renews every year. Cancel any time." when ineligible or when no offer exists. `<period>` is the offer's total length (`period` times `periodCount` for `.payAsYouGo`) and `<unit>` is the offer's single `period.unit`, both formatted by `DateComponentsFormatter` with `unitsStyle = .full`; for a one-unit period the free-trial line reads "First week free", "First month free" or "First day free". The core test checks "First week free", "First 3 days free" and "$0.99 per month for 3 months". Until `isEligibleForIntroOffer` answers the line uses `line.renews` and changes at most once.

### AC-15 Purchase succeeds
Given the paywall with prices loaded and a store stub whose `purchase()` returns `.success(.verified(transaction))` for the selected product
When the user selects `paywall.product.lifetime` or `paywall.product.yearly`
Then `purchase()` is called once with that product, the transaction is finished, the cache holds the matching `Entitlement`, the provider emits `.entitled` on `updates`, and within one second on the injected clock `paywall.root` is gone and a stub root chooser records the entitled branch. Which 0006 or 0010 screen follows is those specs' criteria.

### AC-16 Purchase cancelled
Given the purchasing state
When `purchase()` returns `.userCancelled` or throws `StoreKitError.userCancelled`
Then `paywall.status` does not exist, both products are enabled, a stream obtained from `updates` before the purchase has received no value when `purchase()` has returned and the model's state is default again, and the cache is unchanged.

### AC-17 Purchase pending
Given the purchasing state
When `purchase()` returns `.pending`
Then `paywall.status` has key `status.pending` "Waiting for approval. Antenna unlocks as soon as the purchase is approved." in the muted style, both products are selectable again, and a later verified transaction for that product arriving on `Transaction.updates` applies AC-15 without any tap.

### AC-17c Pending approval after a relaunch
Given a purchase left pending (AC-17) and the app terminated
When the app relaunches and a verified transaction for that product is in `Transaction.updates` or `currentEntitlements`
Then AC-15's outcome applies without any tap.

### AC-17b One status at a time
Given `paywall.status` is shown
When the user starts a purchase, a restore or `paywall.retry`, or the provider emits `.entitled`
Then `paywall.status` is removed before the new attempt starts; a new status replaces the old one, never stacks with it.

### AC-18 Purchase fails
Given the purchasing state
When `purchase()` throws anything not named in AC-16, AC-22 or AC-36, or returns `.success(.unverified)`
Then `paywall.status` has key `status.failed` "The purchase did not go through. Try again." in the error style, both products are selectable, nothing is cached, and the unverified transaction is not finished.

### AC-19 One purchase at a time
Given the purchasing state
When the user activates the other product, `paywall.restore` or, where it exists, `paywall.redeem`
Then no second `purchase()` or `AppStore.sync()` call is made, those controls are not enabled on iOS, iPadOS and macOS and not focusable on tvOS, and `paywall.product.<kind>.status` exists until the result.

### AC-20 Restore finds a purchase
Given the default or unavailable state and a store stub whose `AppStore.sync()` succeeds and whose current entitlements then resolve to `.entitled`
When the user activates `paywall.restore`
Then `paywall.restore` shows the ring and is disabled until the answer, then `paywall.restored` exists with `paywall.restored.kind` reading "Lifetime" or "Yearly", followed by " · Shared with you through Family Sharing" (tvOS) or " · Family Sharing" (touch) when `familyShared` is true; `paywall.restored.note` has key `restored.lifetime` "Nothing more to pay. Your sources and favourites are where you left them." for Lifetime and `restored.yearly` "Renews on <expiresAt in the locale's long style>. Your sources and favourites are where you left them." for Yearly; the cache is written and `updates` emits `.entitled`; `paywall.root` still exists until `paywall.continue` is activated, after which AC-15's hand-over applies.

### AC-20b Restore errors
Given the default or unavailable state
When `AppStore.sync()` throws `StoreKitError.userCancelled` (the user dismissed the Apple Account prompt), or throws any error not named in AC-22
Then for the cancel `paywall.status` does not exist and `paywall.restore` is enabled again; for the other errors `paywall.status` has key `status.restoreFailed` "Restore did not go through. Try again." in the error style and `paywall.restore` is enabled again; nothing is cached in either case.

### AC-20c Restore holds the paywall while updates arrive
Given `paywall.restore` in its restoring state
When the provider emits `.entitled` before `AppStore.sync()` returns
Then `paywall.root` stays, `paywall.restored` appears once `sync()` returns, and `paywall.root` is not removed before `paywall.continue` is activated.

### AC-21 Restore finds nothing
Given the default state and a store stub whose `AppStore.sync()` succeeds and whose entitlements resolve to `.notEntitled`
When the user activates `paywall.restore`
Then `paywall.status` has key `status.nothingFound` "No purchase found for this Apple Account. If a family member bought Antenna, check that purchase sharing is on in Family Sharing." in the muted style, the products stay selectable and nothing is cached; from the unavailable state the same status replaces `paywall.unavailable.body` and `paywall.retry` stays.

### AC-22 Offline during restore or purchase
Given the default state and a store stub whose `AppStore.sync()` or `purchase()` throws a `URLError`, or a `StoreKitError.networkError` wrapping one, with code `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`
When the user activates `paywall.restore` or selects a product
Then `paywall.status` has key `status.offline` "You're offline. Connect to the internet and try again." in the error style and `paywall.restore` and both products are enabled again; from the unavailable state the same status replaces `paywall.unavailable.body` and `paywall.retry` and `paywall.restore` are enabled again.

### AC-23 Store unreachable: error
Given no cache and a store stub whose `Product.products(for:)` throws
When the error arrives
Then `paywall.unavailable` exists with `paywall.unavailable.title` (key `unavailable.title`, "Can't reach the App Store"), and `paywall.restore` is enabled; selecting `paywall.retry` calls `Product.products(for:)` once more, `paywall.retry` is disabled until that call ends so repeated selects make no further call, and the default state returns when it answers with both products. tvOS focus is AC-31d.

### AC-23b Store unreachable: incomplete answer
Given no cache and a store stub whose `Product.products(for:)` returns an array holding exactly one of the two product ids
When the answer arrives
Then AC-23's Then applies.

### AC-23e Products not sold in this storefront
Given no cache and a store stub whose `Product.products(for:)` returns an empty array
When the answer arrives
Then `paywall.unavailable` exists with `paywall.unavailable.body` holding key `status.notInStorefront` (AC-37's text), `paywall.retry` does not exist and `paywall.restore` is enabled.

### AC-23c Store unreachable: deadline
Given no cache and a store stub that has not answered 10 seconds after the paywall appeared on the injected clock
When the deadline passes
Then AC-23's Then applies.

### AC-23d Late answer
Given the unavailable state reached by AC-23c
When a complete answer arrives before `paywall.retry` is selected
Then `paywall.unavailable` is removed and AC-13 applies.

### AC-24 Lapse returns to the paywall and keeps the data
Given the shell or onboarding is shown with an entitled provider, n `SourceRecord`s, m `FavoriteRecord`s and k Keychain items
When `updates` emits `.notEntitled(.expired(date))` or `.notEntitled(.revoked)`
Then at the next root evaluation (Scope) `paywall.root` exists with `paywall.title` key `title.lapsed` "Antenna is locked again", the cache holds the lapse (AC-9), and the store still holds n `SourceRecord`s, m `FavoriteRecord`s and k Keychain items; a following AC-15 or AC-20 shows the shell with the same sources.

### AC-24b Lapse stops playback and source traffic
Given a channel playing and a source or guide refresh scheduled when the lapse of AC-24 arrives
When `paywall.root` appears
Then the player is stopped and released, and the injected `URLSession` records no request to a source or guide URL after that moment.

### AC-24c Lapse survives a relaunch
Given the cache holds a lapse (AC-24) and StoreKit has not answered
When the app relaunches
Then `paywall.root` exists with key `title.lapsed` and the matching `paywall.lapsedNote`, offline included; no Unavailable panel replaces them. When `products(for:)` fails or has not answered within 10 seconds on the injected clock, each product's `.price` shows key `price.unavailable` "Price unavailable" in place of its ring, `paywall.retry` appears under the products, and `paywall.restore` stays enabled.

### AC-25 Lapse wording
Given the lapsed paywall of AC-24
When it is shown
Then `paywall.lapsedNote` has key `lapsed.expired` "Your yearly subscription ended on <date in the locale's long style>." for `.expired(date)`, and `lapsed.revoked` "The purchase on this Apple Account was refunded or is no longer shared with you." for `.revoked`; products, `paywall.restore` and `paywall.legal` are as on the default board.

### AC-26 Background revalidation
Given a launch that entered the app from the cache (AC-12)
When `Transaction.currentEntitlements` answers, and again each time the scene becomes active
Then the resolver runs on the answer, and on `.entitled` the cache's `verifiedAt`, `kind` and `expiresAt` take the answer's values.

### AC-26c Renewal after the offline window
Given a cached yearly entitlement whose `expiresAt + 16 days` is before the injected now
When StoreKit answers with a yearly transaction whose `expiresAt` is after now and `renewalState == .subscribed`
Then the state is `.entitled` and the cache's `expiresAt` equals the answer's; when the answer's `expiresAt` is before now, AC-5 applies.

### AC-26b Empty answer while the cache says entitled
Given the cache holds `.entitled`
When an answer resolves to `.notEntitled(.neverPurchased)` (empty, or only unknown products)
Then `StoreKitEntitlementProvider` keeps reporting `.entitled` and writes `unconfirmedAt: <now>` into the cache entry. Only the first answer of a process launch counts; answers on later scene activations in the same process never set or advance the mark. A signed-out Apple Account or an Apple TV that has not synced yet keeps the app for the rest of that launch.

### AC-26d Second empty launch
Given the cache entry carries `unconfirmedAt` from an earlier launch
When the first answer of this launch also resolves to `.notEntitled(.neverPurchased)`
Then the provider emits `.notEntitled(.revoked)` and AC-24 applies; when that first answer resolves to `.entitled` instead, `unconfirmedAt` is removed.

### AC-27 Updates listener runs from launch
Given the app launched into the shell
When a verified transaction arrives on `Transaction.updates` (a family member's purchase, a renewal, a refund)
Then the resolver runs over current entitlements, the transaction is finished, a transaction with a non-nil `revocationDate` applies AC-6 directly, and the state change, if any, is emitted on `updates` within one second on the injected clock.

### AC-27b Listener order and unverified updates
Given a fake `StoreClient` updates stream
When the app starts
Then the stream has a subscriber, started by `StoreKitEntitlementProvider.init`, before `AppRootView`'s body first runs; an `.unverified` update is ignored, not finished, and changes no state.

### AC-28 Copy
Given `PaywallCopy` in the en locale
When the core test reads it
Then `title.default` is "Unlock Antenna", `body` is "Antenna plays the TV sources you already have and includes no channels. One purchase unlocks every feature on iPhone, iPad, Mac and Apple TV, for everyone in your Family Sharing group.", `line.lifetime` is "Pay once. Yours for good.", and `legal` is "Yearly renews automatically until cancelled in Settings. Payment is charged to your Apple Account. Terms of Use and Privacy Policy." with `paywall.terms` and `paywall.privacy` covering the last two names; no value contains "IPTV", "provider", "channels" preceded by a number, "free" (except in `line.freeTrial`), or the name of any service or playlist vendor. A UI test checks that `paywall.title`, `paywall.body`, `paywall.product.lifetime.line` and `paywall.legal` exist on the default paywall with those keys.

### AC-29 Terms and privacy on iOS, iPadOS and macOS
Given the default paywall on iOS, iPadOS or macOS
When `paywall.terms` or `paywall.privacy` is activated
Then the `AntennaTermsURL` or `AntennaPrivacyURL` value is opened in the system browser (recorded on a fake opener). That `paywall.legal` is one VoiceOver element exposing both links in the links rotor is a manual checklist item.

### AC-29b Terms and privacy on tvOS
Given the default paywall on tvOS
When it is shown
Then `paywall.terms` and `paywall.privacy` are static text showing the two URL values, and while VoiceOver runs `paywall.legal` is focusable, the last stop below `paywall.restore`, so the legal text is read; without VoiceOver it is not focusable.

### AC-29c Missing or malformed URL
Given an Info.plist where `AntennaTermsURL` or `AntennaPrivacyURL` is missing or not an `https` URL
When the paywall is built
Then `AppURLs.read(infoDictionary:)` returns `.invalid(key)`, a debug build calls an injectable assertion handler, and a release build shows that control as static text with no link.

### AC-30 Redeem a code
Given the default paywall on iOS, iPadOS or macOS
When the user activates `paywall.redeem`
Then `offerCodeRedemption(isPresented:)` is presented once (recorded on a fake presenter); on tvOS `paywall.redeem` does not exist. That a redemption producing a verified transaction applies AC-15 through `Transaction.updates` is covered by AC-27 for the transaction and by a manual sandbox checklist item for the sheet.

### AC-31 tvOS initial focus
Given the default paywall on tvOS
When it appears
Then the first focused element is `paywall.product.lifetime`, prices loaded or not, and `paywall.title` and `paywall.body` are not focusable.

### AC-31b tvOS focus moves
Given the default paywall on tvOS
When the user swipes right from `paywall.product.lifetime`, or swipes down from either product
Then focus is on `paywall.product.yearly`, or on `paywall.restore`.

### AC-31c tvOS Menu
Given the default paywall on tvOS
When the UI test presses Menu
Then no `shell.*` or `onboarding.*` identifier appears; a manual checklist item confirms that Menu suspends the app and that after a relaunch `paywall.root` exists.

### AC-31d tvOS focus in other states
Given the paywall on tvOS
When the Purchasing, Restored, Unavailable or Lapsed state appears
Then focus is on the purchasing product, `paywall.continue`, `paywall.retry`, or `paywall.product.lifetime` respectively, and after Purchasing ends focus returns to the product that was selected.

### AC-32 Touch targets
Given the paywall on iOS or iPadOS in the state where each control exists (default for products, `paywall.restore` and `paywall.redeem`; unavailable for `paywall.retry`; restored for `paywall.continue`)
When the control frames are measured
Then each hit area is at least 44 pt tall and the two product rows are at least 72 pt tall and span the column width.

### AC-32b Mac keyboard
Given the paywall on macOS
When the user presses Tab repeatedly, and Return in the unavailable and restored states
Then Tab reaches both products, `paywall.restore`, `paywall.redeem`, `paywall.terms` and `paywall.privacy` in that order, and Return activates `paywall.retry` or `paywall.continue`.

### AC-33 UI test entitlement argument
Given a debug build launched with `-antenna.entitlement none`, `entitled` or `lapsed` and an injected launch clock
When the root view appears
Then the provider is a `FixedEntitlementProvider` reporting `.notEntitled(.neverPurchased)`, `.entitled(Entitlement(kind: .lifetime, expiresAt: nil, familyShared: false, verifiedAt: <launch clock>))` or `.notEntitled(.expired(2026-01-01 00:00 UTC))`, and no StoreKit call is made.

### AC-33b UI test store argument
Given a debug build launched with `-antenna.store <scenario>`, where scenario is one of `loaded`, `slow`, `unavailable`, `purchaseSuccess`, `purchaseCancel`, `purchasePending`, `purchaseFail`, `purchaseOffline`, `notAllowed`, `restoreFound`, `restoreFoundShared`, `restoreNothing`, `restoreOffline`
When the root view appears
Then `StoreKitEntitlementProvider` runs over a stub `StoreClient` that answers per the scenario and no real StoreKit call is made; when `-antenna.entitlement` is also given, it sets only the initial cache contents. Both arguments live inside `#if DEBUG`, so a release build has no code that reads them (checked by a repo-rule grep in `scripts/`, run in CI).

### AC-34 Universal purchase across devices (manual)
Given one Apple Account that bought Lifetime on iPhone, and the bundle id ADR applied
When Antenna is launched on an Apple TV signed into the same account, or on a Mac
Then `Transaction.currentEntitlements` returns that transaction and AC-12 or the no-tap path of the user flow (step 2) applies without a purchase or restore.

### AC-35 Family member unlocks without buying (manual)
Given a family member's Apple Account in the purchaser's Family Sharing group with purchase sharing on
When Antenna is launched on that member's device
Then `Transaction.currentEntitlements` returns the purchase with `ownershipType == .familyShared`, the app enters without a purchase, and nothing in the app counts devices or members.

### AC-36 Purchases not allowed
Given `AppStore.canMakePayments == false`, or `purchase()` throws `Product.PurchaseError.purchaseNotAllowed`
When the paywall is shown, or the user selects a product
Then `paywall.status` has key `status.notAllowed` "Purchases are turned off on this device. Check Screen Time, or ask the family organiser." in the muted style, both products show their prices and are disabled when `canMakePayments` is false, and `paywall.restore` stays enabled.

### AC-37 Product not sold here
Given `purchase()` throws `Product.PurchaseError.productUnavailable` or `StoreKitError.notAvailableInStorefront`
When the user selected a product
Then AC-23's Then applies with `paywall.status` key `status.notInStorefront` "Antenna can't be bought in this App Store region yet." in place of `paywall.unavailable.body`.

### AC-38 Launch splash
Given no cache and a store stub whose `currentEntitlements` answers after d milliseconds on the injected clock
When the app launches
Then for d ≤ 750 and an entitled answer no `paywall.root` ever appears and the entitled branch follows the splash; for d ≤ 750 and a not-entitled answer the paywall appears at d; for d > 750 the paywall appears at 750 ms; nothing on the splash is focusable or has an identifier other than `paywall.splash`.

### AC-39 Scene changes during a purchase
Given the purchasing state
When the scene goes inactive and active again while the system sheet is up
Then the root evaluation keeps the Purchasing state, the ring and `paywall.product.<kind>.status` stay, and no second `purchase()` call is made.

## Edge cases and failure modes

- Offline with a cache: AC-12 and AC-10. Offline without a cache: AC-23. Offline restore or purchase: AC-22. Offline after a lapse: AC-24c.
- Slow store: the 750 ms splash of AC-38, the 10 second deadline of AC-23c and the late-answer rule of AC-23d.
- Malformed data: an `.unverified` transaction is never trusted (AC-18, AC-27b) and is never finished; a product id outside Scope is ignored (AC-8); a cache that fails to decode counts as missing (AC-10); a products answer with one product counts as unavailable (AC-23b); a bad Terms or Privacy URL is AC-29c.
- Credential not yet synced, huge sources: not reached before the paywall. Nothing in this spec reads a source, so a user whose only source is waiting for its Keychain item sees the same paywall as anyone else (AC-11), and after AC-15 lands in 0006/AC-21 or 0010/AC-18.
- First launch with an empty store: AC-38, AC-11, then AC-15 hands over to 0006/AC-1.
- tvOS, remote only: AC-31 to AC-31d. There is no text entry on the paywall. Offer codes are redeemed on another device or in the App Store; the tvOS board carries no redeem control (AC-30).
- Ask to Buy: AC-17. The approval can arrive days later with the app closed; AC-17c picks it up at the next launch.
- Refund: Apple sets `revocationDate` and drops the transaction from `currentEntitlements`. The update through AC-27 is the only immediate path; when the app was closed and missed it, AC-26b and AC-26d leave a refunded user one more launch before the lapse. Accepted. AC-24 and AC-25 handle the screen. The user keeps sources, favourites and credentials.
- Family Sharing turned off by the purchaser, or the member leaves the family: same path as a refund.
- Signed out of the Apple Account, or a fresh Apple TV that has not synced: AC-26b and AC-26d give the rest of one launch before the lapse.
- Expiry while the scene stays active: no timer. The lapse is detected at the next scene activation or launch (AC-26). Accepted because `Transaction.updates` delivers the renewal or refund that changes the verdict.
- Cancelled yearly, offline: AC-10 keeps the app open up to 16 days past `expiresAt` whatever the renewal state. Intended; the alternative is a cache that stores the renewal state, which is out of date offline anyway.
- Both products owned (bought yearly, later lifetime): AC-3, lifetime wins; the subscription keeps renewing until the user cancels it in Settings, which belongs to the Settings spec.
- Device clock set far ahead: a yearly cache expires early (AC-10) but AC-26 revalidates against StoreKit as soon as it answers, so a wrong clock costs at most one paywall appearance while online.
- Cache tampering: on the Mac `defaults write` can put a lifetime entry in the cache and unlock the app offline until StoreKit answers, after which AC-26b applies. Accepted; the key is device-local in standard `UserDefaults`, never in `NSUbiquitousKeyValueStore`.
- Sandbox and TestFlight: no special casing; `Transaction.currentEntitlements` behaves the same.
- No trial logic of the app's own (ADR-0006): the diff contains no trial counter, start date or end date; the impl-reviewer checks this along with AC-14.
- Secrets: the cache (AC-9), the status lines and any log line never contain a transaction id, JWS or Apple Account. The impl-reviewer checks this.
- Nothing from this spec touches SwiftData; `SourceRecord` and `FavoriteRecord` are unchanged (ADR-0002).
- Dynamic Type at the largest accessibility size: the touch column scrolls; the product rows stay at least 72 pt and the legal text stays at or above the caption minimum (DR-4).
- VoiceOver: each product is one element reading name, price, unit and line; `paywall.status` is announced when it appears.

## Test plan

Core tests live in `Packages/AntennaCore/Tests/AntennaCoreTests/EntitlementTests.swift` and run under `swift test` with fixtures of `EntitlementEvidence` arrays and the `PaywallCopy` table. Integration tests drive `PaywallModel` (`@MainActor`) with an injected `StoreClient` protocol wrapping `Product.products(for:)`, `purchase`, `AppStore.sync()`, `AppStore.canMakePayments`, `Transaction.currentEntitlements` and `Transaction.updates`, a fake cache, an injected clock, a recording root chooser and an in-memory `ModelContainer`. Where Xcode's `StoreKitTest` framework is available, one test per purchase outcome runs against an `SKTestSession` with `Antenna.storekit`. UI tests launch with `-antenna.uiTest`, `-antenna.entitlement` (AC-33) and `-antenna.store` (AC-33b), and assert identifiers and copy keys, never display text. Manual items run from the checklist in the implementing PR. Identifiers: `paywall.root`, `paywall.splash`, `paywall.title`, `paywall.body`, `paywall.lapsedNote`, `paywall.product.lifetime`, `paywall.product.lifetime.price`, `paywall.product.lifetime.unit`, `paywall.product.lifetime.line`, `paywall.product.lifetime.status`, `paywall.product.lifetime.family`, `paywall.product.yearly`, `paywall.product.yearly.price`, `paywall.product.yearly.unit`, `paywall.product.yearly.line`, `paywall.product.yearly.status`, `paywall.product.yearly.family`, `paywall.familyNote`, `paywall.status`, `paywall.restore`, `paywall.redeem`, `paywall.legal`, `paywall.terms`, `paywall.privacy`, `paywall.restored`, `paywall.restored.kind`, `paywall.restored.note`, `paywall.continue`, `paywall.unavailable`, `paywall.unavailable.title`, `paywall.unavailable.body`, `paywall.retry`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (compile-time conformance in a test type) | TBD |
| AC-1b | core (compile-time; mapping checked in integration) | TBD |
| AC-1c | core | TBD |
| AC-2 | core | TBD |
| AC-2b | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core (parameterised over the pairs named) | TBD |
| AC-4b | core | TBD |
| AC-5 | core (parameterised over the pairs named) | TBD |
| AC-6 | core | TBD |
| AC-6b | core | TBD |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9 | core (JSON keys, lifetime, yearly, both lapses) | TBD |
| AC-9b | core | TBD |
| AC-10 | core (injected now) | TBD |
| AC-11 | ui (injected provider, recorded URLSession) | TBD |
| AC-12 | integration (fake cache, never-answering store) + ui | TBD |
| AC-12b | integration (recorded branch history) | TBD |
| AC-13 | integration (stub products) + ui | TBD |
| AC-13c | integration | TBD |
| AC-14 | core (period strings) + integration (each payment mode, ineligible, no offer) | TBD |
| AC-15 | integration + ui (both products) | TBD |
| AC-16 | integration (`.userCancelled` result and thrown) | TBD |
| AC-17 | integration (pending, then update) | TBD |
| AC-17b | integration | TBD |
| AC-17c | integration (relaunch with a fresh model over the same fake cache) | TBD |
| AC-18 | integration (thrown error, unverified) | TBD |
| AC-19 | ui (per platform) | TBD |
| AC-20 | integration + ui (purchased and familyShared, lifetime and yearly) | TBD |
| AC-20b | integration | TBD |
| AC-20c | integration (updates emitted before `sync()` returns) | TBD |
| AC-21 | integration (default and unavailable) | TBD |
| AC-22 | integration (each listed code, bare and wrapped, restore and purchase, both states) | TBD |
| AC-23 | integration + ui (tvOS focus) | TBD |
| AC-23b | integration | TBD |
| AC-23c | integration (injected clock) | TBD |
| AC-23d | integration (injected clock) | TBD |
| AC-23e | integration | TBD |
| AC-24 | integration (in-memory ModelContainer, fake credential store) + ui | TBD |
| AC-24b | integration (fake player, recorded URLSession) | TBD |
| AC-24c | integration | TBD |
| AC-25 | integration (both reasons, keys) + core (en text) | TBD |
| AC-26 | integration (scene phase and clock injected) | TBD |
| AC-26b | integration (two activations, with and without an entitled answer between) | TBD |
| AC-26c | integration (injected clock) | TBD |
| AC-26d | integration (two launches over one fake cache) | TBD |
| AC-27 | integration (fake updates stream) | TBD |
| AC-27b | integration | TBD |
| AC-28 | core (strings table scan) + ui (keys) | TBD |
| AC-29 | ui (iOS, macOS; fake opener) + manual (rotor) | TBD |
| AC-29b | ui (tvOS, VoiceOver flag injected) | TBD |
| AC-29c | integration (URL reader returns `.invalid(key)`; injectable assertion handler) | TBD |
| AC-30 | ui (iOS, macOS; fake presenter) + manual (sandbox redemption) | TBD |
| AC-31 | ui (tvOS) | TBD |
| AC-31b | ui (tvOS) | TBD |
| AC-31c | ui (tvOS) + manual (Menu and relaunch) | TBD |
| AC-31d | ui (tvOS, per state via `-antenna.store`) | TBD |
| AC-32 | ui (frames, iOS and iPadOS) | TBD |
| AC-32b | ui (macOS) | TBD |
| AC-33 | ui (debug) | TBD |
| AC-33b | ui (debug) + CI repo-rule grep in `scripts/` | TBD |
| AC-34 | device, needs two signed-in devices, a sandbox account and the bundle id ADR | checklist |
| AC-35 | device, needs a sandbox family group | checklist |
| AC-36 | integration (both triggers) | TBD |
| AC-37 | integration | TBD |
| AC-38 | integration (injected clock, three timings) | TBD |
| AC-39 | integration (scene phase injected) | TBD |

## Required of other specs

These edits block the implementing PRs of 0006 and 0015, not this spec. Until 0006 lands, this spec is implemented behind a stub root chooser (AC-15, AC-12b); the PR that wires `AppRootView` to 0006's screens depends on 0006.

- 0006: Scope and AC-1 say "an injected entitlement provider reporting entitled". Name it `EntitlementProvider` with `FixedEntitlementProvider(state: .entitled(...))`, and add to AC-1's Given "and 0024/AC-11 did not apply". The root chooser order is splash (0024/AC-38), paywall (0024/AC-11), onboarding (0006/AC-1), shell (0006/AC-2), and it lives in `AppRootView` (0024 Scope).
- 0015: Scope's "0006 owns the root chooser (paywall per ADR-0006, ...)" should cite 0024/AC-11 for the paywall branch and `AppRootView` for the chooser, and "Entitlement lapses" under Edge cases should cite 0024/AC-24 and AC-24b.
- 0010: the same lapse sentence, if it has one, cites 0024/AC-24.
- Settings spec (not yet written): a row that shows the entitlement kind and opens the system subscription management, and the place where `paywall.legal` says "Settings".

## Open questions

Decisions made without an interview, for the owner to overturn:

- Both products, as ADR-0006 says: lifetime and yearly, no monthly. Prices on the boards are placeholders.
- Product ids `se.codecrave.antenna.lifetime` and `se.codecrave.antenna.yearly`, subscription group `Antenna`.
- One App Store record on every platform so one purchase unlocks Apple TV; the tvOS bundle id must change from `se.codecrave.antenna.tv`. ADR needed, named in the header.
- The cache is JSON in the standard `UserDefaults` under key `paywall.entitlement`, like 0015's last-channel key, and also stores a lapse (AC-9). An app-group container or a file would be the alternative; neither buys anything until a widget or Top Shelf extension needs the state.
- Offline tolerance for the yearly product is 16 days past `expiresAt` (AC-4, AC-10), matching the longest common billing grace period, and applies to a cancelled subscription too. 28 days or none are the alternatives.
- An empty `currentEntitlements` answer while the cache says entitled lapses only after a second empty answer at the next activation (AC-26b). The alternative was an immediate `.revoked`, which locks out a signed-out user on the first launch.
- The launch splash waits up to 750 ms for StoreKit (AC-38) so a returning user on a new device does not see the paywall flash. Longer waits delay first-time buyers.
- The restored state asks for a Continue tap (AC-20) rather than leaving on its own, so the user sees what was found and whether it came through Family Sharing. A purchase leaves without a tap (AC-15) because the system sheet already confirmed it.
- Store unreachable deadline is 10 seconds (AC-23c), the same as 0015/AC-2b's launch deadline.
- Lapsed title "Antenna is locked again" and the two AC-25 lines. Alternatives: reuse "Unlock Antenna" with only the note.
- Introductory offers of every payment mode are shown with their price (AC-14), as App Review 3.1.2 asks. If App Store Connect only ever carries a free trial, the other two keys stay unused.
- No timer for expiry while the scene stays active (Edge cases). Alternative: a clause in AC-26 firing on the injected clock.
- Offer code redemption on iOS, iPadOS and macOS (AC-30); `offerCodeRedemption(isPresented:)` exists on macOS since 15 and not on tvOS.
- The Terms and Privacy URLs come from `AntennaTermsURL` and `AntennaPrivacyURL` in Info.plist (AC-29); the boards show `codecrave.se/antenna/terms` and `/privacy` as placeholders. The real URLs are the store-listing follow-up of ADR-0006.
- The paywall uses custom views on the boards rather than `SubscriptionStoreView`, so the tvOS focus order and the identifiers are under our control. If App Review asks for the system view, the criteria still hold; only the Design section changes.
- No Settings row for "manage subscription" here; it goes to the Settings spec. Until then the only way to cancel is Settings on the device, which `paywall.legal` says.
- The cache stays in standard `UserDefaults` for now (Scope makes the suite a parameter). Specs written after this one that read the entitlement from an extension own the move to an app group.
- New copy keys without a board line: `price.loading`, `price.unavailable`, `status.restoreFailed`, `status.notAllowed`, `status.notInStorefront`, `restored.yearly`. They use the caption and muted styles already drawn.
