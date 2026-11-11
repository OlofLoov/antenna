# Tasks

## 1. Profiles in the core package

- [x] 1.1 Add `Profile` and `ProfileList` to AntennaCore: order, duplicates by id (earliest wins), the name rule, the eight-profile cap, adding the second profile with Main, deleting all but the last, the current profile and whether the picker shows, and verify with core tests citing `profiles/who-s-watching-at-launch`, `profiles/adding-a-profile`, `profiles/editing-and-deleting-a-profile` and `profiles/profiles-sync-between-devices`

## 2. Records and the current profile

- [x] 2.1 Add `ProfileRecord` and `FavoriteRecord.profileID` with an additive migration, and a `ProfileStore` that maps records to `ProfileList`, writes adds, edits and deletes (with the profile's favorites), and keeps `profiles.current` in `UserDefaults`, and verify with integration tests on an in-memory store citing `profiles/adding-a-profile`, `profiles/editing-and-deleting-a-profile` and `favorites/favorites-belong-to-a-profile`
- [x] 2.2 Provide the current profile through an `@Entry` value, filter the catalogue's favorites and the Favorites tab by it, and write favorites with it, and verify with tests citing `favorites/favorites-belong-to-a-profile` and `profiles/what-each-profile-keeps`
- [x] 2.3 Key `shell.lastChannel` and `player.languages` per profile (`.<profile id>` for all but Main) and remove a deleted profile's keys at launch, and verify with tests citing `tvos-shell/back-to-the-last-channel-on-launch` and `profiles/what-each-profile-keeps`

## 3. Who's watching

- [x] 3.1 Add the picker on Apple TV (`TV-Profiles`) before the shell starts, with focus on the last profile used here and Menu doing nothing, and verify with a UI test citing `profiles/who-s-watching-at-launch`
- [x] 3.2 Add the picker on iPhone, iPad and Mac (`iPhone-Profiles`) before the tabs, and verify with a UI test citing `profiles/who-s-watching-at-launch`
- [x] 3.3 Show nothing about profiles with one profile, and verify with UI tests on both platforms citing `profiles/who-s-watching-at-launch`

## 4. Managing and switching

- [x] 4.1 Add Manage profiles and the edit screen on Apple TV (`TV-Profiles-Manage`, `TV-Profiles-Edit`) and the edit sheet on iPhone (`iPhone-Profiles-Edit`), with the delete confirmation and the eight-profile line, and verify with UI tests citing `profiles/adding-a-profile` and `profiles/editing-and-deleting-a-profile`
- [x] 4.2 Add the Profiles row in Settings on every device, and verify with a UI test citing `profiles/switching-profile` and `profiles/adding-a-profile`
- [x] 4.3 Add the profile button to the Apple TV tab bar (`TV-Shell-Menu-Profile`) with two or more profiles, and switch: stop playback, set the current profile, rebuild the catalogue and start Live on the new profile, and verify with UI tests citing `tvos-shell/the-tabs-in-order` and `profiles/switching-profile`
- [x] 4.4 Show the picker, or open on the only profile left, when the current profile is deleted on another device, and verify with an integration test citing `profiles/editing-and-deleting-a-profile`

## 5. Shared sources and sync

- [x] 5.1 Check that sources and logins are read without a profile filter anywhere, and verify with a test citing `profiles/sources-and-logins-are-shared`
- [x] 5.2 Resolve the two Main records two devices can make, and open as with one profile until profiles arrive, and verify with integration tests citing `profiles/profiles-sync-between-devices`
- [ ] 5.3 Check on two devices signed into one iCloud account that profiles and per-profile favorites sync, and record the result citing `profiles/profiles-sync-between-devices` and `favorites/favorites-sync-between-devices`
  - Open: needs two devices signed into one iCloud account, and the simulators do not sync CloudKit.

## 6. Verify

- [x] 6.1 Each requirement has a test citing `profiles/<requirement-slug>`, and the modified `favorites` and `tvos-shell` requirements a test citing theirs
- [x] 6.2 `/opsx:verify` passes
  - Its one critical issue is task 5.3, open for hardware.
