# Proposal

## Why

> As the owner testing on my iPhone and Apple TV, I want to see why a playlist added on one device never reaches the other, and why Play on never lists the TV.

Both devices run Debug builds from Xcode on the paid team, with the iCloud entitlement and the development CloudKit environment. Nothing syncs, and nothing says why. Every Play on store call drops its error with `try?`, and Core Data's CloudKit lines do not reach `xcrun devicectl device process launch --console`. Only the app's own `Logger` lines do.

With a later build, sources sync from the phone to the TV, but Play on still lists no TV. Play on and the login-drop sweep start only when `FileManager.default.ubiquityIdentityToken` is set. That value belongs to iCloud Drive, not CloudKit: it is nil with iCloud Drive off, and tvOS has no iCloud Drive, so the TV never writes its device record and never listens. SwiftData sync does not ask for it, which matches what the owner sees.

There is also a gap in Play on. The phone reads the account's device list when the scene becomes active. A TV that opens Antuna for the first time after that stays unlisted until the phone goes to the background and back.

## What Changes

- Debug builds on iPhone, iPad, Mac and Apple TV record the last setup, import and export event of SwiftData's CloudKit mirroring, with start and end time, success and the error's domain, code and description. They also record the iCloud account state for the container, whether the device has an iCloud identity, the container this build uses, and whether Play on runs.
- Debug builds log each event in the `sync` category, and each Play on store failure and the device count of each read in the `playOn` category. The lines hold no stream link, login, source name, title or device name.
- Debug builds show a Sync status section in Settings with those values and the Play on device records (name, kind, last seen), and a Read devices again button.
- Every build: Play on and the login-drop sweep start when the build has a CloudKit container and CloudKit reports the iCloud account as available, asked once and again on each account change. The iCloud Drive identity no longer decides it.
- Every build: while the scene is active and no TV is listed, the phone, iPad or Mac reads the device list again every 30 seconds, and once more when a title page or programme details opens, at most every 10 seconds.

Out of scope: the welcome screen's and Settings' iCloud note, which still reads the iCloud Drive identity to decide what to say; nothing waits on it. Release builds log nothing new and show no new section.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `play-on-apple-tv`: "Apple TVs on the same iCloud account" gains the scenario for a TV that opens Antuna while the phone is open; "Waits in iCloud when the TV is not reachable" gains the scenario for iCloud Drive turned off.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Code: a new `CloudAccount` that `PlayOnSetup` and `LoginDropSweep` wait on, `PlayDestination` (the reread), `PlayOnReceiver` and the Play on stores (logging), a Debug-only `SyncStatus` and `SyncStatusSection`.
- Stays out of the SwiftData models, which `encrypt-synced-library` is changing.
- Depends on nothing else.
