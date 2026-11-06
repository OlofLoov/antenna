# Design: one App Store unlock, no free tier

## Context

Antenna ships no content, so the player is the only thing it can charge for.
`docs/research/tivimate-user-sentiment.md` records what TiviMate users say.
Its demo free tier causes most one-star reviews. Hidden VOD gating reads as
bait and switch. The Companion app and the five-device cap drive purchase
and refund anger on Trustpilot. Paying users are content with one reasonable
lifetime fee, and forum reputation sells the app rather than the free tier.

Entitlement state touches two earlier decisions: nothing of it goes in
SwiftData (decision adr-0002, SwiftData with private CloudKit for sync) and
receipts are never logged (decision adr-0003, credentials in iCloud
Keychain).

## Goals / Non-Goals

**Goals:**

- One entitlement that unlocks everything, bought and restored through the
  App Store, shareable with Family Sharing.
- The app works offline once entitled.
- A lapsed entitlement never costs the user their setup.

**Non-Goals:**

- A free tier, feature tiers or per-feature flags.
- Accounts, device counts, a companion app, or promo codes outside App Store
  offer codes.
- Trial logic inside the app.

## Decisions

**Paywall until entitled.** The app is free to download and shows only the
paywall on first launch and whenever no entitlement is present.

**StoreKit 2 is the only source of entitlement.** One non-consumable
lifetime product and one auto-renewing yearly subscription, both with Family
Sharing. A trial, if any, is the App Store introductory offer on the
subscription.

**One gate.** Every feature checks the same "is entitled" state. A PR that
adds any other feature gate does not follow this decision.

**Local cache, read from the system.** Entitlement state comes from
`Transaction.currentEntitlements` and is cached locally for offline use. It
never goes in SwiftData and receipts are never logged.

**Lapse returns to the paywall and keeps data.** Sources, favorites and
settings are preserved when an entitlement lapses.

**The listing discloses it.** The App Store description says a purchase is
required.

Options considered:

1. Freemium with a usable free tier (one source, full guide, no sync, no
   multi-view). Rejected because it means two feature matrices to build and
   support, and the research shows free users write the reviews while paid
   users do the selling.
2. TiviMate-style demo free tier (one playlist, two-day EPG, VOD visible but
   locked). Rejected because the research names it as the source of one-star
   reviews.
3. Paid up front. Rejected because it has no yearly option and no App Store
   introductory offer, and price changes or promotions are harder. Family
   Sharing exists for paid apps, but in-app purchase gives the same for both
   products.

## Risks / Trade-offs

- No organic "try it" funnel. A user whose provider does not work finds out
  after paying unless a trial exists, and the refund goes through Apple.
- Fewer downloads and reviews than a free app. Discovery relies on word of
  mouth in forums where TiviMate is already the default.
- Higher App Review scrutiny for an app that does nothing without a
  purchase. The paywall must be unambiguous and the listing must disclose
  the requirement.
- Pricing and trial length live in App Store Connect and change without a
  release.
- Follow-ups: a spec for the paywall, entitlement check and lapse handling;
  a decision on trial length and prices; store listing copy.
