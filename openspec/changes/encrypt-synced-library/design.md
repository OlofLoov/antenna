# Design

No screen changes, so no board.

## What CloudKit encryption gives

Checked against the iOS 27.2 SDK (Xcode 27.2) and Apple's documentation on 2026-11-28:

- SwiftData has `Schema.Attribute.Option.allowsCloudEncryption`, written `@Attribute(.allowsCloudEncryption)`. It sets Core Data's `NSAttributeDescription.allowsCloudEncryption`, and `NSPersistentCloudKitContainer` then writes the attribute's `CD_` field through `CKRecord.encryptedValues`. It changes nothing in the local store.
- Core Data's header lists the limits: an encrypted attribute must be new to the CloudKit schema, and a field "cannot (ever) change" its encryption state. CloudKit's guide says the same of fields, and that encrypted fields have no index because the server cannot read them.
- An encrypted value is sealed with key material in the user's iCloud Keychain. With Advanced Data Protection on, those keys stay in the iCloud Keychain protection domain and Apple cannot read them. Under standard data protection, Apple's Platform Security guide counts third-party CloudKit encrypted fields among what Advanced Data Protection adds; without it the CloudKit service keys are held in Apple's HSMs, and Apple can decrypt the fields as it can the rest of standard iCloud data.
- `CKAsset` data is always encrypted, with the asset key kept in an encrypted field of the record. A large imported playlist (`playlistData`, external storage) syncs as an asset and gets this already.

So this change makes the library end-to-end encrypted for accounts with Advanced Data Protection, and keeps it out of plain, indexed fields for everyone else. It does not meet the owner's goal for accounts without Advanced Data Protection; Decision 4 covers that.

## Decision 1: which fields

Every stored property of every model in `AntennaSchema.models` is marked, including ids, dates and numbers.

Options:

1. **Only the revealing fields** (names, addresses, titles, queries, channel ids, playlist text). Leaves dates and counters plain: `ProgressRecord.updatedAt` and `position` say when and how long someone watched, and `ReminderRecord.start` says what time they planned to watch. Each new property needs a judgment call.
2. **Every stored property.** Chosen. The rule is one line and a grep can enforce it.

Nothing needs to stay plain. SwiftData's CloudKit mirroring asks the server for zone changes and never queries a field, and the dedupe in code (`id`, `sourceID`, `profileID`, `channelID`) runs on the local store after the records arrive. `#Predicate` fetches run against the local SQLite store, which this option does not touch. There are no relationships, the one kind of value `encryptedValues` cannot hold.

Plain fields that remain, set by CloudKit and `NSPersistentCloudKitContainer` rather than the models: the record type (`CD_SourceRecord` and so on), the record name (a UUID), the zone, `CD_entityName`, the creation and modification times, the user record that made each change, each record's size and the number of records. Apple can still see how many sources, favorites and progress records an account has, how big they are and when they change. That is in the Privacy Policy.

## Decision 2: existing fields

CloudKit cannot make an existing field encrypted. The models' fields already exist as plain `CD_` fields in the development environment of `iCloud.se.codecrave.antenna`, because `ANTENNA_PAID_TEAM` builds have synced there. The production environment has no schema: `docs/release/device-checklist.md`, "add-signing-capabilities 5.2, CloudKit schema in production", is still open, and no build has gone to TestFlight.

Options:

1. **Rename every property** (`name` to `nameSealed` and so on) with `@Attribute(originalName:)`, so the local store migrates by rename and CloudKit gets new `CD_` fields. Works with any schema already in production. The old plain fields stay in the schema for good, and the plain values already in existing records stay on Apple's servers until the record is deleted: SwiftData saves the fields it changed and never clears a field the model no longer has. Every property name in the code gets worse for a schema nobody has shipped.
2. **New record types**, by renaming the model classes with a `SchemaMigrationPlan` that copies old records into new ones. Same leftovers as option 1 in the old types, plus a custom migration stage for thirteen models.
3. **Keep the names and reset the development environment once.** Chosen. A reset in CloudKit Console deletes the development schema and every record in it, plain values included, and the next build creates the fields encrypted. Production gets them encrypted on its first deploy. Local stores open unchanged, since the option is not part of the local model (the app test opens a store written without it).

Option 3 holds only while production has none of these fields. Before the reset, the owner checks in CloudKit Console that the Production schema has no `CD_` record types. If it has them, this change switches to option 1 for the fields already there.

After the reset, a device that synced before has records CloudKit no longer has. `NSPersistentCloudKitContainer` sees the zone gone and uploads its local records again with the new fields. If a device logs export errors instead, deleting the app on it and installing again starts it clean; logins survive in the Keychain.

## Decision 3: Play on device records

`PlayDevice` records are written with `CKRecord` directly, outside SwiftData. Three values move to `encryptedValues` under new keys, since the old keys exist plain in the development schema and the reset removes them:

- `deviceName`, the name the TV gives itself ("Living Room").
- `devicePublicKey` and `deviceKeyDate`. The public key is not secret, but nothing else vouches for it: a sender derives the link's pre-shared key from the key in the TV's record, with no check against the TV itself. A plain field is one Apple's servers could replace with a key of their own. In encrypted values, with Advanced Data Protection on, a replaced value no longer decrypts. The devices read encrypted values as they read plain ones, so the key stays readable to them.

`kind`, `lastSeen` and `version` stay plain. They say only that a device of some kind runs some version and was seen at some time, which the record's modification time already says, and the sweep reads `lastSeen` after fetching, with no index.

With no records in production there is no older reader to keep. A record without the new keys does not list until its device saves again, which it does each time the app starts.

## Decision 4: without Advanced Data Protection (follow-up, for the owner)

Keeping the library from Apple for every account needs a key Apple never holds. The iCloud Keychain is end-to-end encrypted under standard data protection, so a 256-bit key kept there, synchronizable, under `se.codecrave.antenna.sources` like the logins, would do. Options for using it:

1. **Seal each record into one encrypted blob** (AES-GCM with CryptoKit) in a single field of the synced model, with a local-only store of plain models for queries, and a bridge that keeps the two in step. Keeps SwiftData's sync. Every `@Query` (47 today) and `#Predicate` (17) keeps working on the local store. The bridge, conflict handling and the two stores are new code to get right.
2. **Replace SwiftData's CloudKit mirroring with `CKSyncEngine`**, sealing records before upload. Full control of what Apple sees, including record names and types. The largest change: our own change tokens, conflict resolution and retries.
3. **Stay with CloudKit encrypted fields** and say plainly that the library is end-to-end encrypted with Advanced Data Protection. No new key to lose.

Any option with our own key loses the library when the user resets their iCloud Keychain, as CloudKit's encrypted fields do, and a record can arrive before the key does, as a source arrives before its login today. The recommendation is option 1 as its own change after this one; this change is needed under every option, because the fields must be encrypted before the first production deploy or never.

## Regression guard

- `scripts/check-rules.sh` gets a check, "source-management/the-synced-library-is-in-encrypted-fields", that reads each `@Model` class in `Apps/Shared` and fails on a stored `var` without `.allowsCloudEncryption` in its `@Attribute`. An allowlist variable in the check names `File.swift:property` pairs that may stay plain; it is empty.
- `SyncedFieldEncryptionTests` in `Apps/Tests` builds `Schema(AntennaSchema.models)` and expects every attribute of every entity to carry the option, so a model added to the list from another folder is caught too. It also opens an on-disk store written with the models as they were and finds the records.

## Identifiers

- `@Attribute(.allowsCloudEncryption)` on every stored property in `Records.swift`, `ActivityRecords.swift`, `ReminderRecords.swift`, `GroupRecords.swift`, `PreferencesStore.swift`, `PasscodeStore.swift`, `GuideSettingsStore.swift`; `SourceRecord.playlistData` keeps `.externalStorage` beside it.
- `CloudKitPlayDevices.Key.name`, `.publicKey`, `.keyDate` (`deviceName`, `devicePublicKey`, `deviceKeyDate`), written and read through `encryptedValues`.
- `SyncedFieldEncryptionTests`, `UnencryptedSchema` (the old models, in the test).
