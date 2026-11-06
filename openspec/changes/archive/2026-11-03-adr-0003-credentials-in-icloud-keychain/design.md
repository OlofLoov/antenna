# Design: credentials in the synchronizable Keychain

## Context

Sources sync through SwiftData over private CloudKit (decision adr-0002,
SwiftData with private CloudKit for sync). Xtream and Stalker sources also
need a username and password. In SwiftData those would replicate through
CloudKit records we can query and show up in any debug dump of the store.

## Goals / Non-Goals

**Goals:**

- Credentials reach the user's other devices without passing through the
  synced data model.
- Secrets never appear in the store, in CloudKit records or in logs.

**Non-Goals:**

- Controlling when a credential arrives on a device. Keychain sync decides
  that.

## Decisions

**Keychain items, keyed from the record.** `CredentialStore` writes
`kSecClassGenericPassword` items with `kSecAttrSynchronizable = true` under
service `se.codecrave.antenna.sources`. `SourceRecord` keeps only a
`credentialKey` that points at the item. iCloud Keychain moves the secret
between devices and the app never sees it in transit.

Options considered:

1. Credentials in SwiftData. Rejected because it puts secrets in a queryable
   store and in CloudKit records.
2. Credentials embedded in the playlist URL. Many sources already do this,
   but it leaks into logs and the URL field.

## Risks / Trade-offs

- Keychain sync is opaque. A source can arrive before its credential, so the
  UI must handle a missing credential gracefully.
- Follow-up: a spec for the "credential not yet synced" state.
