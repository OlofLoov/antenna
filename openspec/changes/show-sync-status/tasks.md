# Tasks

## 1. Find late TVs

- [x] 1.1 `PlayDestination` reads the device list every 30 s while active with no TV, and stops in the background or once a TV is listed
- [x] 1.2 `lookForTVs()` from the title page and the programme details
- [x] 1.3 Tests with the in-memory stores

## 2. Sync status in Debug builds

- [x] 2.1 `SyncStatus` records the CloudKit events and the account, and logs them in `sync`
- [x] 2.2 `PlayOnLog` logs store failures and device counts in `playOn`, from the phone, the TV and `PlayOnStoreError.map`
- [x] 2.3 `SyncStatusSection` in Settings on every platform

## 3. Gate on the CloudKit account

- [x] 3.1 `CloudAccount` asks `accountStatus()` when the build has a container, again on `.CKAccountChanged`
- [x] 3.2 `PlayOnSetup`, `PlayOnRuntime` and `LoginDropSweep` wait on it instead of the iCloud Drive identity
- [x] 3.3 Tests for the rule with the status passed in

## 4. Verify

- [x] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 `/opsx:verify` passes
