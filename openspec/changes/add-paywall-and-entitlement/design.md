# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Paywall.dc.html`, `TV-Paywall-Purchasing.dc.html`, `TV-Paywall-Restored.dc.html`, `TV-Paywall-Unavailable.dc.html` (tvOS); `iPad-Paywall.dc.html`, `iPad-Paywall-Purchasing.dc.html`, `iPad-Paywall-Restored.dc.html`, `iPad-Paywall-Unavailable.dc.html` (iPadOS, macOS); `iPhone-Paywall.dc.html`, `iPhone-Paywall-Purchasing.dc.html`, `iPhone-Paywall-Restored.dc.html`, `iPhone-Paywall-Unavailable.dc.html` (iOS).

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall".

Not drawn yet: the launch splash; prices loading; the lapsed paywall with its reason line; the status line (waiting for approval, failed, nothing found, offline, purchases turned off, not sold here); Restore while it runs; "Welcome back" for a Yearly or unshared purchase; the Yearly line with an introductory offer.

## Goals / Non-Goals

**Goals:**
- One entitlement answer that every screen reads, decided on the device, fast at launch from a cache.
- A stand-in provider so onboarding and the shell can test both branches without StoreKit.

**Non-Goals:**
- Trial logic of the app's own. No trial counter or trial start or end date anywhere in the diff.
- Server-side receipt checks.

## Decisions

- The agreed copy and the key for each line are under Copy below. UI tests match on identifiers and copy keys, never on display text.
- Product ids `se.codecrave.antenna.lifetime` (non-consumable) and `se.codecrave.antenna.yearly` (auto-renewable, subscription group `Antenna`). No other id is hard-coded.
- Core (Foundation only): an `EntitlementProvider` protocol with `current()` and an `updates` stream; states unknown, entitled (kind, expiry, family-shared, verified at) and not entitled (never purchased, expired on a date, revoked); a pure resolver over purchase evidence; and a `FixedEntitlementProvider` that onboarding and the shell inject. Each new stream starts at the next change.
- The StoreKit provider lives in `Apps/Shared/Entitlement/`. It listens to transaction updates from launch, ignores and never finishes unverified transactions, and answers `current()` from the cache without waiting on StoreKit. It asks the App Store again in the background after a remembered launch.
- Cache: JSON in standard `UserDefaults` under `paywall.entitlement`, versioned, holding the verdict and any lapse but never a transaction id, signed receipt or Apple Account. The suite is an init parameter so an app group can take over later.
- An empty App Store answer while the cache says entitled sets an "unconfirmed" mark on the first answer of a launch. A second launch with an empty answer revokes.
- `AppRootView` replaces `RootView` as the window root and decides splash, paywall, onboarding, shell in that order, on every scene activation. A lapse found while the scene is active is applied at the next activation. While a restore runs or "Welcome back" shows, the paywall stays until Continue.
- Starting values: the splash waits up to 750 ms, and the App Store counts as unreachable after 10 seconds.
- Terms and Privacy addresses come from Info.plist keys `AntennaTermsURL` and `AntennaPrivacyURL`. A missing or bad value asserts in debug and shows plain text in release. UI-test launch arguments `-antenna.entitlement` and `-antenna.store` exist only under `#if DEBUG`.

## Copy

`PaywallCopy` in AntennaCore maps each key to its en text so a core test can scan it. The view exposes the key as its accessibility value in debug builds for the status line, the lapsed note, the Yearly line and the restored note. Prices are always `Product.displayPrice` as given; the prices on the boards are layout samples.

| Key | en text | Where |
|---|---|---|
| `title.default` | "Unlock Antenna" | title |
| `title.lapsed` | "Antenna is locked again" | title after a lapse |
| `body` | "Antenna plays the TV sources you already have and includes no channels. One purchase unlocks every feature on iPhone, iPad, Mac and Apple TV, for everyone in your Family Sharing group." | body |
| `line.lifetime` | "Pay once. Yours for good." | Lifetime line |
| `line.renews` | "Renews every year. Cancel any time." | Yearly line, no offer or not eligible |
| `line.freeTrial` | "First <period> free, then <displayPrice> per year" | Yearly line, free trial |
| `line.introPrice` | "<offer displayPrice> for <period>, then <displayPrice> per year" | Yearly line, pay up front |
| `line.introPerPeriod` | "<offer displayPrice> per <unit> for <period>, then <displayPrice> per year" | Yearly line, pay as you go |
| `unit.perYear` | "per year" | Yearly unit, every platform |
| `unit.oneTime` | "one time" | Lifetime unit, touch platforms only |
| `price.loading` | "Loading price" | VoiceOver value while prices load |
| `price.unavailable` | "Price unavailable" | price slot on the lapsed paywall when the App Store does not answer |
| `legal` | "Yearly renews automatically until cancelled in Settings. Payment is charged to your Apple Account. Terms of Use and Privacy Policy." | legal line; "Terms of Use" and "Privacy Policy" are the links |
| `status.pending` | "Waiting for approval. Antenna unlocks as soon as the purchase is approved." | status, muted |
| `status.failed` | "The purchase did not go through. Try again." | status, error |
| `status.restoreFailed` | "Restore did not go through. Try again." | status, error |
| `status.nothingFound` | "No purchase found for this Apple Account. If a family member bought Antenna, check that purchase sharing is on in Family Sharing." | status, muted |
| `status.offline` | "You're offline. Connect to the internet and try again." | status, error |
| `status.notAllowed` | "Purchases are turned off on this device. Check Screen Time, or ask the family organiser." | status, muted |
| `status.notInStorefront` | "Antenna can't be bought in this App Store region yet." | status, and the unavailable panel body when the products are not sold here |
| `restored.lifetime` | "Nothing more to pay. Your sources and favourites are where you left them." | restored note, Lifetime |
| `restored.yearly` | "Renews on <expiresAt, locale long style>. Your sources and favourites are where you left them." | restored note, Yearly |
| `lapsed.expired` | "Your yearly subscription ended on <date, locale long style>." | lapsed note |
| `lapsed.revoked` | "The purchase on this Apple Account was refunded or is no longer shared with you." | lapsed note |
| `unavailable.title` | "Can't reach the App Store" | unavailable panel title |

Lines on the boards with no key named yet; the implementation adds keys for them:
- Product names "Lifetime" and "Yearly".
- On Apple TV each product card ends with "Includes Family Sharing".
- While buying, the selected product shows "Waiting for the App Store…" in place of its line.
- Restored title "Welcome back" and body "Your purchase was found for this Apple Account."
- Restored kind: "Lifetime" or "Yearly", followed by " · Shared with you through Family Sharing" on Apple TV or " · Family Sharing" on touch platforms when the purchase is family-shared.
- Unavailable panel body: "Check the connection and try again. If you already bought Antenna, Restore purchase finds it once the connection is back."

Formatting:
- `<period>` is the offer's total length (period times period count for pay as you go) and `<unit>` is its single period unit, both from `DateComponentsFormatter` with `unitsStyle = .full`. A one-unit free trial reads "First week free", "First month free" or "First day free". The core test checks "First week free", "First 3 days free" and "$0.99 per month for 3 months".
- Until eligibility for the offer is known, the Yearly line uses `line.renews` and changes at most once.
- At most one status line shows at a time. A new attempt removes it first, and a new status replaces the old one. In the unavailable panel the status takes the place of the panel body.
- No value contains "IPTV", "provider", a number followed by "channels", "free" (except in `line.freeTrial`), or the name of any service or playlist vendor.

## Risks / Trade-offs

- Open question: is 16 days of offline grace for a remembered Yearly purchase right, also for a cancelled one? 28 days or none are the alternatives. Can be decided during implementation.
- Open question: Restore asks for a Continue tap so the user sees what was found, while a purchase leaves without one. Can be decided during implementation.
- Open question: the lapsed title "Antenna is locked again" and its two reason lines are drafts for the owner.
- [The Apple TV app has its own bundle id until the shared App Store record lands] → the Apple TV paywall is tested against the local StoreKit configuration only, and the cross-device requirement waits.
- [A first empty App Store answer can be wrong on a fresh device] → the app locks only after two launches in a row find nothing.
