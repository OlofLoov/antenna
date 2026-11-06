# Design: SwiftData with private CloudKit for sync

## Context

Sources, favorites and settings must follow the user across iPhone, iPad, Mac
and Apple TV. A sync server of our own would cost money, hold user data we
are responsible for, and weaken the App Review position that Antenna only
plays the user's own content.

## Goals / Non-Goals

**Goals:**

- A source or favorite added on one device appears on the user's other
  devices.
- No server to run, pay for or secure.

**Non-Goals:**

- Syncing secrets. Credentials go through the Keychain (decision adr-0003,
  credentials in iCloud Keychain).
- Strong consistency or uniqueness enforced by the store.

## Decisions

**SwiftData over the user's private CloudKit database.** One `ModelContainer`
with `cloudKitDatabase: .automatic`, container `iCloud.se.codecrave.antenna`.
`SourceRecord` and `FavoriteRecord` sync. CloudKit imposes three rules, and
they are hard constraints: every stored property optional or defaulted, no
`@Attribute(.unique)`, relationships optional.

Options considered:

1. Own backend. Rejected for cost, privacy and App Review risk.
2. Core Data with `NSPersistentCloudKitContainer`. Same constraints and more
   code.
3. No sync. Rejected because sync is the gap this product exists to close.

## Risks / Trade-offs

- No uniqueness enforcement, so deduplication happens in code.
- Sync is eventually consistent and cannot be exercised in CI.
- Works per tvOS profile through runs-as-current-user.
- Follow-up: a conflict policy for `sortOrder` collisions.
- Follow-up: every schema migration gets its own decision.
