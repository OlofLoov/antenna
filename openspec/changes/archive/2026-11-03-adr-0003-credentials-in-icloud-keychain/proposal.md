# Proposal: store source credentials in the synchronizable Keychain (adr-0003)

## Why

Xtream and Stalker sources need a username and password. Putting them in
SwiftData would replicate secrets through CloudKit records we can query and
would make them visible in any debug dump of the store.

Accepted on 2026-11-03.

## What Changes

- `CredentialStore` writes `kSecClassGenericPassword` items with
  `kSecAttrSynchronizable = true` under the service
  `se.codecrave.antenna.sources`.
- `SourceRecord` stores only a `credentialKey`, never the secret.
- iCloud Keychain carries secrets between devices without the app ever
  seeing them in transit.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- Secrets never touch the data model or logs.
- Keychain sync is opaque. A source can arrive on a device before its
  credential does, and the UI must handle a missing credential gracefully.
- Follow-up: a spec for the "credential not yet synced" state.
