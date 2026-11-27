# Tasks

## 1. Encrypted fields

- [x] 1.1 `@Attribute(.allowsCloudEncryption)` on every stored property of the models in `AntennaSchema.models`
- [x] 1.2 `CloudKitPlayDevices` writes and reads the name, public key and key date through `encryptedValues`
- [x] 1.3 `scripts/check-rules.sh` fails on a stored property of a synced model without the option, with an empty allowlist
- [x] 1.4 `SyncedFieldEncryptionTests`: every schema attribute is encrypted, and a store written without the option opens with its records

## 2. Policy and release notes

- [x] 2.1 The Privacy Policy says the library is in encrypted fields, end to end with Advanced Data Protection, and what Apple sees; `WebsiteTests` checks it
- [x] 2.2 `docs/release/app-privacy.md` says the same
- [x] 2.3 The device checklist's production schema step checks that every `CD_` field and the Play on fields show as encrypted, and starts with the development reset

## 3. Owner, by hand

- [ ] 3.1 In CloudKit Console, confirm the Production schema of `iCloud.se.codecrave.antenna` has no `CD_` record types, then reset the Development environment
- [ ] 3.2 Install a build with this change on two devices and check a source, a favorite and progress reach the second one

## 4. Verify

- [x] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.2 `/opsx:verify` passes
