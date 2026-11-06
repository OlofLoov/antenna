# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Paywall.dc.html`, `TV-Paywall-Purchasing.dc.html`, `TV-Paywall-Restored.dc.html`, `TV-Paywall-Unavailable.dc.html` (tvOS); `iPad-Paywall.dc.html`, `iPad-Paywall-Purchasing.dc.html`, `iPad-Paywall-Restored.dc.html`, `iPad-Paywall-Unavailable.dc.html` (iPadOS, macOS); `iPhone-Paywall.dc.html`, `iPhone-Paywall-Purchasing.dc.html`, `iPhone-Paywall-Restored.dc.html`, `iPhone-Paywall-Unavailable.dc.html` (iOS).

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall".

Not drawn yet: the launch splash; prices loading; the lapsed paywall with its reason line; the status line (waiting for approval, failed, nothing found, offline, purchases turned off, not sold here); Restore while it runs; "Welcome back" for a Yearly or unshared purchase; the Yearly line with an introductory offer.

Decisions this builds on: adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only).

## Goals / Non-Goals

**Goals:**
- One entitlement answer that every screen reads, decided on the device, fast at launch from a cache.
- A stand-in provider so onboarding and the shell can test both branches without StoreKit.

**Non-Goals:**
- Trial logic of the app's own. No trial counter or trial start or end date anywhere in the diff (adr-0006).
- Server-side receipt checks.

## Decisions

- The previous revision of the old spec (`docs/specs/0024-paywall-and-entitlement.md` at 0bce26a) holds the agreed copy: titles, body, product lines, status lines, the lapsed lines, the unavailable panel, and the copy key per line. UI tests match on identifiers and copy keys, never on display text.
- Product ids `se.codecrave.antenna.lifetime` (non-consumable) and `se.codecrave.antenna.yearly` (auto-renewable, subscription group `Antenna`). No other id is hard-coded.
- Core (Foundation only, adr-0005): an `EntitlementProvider` protocol with `current()` and an `updates` stream; states unknown, entitled (kind, expiry, family-shared, verified at) and not entitled (never purchased, expired on a date, revoked); a pure resolver over purchase evidence; and a `FixedEntitlementProvider` that onboarding and the shell inject. Each new stream starts at the next change.
- The StoreKit provider lives in `Apps/Shared/Entitlement/`. It listens to transaction updates from launch, ignores and never finishes unverified transactions, and answers `current()` from the cache without waiting on StoreKit. It asks the App Store again in the background after a remembered launch.
- Cache: JSON in standard `UserDefaults` under `paywall.entitlement`, versioned, holding the verdict and any lapse but never a transaction id, signed receipt or Apple Account. The suite is an init parameter so an app group can take over later.
- An empty App Store answer while the cache says entitled sets an "unconfirmed" mark on the first answer of a launch. A second launch with an empty answer revokes.
- `AppRootView` replaces `RootView` as the window root and decides splash, paywall, onboarding, shell in that order, on every scene activation. A lapse found while the scene is active is applied at the next activation. While a restore runs or "Welcome back" shows, the paywall stays until Continue.
- Starting values: the splash waits up to 750 ms, and the App Store counts as unreachable after 10 seconds.
- Terms and Privacy addresses come from Info.plist keys `AntennaTermsURL` and `AntennaPrivacyURL`. A missing or bad value asserts in debug and shows plain text in release. UI-test launch arguments `-antenna.entitlement` and `-antenna.store` exist only under `#if DEBUG`.

## Risks / Trade-offs

- Open question: is 16 days of offline grace for a remembered Yearly purchase right, also for a cancelled one? 28 days or none are the alternatives. Can be decided during implementation.
- Open question: Restore asks for a Continue tap so the user sees what was found, while a purchase leaves without one. Can be decided during implementation.
- Open question: the lapsed title "Antenna is locked again" and its two reason lines are drafts for the owner.
- [The Apple TV app has its own bundle id until the shared App Store record lands] → the Apple TV paywall is tested against the local StoreKit configuration only, and the cross-device requirement waits.
- [A first empty App Store answer can be wrong on a fresh device] → the app locks only after two launches in a row find nothing.
