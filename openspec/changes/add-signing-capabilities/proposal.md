# Proposal

## Why

> As a household setter-upper, I want the sources and logins I added on my iPhone to show up on the Apple TV, so I never type a password with the remote.

On a real Apple TV the app logs "In order to use CloudKit, your process must have a com.apple.developer.icloud-services entitlement", and nothing syncs. No target asks for iCloud, push, keychain sharing or associated domains: `Config/Antenna.entitlements` is empty and the Apple TV's file holds only the app group. The capabilities waited for a team id (`add-iphone-as-setup-device`, design.md); the team id now exists.

The Keychain has a second gap. The iPhone and Mac app (`se.codecrave.antenna`) and the Apple TV app (`se.codecrave.antenna.tv`) have different bundle ids, so each saves logins in its own default access group. iCloud Keychain carries an item to the TV, but the TV app cannot read an item in the iPhone app's group. Logins the owner already saved on his iPhone sit in that group.

After this change a signed build of each app syncs sources, favorites, settings and progress through CloudKit, gets CloudKit change pushes, opens setup links, and reads logins saved by the other app, including the ones saved before the change.

## What Changes

- iCloud with CloudKit and the container `iCloud.se.codecrave.antenna` on the iPhone, iPad and Mac app and on the Apple TV app.
- Push notifications for CloudKit changes, with the remote-notification background mode on iOS and tvOS.
- A shared Keychain access group, `<team id>.se.codecrave.antenna.shared`, on both apps. Logins are written there.
- A login found in another group on read is copied to the shared group and the old copy deleted.
- The associated domain `applinks:antenna.code-crave.se` on the iPhone, iPad and Mac app.
- App Sandbox on the Mac build, with outgoing network connections and read access to files the user picks, in a Mac-only entitlements file.
- A setting, `ANTENNA_PAID_TEAM = NO` in `Config/Local.xcconfig`, that signs with a free personal team: no iCloud, push or associated domains, and the app runs without sync. The team in use today is a personal team.
- The app keeps working, local only, in any build that cannot reach CloudKit, and treats sending a login to an Apple TV as not signed in there.
- Release docs: the CloudKit schema deploy and the portal steps.

Out of scope:
- Universal links on Apple TV. tvOS does not open web links in apps.
- A Keychain group for the Top Shelf extension. It reads no login.
- App groups on the iPhone app. Nothing there shares files with an extension.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `source-management`: logins are kept where both apps can read them, logins saved by an earlier version move there, and sources stay on the device without iCloud.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS. `project.yml`, `Config/*.entitlements`, `Config/Shared.xcconfig`, `Apps/Shared/Persistence/CredentialStore.swift`, the CloudKit call sites, tests, `docs/release/`, CLAUDE.md.
- Depends on: `source-management`, `watch-progress-sync`, `favorites`, `sources-and-settings`, `apple-tv-login-from-iphone` and `iphone-as-setup-device`, which assume these capabilities exist on a signed build.
- Blocked on: the paid Apple Developer Program. Team `R767H5DB8H` is a personal team, and Xcode refuses iCloud, Push Notifications and Associated Domains for it. After joining, the owner creates the iCloud container and enables the capabilities on the app ids, or lets Xcode's automatic signing do it.
- CI builds unsigned (`CODE_SIGNING_ALLOWED=NO`), so the entitlements change nothing there.
- Data: Mac App Sandbox moves the Mac app's local store into its container. The Mac app has not shipped; a development Mac starts empty and syncs back from iCloud.
