# Proposal: sync sources, favorites and settings with SwiftData over private CloudKit (adr-0002)

## Why

Users expect a source added on iPhone to appear on Apple TV. Running our own
sync server costs money, creates a privacy liability, and weakens the App
Review position that Antenna only plays the user's own content.

Accepted on 2026-11-03.

## What Changes

- One `ModelContainer` with `cloudKitDatabase: .automatic`, backed by the
  container `iCloud.se.codecrave.antenna`.
- `SourceRecord` and `FavoriteRecord` are the synced models.
- CloudKit's constraints become hard rules for every model. Each stored
  property is optional or defaulted, nothing uses `@Attribute(.unique)`, and
  relationships are optional.
- Secrets stay out of the synced store (decision adr-0003, credentials in
  iCloud Keychain).

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- Zero infrastructure. Sync works per tvOS profile with runs-as-current-user.
- No uniqueness enforcement, so duplicates must be removed in code.
- Sync is eventually consistent and cannot be tested in CI.
- Follow-ups: a conflict policy for `sortOrder` collisions. Each schema
  migration needs its own decision.
