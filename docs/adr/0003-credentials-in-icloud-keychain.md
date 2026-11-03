# 0003. Store source credentials in the synchronizable Keychain

- Status: Accepted
- Date: 2026-11-03

## Context

Xtream and Stalker sources need a username and password. Putting them in
SwiftData would replicate secrets through CloudKit records we can query and
would make them visible in any debug dump of the store.

## Decision

`CredentialStore` writes `kSecClassGenericPassword` items with
`kSecAttrSynchronizable = true` under service `se.codecrave.antenna.sources`.
`SourceRecord` stores only a `credentialKey`. iCloud Keychain carries secrets
between devices without the app ever seeing them in transit.

## Options considered

1. **Credentials in SwiftData.** Secrets in a queryable store and in CloudKit records.
2. **Embed credentials in the playlist URL.** Many sources do this already, but
   it leaks into logs and the URL field.

## Consequences

- Good: Secrets never touch our data model or logs.
- Bad: Keychain sync is opaque. A source can arrive on a device before its
  credential does. The UI must handle a missing credential gracefully.
- Follow-ups: Spec for the "credential not yet synced" state.
