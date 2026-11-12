# Tasks

## 1. Records and policy

- [ ] 1.1 Add the group, member and passcode records with additive migration, ignoring malformed records
- [x] 1.2 Add the group policy and locks-open flag to the catalogue with no-rules defaults, and verify with a core test citing `channel-catalogue/group-list-and-order`

## 2. Hide, order, rename

- [x] 2.1 Leave hidden groups out of lists and search unless enabled, without renumbering, and verify with a core test citing `group-management/hide-groups-you-never-watch`
- [x] 2.2 Apply the user's group order below Favorites and All channels, and verify with a core test citing `group-management/put-groups-in-your-order`
- [x] 2.3 Apply custom names across screens with the empty-name rules, and verify with an integration test citing `group-management/give-a-group-your-own-name`
- [ ] 2.4 List settings for groups that are gone with Remove, skipping unloaded playlists, and verify with a core test citing `group-management/settings-for-groups-that-are-gone`

## 3. Own groups

- [ ] 3.1 Create, rename, fill from any playlist, reorder and delete own groups, and verify with a core test citing `group-management/build-your-own-group-from-any-playlist`

## 4. Passcode and locks

- [x] 4.1 Hide locked channels, counts and numbers while locks are closed, and verify with a core test citing `group-management/locked-channels-stay-out-of-reach`
- [ ] 4.2 Set the first passcode and store only a salted verifier, and verify with an integration test citing `group-management/lock-a-group-with-a-passcode`
- [ ] 4.3 Show the prompt on locked groups and open the locks on the right passcode, and verify with a UI test citing `group-management/unlock-with-the-passcode`
- [ ] 4.4 Add the per-device lockout that survives relaunch, and verify with an integration test citing `group-management/guessing-the-passcode-is-slow`
- [ ] 4.5 Close locks on Lock now, relaunch and idle, and verify with an integration test citing `group-management/locks-close-again-on-their-own`
- [ ] 4.6 Add Forgot passcode with device authentication on iPhone, iPad and Mac, and verify with a UI test citing `group-management/reset-a-forgotten-passcode`
- [ ] 4.7 Pause and prompt when the playing channel becomes locked, with the current-group fallback, and verify with an integration test citing `group-management/a-channel-that-gets-locked-stops-playing`

## 5. Screens and sync

- [ ] 5.1 Build the Groups screen on every platform from the boards, reached from a Groups row in Sources and Settings, and check the 400-group first-frame budget
- [ ] 5.2 Check on two devices that hide, rename, lock and an own group sync while locks stay closed, citing `group-management/changes-follow-you-to-every-device`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `group-management/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
