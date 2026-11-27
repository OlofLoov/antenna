# Design

The Sync status section is a Debug-only tool for the owner and has no board. It uses the platform's form rows (design-system/forms-use-the-platform-form-style) with plain, untranslated strings, as the Debug section above it does. No other screen changes.

## Decision 1: where the sync events come from

Options:

1. **`NSPersistentCloudKitContainer.eventChangedNotification`**, observed with a nil object since SwiftData owns the container. It carries each setup, import and export with its dates, success and error. Chosen.
2. **`-com.apple.CoreData.CloudKitDebug 1` as a launch argument.** Its lines go to the unified log under Apple's subsystem, which `devicectl --console` does not show, and it says nothing in the app.
3. **Asking CloudKit directly** for the SwiftData zone's changes. It would duplicate the mirroring's work and could not see the mirroring's own errors.

`SyncStatus.shared` starts observing in `AntennaApp.init`, before the model container exists, so the setup event is not missed. A CloudKit partial failure is shown as its first inner error; another domain with an underlying error shows the underlying one.

## Decision 2: logging

`Logger(subsystem: Bundle.main.bundleIdentifier, category:)`, with `sync` for events and the account, `playOn` for the stores. Values are `privacy: .public` so a device without a debugger shows them. Each line holds a step name, a CloudKit error domain, code and description, a count or a kind. `PlayOnStoreError.map` logs the CloudKit error it maps, since every Play on store passes its errors through it. `PlayOnLog` compiles to nothing in Release.

## Decision 3: reading the device list again

Options:

1. **A CloudKit subscription on the `PlayDevices` zone**, pushed to the phone when a TV writes its record. Needs the push entitlement working, which is part of what the owner cannot verify yet.
2. **Polling every 30 seconds while the scene is active and no TV is listed.** Chosen. It stops when a TV shows up or the scene leaves the foreground, so a household with a TV reads no more than before.
3. **Polling at all times.** Costs a CloudKit read every 30 seconds for every user, with a TV or without.

`PlayDestination.Dependencies.rereadWait` is the wait, `Task.sleep` for `PlayDestination.rereadInterval` in the app and a ticker in tests. `lookForTVs()` runs from the title page and both programme details views and reads at most once every 10 seconds, only while no TV is listed.

## Decision 4: what decides that Play on can run

Play on and the login-drop sweep used to start when `CloudSync.container` was set and `FileManager.default.ubiquityIdentityToken` was not nil. That token is iCloud Drive's: nil with iCloud Drive off on an iPhone, and nil on Apple TV. The TV never wrote its device record, so no phone listed it.

Options:

1. **`CKContainer(identifier:).accountStatus() == .available`**, asked when the container is set, once per launch and again on `.CKAccountChanged`. Chosen. It is what CloudKit itself checks.
2. **Keep the token on iPhone and drop it on tvOS.** Still wrong for an iPhone with iCloud Drive off.
3. **Start whenever the container is set** and let CloudKit calls fail. Every launch without an account would log failures and write nothing useful.

`CloudAccount.shared` holds the answer. `CloudAccount.available(container:status:)` is the rule, and tests pass the status in through `CloudAccount(container:check:)`. `PlayOnSetup.enabled(_:)` and `LoginDropSweep.enabled(_:)` are async and wait for the first answer. `PlayOnRuntime` builds its parts once the answer is yes, also when the account becomes available after launch. The Debug section shows both values so they can be compared on a device.
