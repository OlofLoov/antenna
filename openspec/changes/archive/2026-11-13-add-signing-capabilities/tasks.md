# Tasks

## 1. Entitlements and build settings

- [x] 1.1 Add iCloud (CloudKit, `iCloud.se.codecrave.antenna`), `aps-environment`, the shared `keychain-access-groups` entry and `applinks:antenna.code-crave.se` to `Config/Antenna.entitlements`; iCloud, push and the Keychain group to `Config/AntennaTV.entitlements`, keeping its app group; name both in `CODE_SIGN_ENTITLEMENTS` in `project.yml`; verify with `xcodegen generate` and `plutil -lint`.
- [x] 1.2 Add `Config/AntennaMac.entitlements` with the macOS push key, iCloud, the Keychain group, the associated domain and App Sandbox (`network.client`, `files.user-selected.read-only`), selected by `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`; verify `-showBuildSettings` for the macOS destination names it.
- [x] 1.3 Add `remote-notification` to `UIBackgroundModes` on iOS and tvOS, and the Info.plist keys `AntennaCloudKitContainer` and `AntennaKeychainGroup`, set in `Config/Shared.xcconfig` only when code signing is allowed; verify the built Info.plist of an unsigned build has both empty.
- [x] 1.4 Add `ANTENNA_PAID_TEAM` and the `Config/*Personal.entitlements` files a personal team can sign; verify a signed device build of each app with `ANTENNA_PAID_TEAM=NO`.

## 2. Keychain group and migration

- [x] 2.1 Route `CredentialStore` through `KeychainItems`, write to the shared group, fall back to the default group on a missing entitlement, move an old copy on read and delete every copy; verify `CredentialStoreTests` pass.

## 3. Without iCloud

- [x] 3.1 Add `CloudSync.container`, and use it for SwiftData's CloudKit database, `CloudKitLoginDrops`, `CloudKitIdentity` and `LoginDropSweep`; verify `CloudSyncTests` pass and the unsigned simulator build launches.

## 4. Docs

- [x] 4.1 Add the Developer portal, CloudKit Dashboard and Keychain move checks to `docs/release/device-checklist.md`; verify the file names each step and the change task.
- [x] 4.2 Check `docs/release/app-privacy.md` and `docs/architecture/` against the change; verify nothing there names a capability that changed.

## 5. Verify

- [x] 5.1 Build Antenna for iOS Simulator and macOS, and AntennaTV for tvOS Simulator, with `CODE_SIGNING_ALLOWED=NO`; run `CredentialStoreTests`, `CloudSyncTests`, `SourceManagementTests` and the Settings and Onboarding UI test classes on a simulator.
- [x] 5.2 Build AntennaTV and Antenna for devices with `-allowProvisioningUpdates` and record in design.md whether signing registered the capabilities; print the built apps' entitlements with `codesign -d --entitlements -`. The personal team cannot sign the full set; the portal steps and the schema deploy are in docs/release/device-checklist.md.
- [x] 5.3 Each requirement in the delta has a test citing `source-management/<requirement-slug>`, or a device-checklist item for the cross-device scenario (docs/release/device-checklist.md, add-signing-capabilities 5.2).
- [x] 5.4 `/opsx:verify` passes.

## Workflow follow-up

- Archive the change in the same PR.
