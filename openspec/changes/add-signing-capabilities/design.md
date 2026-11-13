# Design

## Context

See proposal.md for why. Today:

- `Config/Antenna.entitlements` is an empty dict. `Config/AntennaTV.entitlements` and `Config/AntennaTopShelf.entitlements` hold `group.se.codecrave.antenna`, which the Top Shelf extension reads its items from.
- The `Antenna` target builds iOS and macOS from one target and one entitlements file (`supportedDestinations: [iOS, macOS]`).
- SwiftData uses `ModelConfiguration(schema:, cloudKitDatabase: .automatic)`. `.automatic` picks the first `iCloud.` container in the entitlements, so it syncs nothing while there is none. `CloudKitLoginDrops` and `SetupPairingModel` name `iCloud.se.codecrave.antenna` directly.
- `CredentialStore` writes synchronizable generic passwords under service `se.codecrave.antenna.sources` with no `kSecAttrAccessGroup`. With no `keychain-access-groups` entitlement, an item lands in the app's application identifier group: `<team>.se.codecrave.antenna` on iPhone, iPad and Mac, `<team>.se.codecrave.antenna.tv` on Apple TV. An app can read only its own groups, so the TV cannot read a login the iPhone saved.
- The team id is `R767H5DB8H`, set in the git-ignored `Config/Local.xcconfig`. CI builds with `CODE_SIGNING_ALLOWED=NO`, which embeds no entitlements.

## Goals / Non-Goals

**Goals:**
- Each signed app has the capabilities the synced specs assume: CloudKit, CloudKit pushes, a Keychain group both apps share, and the setup link's associated domain.
- Logins already on the owner's iPhone reach the Apple TV without retyping.
- CI and simulator tests keep working unsigned.

**Non-Goals:**
- No CloudKit schema change. The SwiftData models are unchanged.
- No new UI. A login that fails to move behaves as before.

## Decisions

### Entitlements per target

| Key | Antenna (iOS) | Antenna (macOS) | AntennaTV | AntennaTopShelf |
|---|---|---|---|---|
| `com.apple.developer.icloud-container-identifiers` `[iCloud.se.codecrave.antenna]` | yes | yes | yes | no |
| `com.apple.developer.icloud-services` `[CloudKit]` | yes | yes | yes | no |
| `aps-environment` `development` | yes | | yes | no |
| `com.apple.developer.aps-environment` `development` | | yes | | no |
| `keychain-access-groups` `[$(AppIdentifierPrefix)se.codecrave.antenna.shared]` | yes | yes | yes | no |
| `com.apple.developer.associated-domains` `[applinks:antenna.code-crave.se]` | yes | yes | no | no |
| `com.apple.security.application-groups` `[group.se.codecrave.antenna]` | no | no | yes (kept) | yes (kept) |
| `com.apple.security.app-sandbox`, `network.client`, `files.user-selected.read-only` | | yes | | |

`aps-environment` stays `development` in the files. Xcode rewrites it to `production` when it exports an App Store build from a distribution profile.

The Top Shelf extension gets no iCloud or Keychain group. It reads the items the TV app writes to the app group and never a login or a CloudKit record.

### One target, two entitlements files

The iOS and macOS builds need different push keys, and only macOS takes App Sandbox. Options:

1. One file with both push keys and the sandbox keys. iOS signing rejects `com.apple.developer.aps-environment` and the sandbox keys in an iOS profile check, so the iOS build fails to sign.
2. Build settings `ENABLE_APP_SANDBOX`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS` and `ENABLE_USER_SELECTED_FILES` for the sandbox, with one file for the rest. Push still differs by platform, so a second file is needed anyway, and the sandbox would be split across two places.
3. A second file, `Config/AntennaMac.entitlements`, selected with `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` in `project.yml`. **Chosen.** Each platform's file lists everything it gets.

The files are written by hand and `project.yml` names them in `CODE_SIGN_ENTITLEMENTS`, because the file name depends on the team kind (next section) and xcodegen's `entitlements.path` takes no build setting.

### A personal team cannot sign these capabilities

The first signed build showed that team `R767H5DB8H` is a personal (free) team. Xcode refuses: "Personal development teams ... do not support the iCloud, Associated Domains, and Push Notifications capabilities." With those keys in the only entitlements file, the owner could not install any build on his iPhone or Apple TV until he joins the paid Apple Developer Program. Options:

1. Keep one set of files. Correct for release, but every device build fails today.
2. Leave the capabilities out until the paid team exists. Device builds work, but the change does not fix sync and has to be redone.
3. A setting, `ANTENNA_PAID_TEAM`, `YES` by default in `Config/Shared.xcconfig` and set to `NO` in the git-ignored `Config/Local.xcconfig` for a personal team. `NO` picks `Config/*Personal.entitlements`, which keep only what a personal team can sign, and leaves `AntennaCloudKitContainer` empty so the app never touches CloudKit. **Chosen.** Release and CI use the full files by default, and a personal-team device build still runs, local-only.

The personal files hold the shared Keychain group on iOS and tvOS (a personal team can sign it, and it lets the two apps share logins), the TV's app group, and on the Mac the sandbox keys only: a Mac `keychain-access-groups` entry needs a provisioning profile with a registered Mac, which this team has none of.

### Shared Keychain group

Options for letting the Apple TV read the iPhone's logins:

1. Store logins in the app group `group.se.codecrave.antenna`, which iOS and tvOS also accept as a Keychain access group. Today only the TV app and the Top Shelf extension have it, and logins there would be readable by the extension, which needs none.
2. A `keychain-access-groups` entry both apps list, `$(AppIdentifierPrefix)se.codecrave.antenna.shared`, and every write names it. **Chosen.** It is the documented way for two apps from one team to share Keychain items, and the extension stays out.
3. Keep the default groups and send logins only through the HPKE login drop. That covers only a login sent from the iPhone on purpose, and not a source added on the Mac.

The app finds the group's full name from an Info.plist key, `AntennaKeychainGroup`, set to `$(AppIdentifierPrefix)se.codecrave.antenna.shared` in both apps. The entitlement and the key come from the same build setting, so they cannot drift apart.

### Moving logins saved before this change

The owner has real logins on his iPhone in `<team>.se.codecrave.antenna`. Options:

1. A one-time migration at launch that walks every item under the service. It runs before anything needs a login, but it needs a "done" flag in `UserDefaults`, and a login that iCloud Keychain delivers after the flag is set (from a Mac still on the old build) would never move.
2. Move on read. `load(for:)` asks for the item in any group the app can read. If the copy is in the shared group, it is used and any other copy is deleted. If the only copy is elsewhere, it is written to the shared group, then the old copy is deleted, and the login is returned either way. **Chosen.** It needs no flag, it catches late arrivals, and it touches only logins the app uses.

`save` writes to the shared group and deletes copies in other groups. `delete` removes the item from every group by leaving the group out of the query, which `SecItemDelete` applies to all matches.

When the shared group cannot be written because the app lacks the entitlement (`errSecMissingEntitlement`, -34018), `save` writes to the app's default group as before. This keeps unsigned and simulator builds, and a device build whose profile has not picked up Keychain Sharing yet, saving logins. A move that fails leaves the old copy, and the next read tries again. No path logs a login, a key or a status that carries one; the store logs nothing.

`CredentialStore` reaches the Keychain through a small `KeychainItems` protocol with one production conformance, `SystemKeychain`. Tests use an in-memory Keychain that models access groups, a default group and groups the app is not entitled to. The existing `HeldCredentialStore` and `FailingCredentialStore` doubles stand in for the whole store elsewhere and stay as they are.

### Background modes

iOS gets `remote-notification` next to `audio`, so CloudKit's silent pushes wake the app and SwiftData imports changes in the background. tvOS gets the same; it delivers silent pushes to a running or suspended app. macOS ignores `UIBackgroundModes` and registers for pushes while running.

### Mac App Sandbox

The Mac build had no sandbox entitlement and no `ENABLE_APP_SANDBOX`. The Mac App Store requires the sandbox, so it is added with what the Mac app uses: outgoing connections to playlists, panels, guides and streams (`network.client`), and reading a playlist file the user picks in the import panel (`files.user-selected.read-only`). It accepts no incoming connections and writes no user file, so neither of those is added. Local network sources use the same outgoing permission.

### Running without CloudKit

`CKContainer(identifier:)` in a process without the iCloud entitlement raises an exception the app cannot catch, and SwiftData's `.automatic` logs a fault for every store it opens without one. Unsigned CI builds, a simulator build and a build signed before the portal has the capability all run without it. Options for knowing whether the process has CloudKit:

1. `SecTaskCopyValueForEntitlement` on the running process. It is public only in the macOS SDK; `SecTask.h` is missing from the iOS and tvOS SDKs.
2. Parse the code signature of the app's own executable. Works everywhere but reads an undocumented blob layout.
3. `FileManager.default.ubiquityIdentityToken`. It says whether the user has iCloud Drive, not whether the process has the entitlement, so a build without the entitlement on a signed-in device still crashes.
4. A build setting. **Chosen**, with option 1 added on the Mac. `Config/Shared.xcconfig` sets `ANTENNA_CLOUDKIT_CONTAINER` to the container only when `CODE_SIGNING_ALLOWED` is `YES`, which is when Xcode embeds the entitlements, and the Info.plist key `AntennaCloudKitContainer` carries it. A signed build always carries the entitlements file's keys, because signing fails when the profile lacks one.

`CloudSync.container` is that value, or nil. SwiftData opens `.private(container)` or `.none`. `CloudKitLoginDrops` throws `notSignedIn` before it creates a container, and `CloudKitIdentity` reports not signed in, so the QR card, the send screen and the TV's receive screen show their existing signed-out states ("No iCloud, no QR code" in `iphone-as-setup-device`). `LoginDropSweep` does not run. A device signed out of iCloud with a signed build keeps the container: CloudKit reports `noAccount`, SwiftData keeps the local store, and the same signed-out states show.

The Keychain group follows the same pattern with `ANTENNA_KEYCHAIN_GROUP` and `AntennaKeychainGroup`, so an unsigned build writes to its default group as before.

### Signing and the portal

Xcode's automatic signing with `-allowProvisioningUpdates` can enable capabilities on an app id and create an iCloud container when the Xcode account belongs to a paid team with the Admin or Account Holder role. The owner's steps are in `docs/release/device-checklist.md`.

## Risks / Trade-offs

- [The Mac sandbox moves the Mac app's local SwiftData store into its container] → The Mac app has not shipped. A development Mac starts empty and syncs back from iCloud.
- [A device build signed before the profile has Keychain Sharing writes to the default group] → `save` falls back, and the first read on a correct build moves the item.
- [A login deleted on one device while another still has an old copy in its own default group] → The other device's old copy is invisible to the first device and stays until that device deletes the source or reads it. Same as before this change.
- [CloudKit in the simulator] → SwiftData logs an account error and keeps the local store; UI tests use in-memory stores and never reach CloudKit.
- [A paid-team release built with `ANTENNA_PAID_TEAM = NO` left in `Local.xcconfig` ships without sync] → The device checklist's portal item says to remove the line, and `codesign -d --entitlements -` on the archive shows the iCloud keys.

## Migration Plan

Ship in one build. The first read of each login on each device moves it. Rolling back to the earlier build reads only the default group, so a login moved to the shared group would look absent there; the source shows as waiting for its login. Nothing has shipped to the App Store, so only the owner's devices are affected.

## Implementation decisions

- Signed builds on 2026-11-13 with team `R767H5DB8H`, `xcodebuild build -allowProvisioningUpdates`: the full files fail for AntennaTV and Antenna (iOS) with the personal-team error above, so automatic signing registered nothing. With `ANTENNA_PAID_TEAM=NO` the tvOS, iOS and macOS device builds succeed. `codesign -d --entitlements -` shows `keychain-access-groups` `R767H5DB8H.se.codecrave.antenna.shared` on the TV and iPhone apps, the app group on the TV app and the Top Shelf extension, the sandbox keys on the Mac app, and an empty `AntennaCloudKitContainer` in each Info.plist.
- `$(AppIdentifierPrefix)` resolves in Info.plist: a signed simulator build carries `AntennaKeychainGroup` `R767H5DB8H.se.codecrave.antenna.shared` and the container. An unsigned build (`CODE_SIGNING_ALLOWED=NO`) carries both empty, so CI writes logins to the default group as before and never creates a CloudKit container.
- The design audit saw the Apple TV app stop in an unsigned simulator when a source's details opened in Settings: the details' QR card asked `CKContainer.accountStatus()` with no iCloud entitlement. `CloudKitIdentity` now answers not signed in without creating a container, and `SourceSignInTVUITests.testSourceDetailsOpenWithoutICloud` opens those details in an unsigned build with the real iCloud check and expects the login fields, no QR card and the app still running.
- Simulator runs on 2026-11-13: `CredentialStoreTests`, `CloudSyncTests` and `SourceManagementTests` on iPhone 17 Pro (signed for the simulator); `OnboardingUITests`, `SettingsUITests` and `SetupUITests` on iPhone 17 Pro; `OnboardingTVUITests`, `SetupTVUITests` and `SourceSignInTVUITests` on Apple TV 4K (3rd generation) with `CODE_SIGNING_ALLOWED=NO`. All passed.
