## 1. Saved channel in AntennaCore

- [ ] 1.1 Add `SavedLink` and `SavedChannel` with `Login`, the refusal rules and `sameStream`
- [ ] 1.2 Test the round trips, refusals, changed password, missing login, same stream, and the pinning test that no login is in the encoded bytes

## 2. Store and launch tune in the apps

- [ ] 2.1 Add `LaunchChannelStore` in the caches folder and `LaunchLogins` per source kind; give `RecentsStore` a `launch` store and clear it on source deletion, channel rename and profile prune
- [ ] 2.2 Write the saved channel from `SessionTracker.remember`, add `adopt`, and compare channels by source and id after a load
- [ ] 2.3 Tune the saved channel early and reconcile with the fresh list in `LiveModel`
- [ ] 2.4 Tune the saved channel early and reconcile with the fresh list in `ShellModel`
- [ ] 2.5 Wire `launchLogins` in the app's and the UI tests' dependencies
- [ ] 2.6 Unit tests in `LiveRestoreTests` and `ShellModelTests`
- [ ] 2.7 UI tests in `RestoreUITests` and `RecentsTVUITests` that relaunch into a source that never finishes

## 3. Verify

- [ ] 3.1 Each added or changed requirement has a test citing `session-restore-and-recently-watched/<slug>` or `tvos-shell/<slug>`
- [ ] 3.2 `/opsx:verify` passes
