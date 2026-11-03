# 0002. Sync sources, favorites and settings with SwiftData over private CloudKit

- Status: Accepted
- Date: 2026-11-03

## Context

Users expect a source added on iPhone to appear on Apple TV. Running our own
sync server costs money, creates a privacy liability, and weakens the App
Review position that Antenna only plays the user's own content.

## Decision

One `ModelContainer` with `cloudKitDatabase: .automatic` backed by
`iCloud.se.codecrave.antenna`. `SourceRecord` and `FavoriteRecord` are the
synced models. CloudKit's constraints are hard rules: every stored property
optional or defaulted, no `@Attribute(.unique)`, optional relationships.
Secrets are excluded (see ADR-0003).

## Options considered

1. **Own backend.** Cost, privacy, and App Review risk.
2. **Core Data + NSPersistentCloudKitContainer.** Same constraints, more code.
3. **No sync.** The gap this product exists to close.

## Consequences

- Good: Zero infrastructure. Works per tvOS profile with runs-as-current-user.
- Bad: No uniqueness enforcement, so dedup must happen in code. Sync is
  eventually consistent and cannot be tested in CI.
- Follow-ups: Conflict policy for `sortOrder` collisions. Schema migrations
  need their own ADR each time.
