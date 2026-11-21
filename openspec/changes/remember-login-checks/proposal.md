# Remember login checks

## Why

A movie and series watcher moving through a big library on Apple TV
expects focus to follow the remote without stalls. Every title page,
preview, Play press and Live source check asked the Keychain whether the
source had its login, on the main thread. Each ask is two or three
Keychain lookups through `securityd`, more for synchronizable items. After
this change the app asks the Keychain once per login while it stays in
front.

## What Changes

- Whether a source has its login is remembered after the first time it is
  found. A login that cannot be read, such as while the Keychain is
  locked, still counts as here and is remembered too.
- A missing login is not remembered, so one that arrives through iCloud
  Keychain is seen on the next check, as before.
- Saving or deleting a login on this device, and the app coming back to
  the front, forget what was remembered, so a login removed on another
  device counts as missing again.

Out of scope:
- The secret itself is still read when a load or Play needs it. Loads and
  info fetches already read it off the main thread. Play reads it once per
  press on the main thread to build the address.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `source-management`: adds "Login checks are remembered".

## Impact

- `LoginPresence` and `ForgetLoginsOnActivate` in `Apps/Shared/Persistence/`,
  `CredentialStore.hasLogin(for:accepts:)`, `SourceLoader.hasLogin`.
- No data model, sync or dependency change.
