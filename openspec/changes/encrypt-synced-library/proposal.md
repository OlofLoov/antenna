# Proposal

## Why

> As the owner of the account, I want what I watch, search for and set up in Antuna kept in iCloud in a form Apple's servers cannot read.

Today every SwiftData record syncs to the private CloudKit database as plain fields: source names and addresses, imported playlist text, favorites, profile names, watch progress, My list, recent searches, reminders with programme titles, group names, guide settings. CloudKit keeps them encrypted at rest with keys Apple holds, and its servers index and serve them as plain values. The names of the Apple TVs in Play on sit there the same way.

CloudKit has encrypted fields for this. A field marked encrypted is sealed on the device before upload. A field's encryption is fixed when CloudKit first sees it and can never change, so the fields have to be marked before the schema reaches the production environment, which has not happened yet.

Encrypted fields are end-to-end encrypted only for accounts with Advanced Data Protection. Without it, Apple holds the CloudKit service keys in its HSMs and can decrypt them, as it can the rest of standard iCloud data. This change marks the fields now, while that is still possible. Keeping the library from Apple without Advanced Data Protection needs a key of our own in the iCloud Keychain; `design.md` sets out that follow-up and leaves it to the owner.

## What Changes

- Every stored property of every synced SwiftData model is marked for CloudKit encryption.
- The Play on device record keeps the device's name, public key and key date in encrypted values. Its kind, last-seen time and version stay plain.
- `scripts/check-rules.sh` fails on a stored property of a synced model without the mark. An app test checks the same on the built schema.
- The Privacy Policy and the App Store privacy notes say the library is in encrypted fields, end to end with Advanced Data Protection, and what Apple still sees.
- The device checklist's CloudKit step checks the fields show as encrypted before the schema is deployed to production.

Out of scope:

- Encryption with a key Apple never holds, for accounts without Advanced Data Protection (`design.md`, Decision 4).
- Per-device state in UserDefaults, caches and the Keychain, which do not sync through CloudKit or already are end-to-end encrypted.
- The login drop and play requests, which already keep their payloads in encrypted values.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `source-management`: new "The synced library is in encrypted fields".
- `antuna-website`: "The Privacy Policy says where data is kept" says the library is in encrypted fields and when that is end-to-end.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV, which share the models.
- Code: the `@Model` classes in `Apps/Shared/Persistence/`, `CloudKitPlayDevices`, `scripts/check-rules.sh`, an app test.
- Data: local stores open unchanged. The CloudKit development environment has plain fields under the same names and must be reset once before a build with this change syncs. Production has no schema yet.
- Site: the Privacy Policy page and its test.
- Blocked on nothing. The owner resets the development environment in CloudKit Console.
