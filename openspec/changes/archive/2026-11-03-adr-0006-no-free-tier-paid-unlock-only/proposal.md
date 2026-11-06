# Proposal: sell every feature behind one App Store unlock, with no free tier (adr-0006)

## Why

Antenna ships no content, so its only revenue is the player itself. The
TiviMate research (`docs/research/tivimate-user-sentiment.md`) shows that
TiviMate's crippled free tier is the main source of its one-star reviews
("almost nothing useful happens in the 'free' version"), that undisclosed
gating of VOD behind Premium reads as a bait and switch, and that the
separate Companion app and five-device cap generate the purchase and refund
anger on Trustpilot. The same research shows paying users are happy with
"one reasonable fee for a lifetime", and that reputation in forums sells the
app, not the free tier.

A usable free tier was considered and rejected. It means maintaining two
feature matrices and still invites "doesn't work with my provider" reviews
from people who paid nothing.

Serves US-26: "As a buyer, I want to pay once, share the purchase with my
family, and restore it on a new device without contacting anyone."

Accepted on 2026-11-03. No spec was related when it was accepted.

## What Changes

- Antenna has no free tier. The app is free to download, but no feature
  works without an active entitlement. On first launch, and whenever no
  entitlement is present, the app shows the paywall and nothing else.
- Entitlements come only from StoreKit 2: one non-consumable lifetime
  product and one auto-renewing yearly subscription, both with Family
  Sharing. No other unlock path exists. No promo codes outside App Store
  offer codes, no account, no device count, no companion app.
- Every feature sits behind the same single entitlement. No tiers and no
  per-feature flags. A PR that adds a feature gate other than "is entitled"
  does not follow this decision.
- A free trial, if offered, is the App Store introductory offer on the
  subscription. The app never implements trial logic of its own.
- Entitlement state is read from `Transaction.currentEntitlements` and
  cached locally so the app works offline. It is never stored in SwiftData
  (decision adr-0002) and receipts are never logged (decision adr-0003).
- When an entitlement lapses, the app returns to the paywall. Sources,
  favorites and settings are kept, not deleted.
- The App Store description states that a purchase is required.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- One code path, with no tier logic anywhere in Apps or AntennaCore.
- Family Sharing removes the device-cap complaint outright. Apple handles
  purchase, restore and refunds, so no Companion-app equivalent exists to
  attract one-star reviews.
- Pricing and trial length live in App Store Connect and change without a
  release.
- No organic "try it" funnel. Someone whose provider does not work with
  Antenna finds out after paying unless a trial exists, and their refund
  goes through Apple with no say from us.
- Fewer downloads and reviews than a free app. Discovery depends on word of
  mouth in the same forums where TiviMate is already the default.
- App Review looks harder at an app that does nothing without a purchase.
  The paywall must be unambiguous and the listing must disclose the
  requirement.
- Follow-ups: a spec for the paywall, the entitlement check and lapse
  handling; a decision on trial length and prices; store listing copy.
