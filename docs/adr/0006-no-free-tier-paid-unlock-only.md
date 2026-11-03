# 0006. Sell every feature behind one App Store unlock, with no free tier

- Status: Proposed
- Date: 2026-11-03
- Related specs: none yet

## Context

Antenna ships no content, so its only revenue is the player itself. The
TiviMate research (`docs/research/tivimate-user-sentiment.md`) shows that
its crippled free tier is the main source of one-star reviews ("almost
nothing useful happens in the 'free' version"), that undisclosed gating of
VOD behind Premium reads as a bait and switch, and that the separate
Companion app and five-device cap generate the purchase and refund anger on
Trustpilot. The same research shows paying users are happy with "one
reasonable fee for a lifetime" and that the free tier is not what sells the
app; reputation in forums is. A usable free tier was considered and rejected
because it means maintaining two feature matrices and still inviting
"doesn't work with my provider" reviews from people who paid nothing.

## Decision

Antenna has no free tier. The app is free to download, but no feature works
without an active entitlement. On first launch, and whenever no entitlement
is present, the app shows the paywall and nothing else.

- Entitlements come only from StoreKit 2: one non-consumable lifetime
  product and one auto-renewing yearly subscription. Both have Family
  Sharing enabled. No other unlock path exists: no promo codes outside
  App Store offer codes, no account, no device count, no companion app.
- Every feature is behind the same single entitlement. There are no tiers
  and no per-feature flags. A PR that adds a feature gate other than
  "is entitled" does not follow this ADR.
- A free trial, if offered, is the App Store introductory offer on the
  subscription. The app never implements trial logic of its own.
- Entitlement state is read from `Transaction.currentEntitlements` and
  cached locally so the app works offline. It is never stored in SwiftData
  (ADR-0002) and receipts are never logged (ADR-0003).
- When an entitlement lapses, the app returns to the paywall. Sources,
  favourites and settings are preserved, not deleted.
- The App Store description states that a purchase is required.

## Options considered

1. **Freemium with a usable free tier** (one source, full guide, no sync,
   no multi-view). Two feature matrices to build and support, and the
   research shows free users write the reviews while paid users do the
   selling.
2. **TiviMate-style demo free tier** (one playlist, two-day EPG, VOD visible
   but locked). The exact thing the research identifies as the source of
   one-star reviews.
3. **Paid up front.** No yearly option, no App Store introductory offer, and
   price changes or promotions are harder. Family Sharing exists for paid
   apps but IAP gives the same for both products.

## Consequences

- Good: One code path. No tier logic anywhere in Apps or AntennaCore.
- Good: Family Sharing removes the device cap complaint outright, and Apple
  handles purchase, restore and refunds, so there is no Companion-app
  equivalent to get one-star reviews.
- Good: Pricing and trial length live in App Store Connect and can change
  without a release.
- Bad: No organic "try it" funnel. Someone whose provider does not work
  with Antenna finds out after paying, unless a trial exists, and their
  refund goes through Apple with us having no say.
- Bad: Fewer downloads and reviews than a free app. Discovery depends on
  word of mouth in the same forums where TiviMate is already the default.
- Bad: App Review scrutiny is higher for an app that does nothing without a
  purchase. The paywall must be unambiguous and the listing must disclose
  the requirement.
- Follow-ups: a spec for the paywall, entitlement check and lapse handling;
  a decision on trial length and prices; store listing copy.
