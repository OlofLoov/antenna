## Context

No board. The check looks at the boarded Sources and Settings list from `add-sources-and-settings`; this change adds no screen and follows no further design-system requirement.

The first version of this change targeted screens that no longer exist: `AddSourceView`, `ChannelsView`, the pushed `PlayerView` and a Settings list whose rows showed each source's URL. Onboarding's form, the Sources and Settings list and Live replaced them. The rewrite keeps only what those changes cannot test.

## Goals / Non-Goals

**Goals:**
- Check once, on real devices, that a source saved on one device reaches another and loads there.

**Non-Goals:**
- New tests for behavior other changes already test (tasks.md group 1).
- A delete across devices, which `add-sources-and-settings` task 4.1 covers.

## Decisions

- The Settings list requirement is dropped. It wanted each row to show the source's URL, which contradicts `add-sources-and-settings`: its rows show name, type and one status line, no source link or host appears in a row, and `SettingsUITests.testEachSourceShowsItsStatusAndNoLink` checks that. The options were keeping the URL, rewriting the requirement without it, or dropping it. `sources-and-settings/see-how-each-source-is-doing` already says the rewritten version, so it is dropped, and the sync requirement says rows show no link.
- The other first-version requirements (the add sheet, the empty channel list, the pushed player) are dropped for the same reason: each is now a requirement of another change, with tests citing it.
- Sync stays a manual two-device check. CloudKit does not sync on a simulator, and CI has no iCloud account. `SourceRefresherTests.syncChanges` covers this device's side by feeding the store change a sync makes, and cites this requirement as well as its own.
- To run the check, add an M3U source and an Xtream source on device A. On device B, open Sources and Settings and wait for both rows. Confirm the order, names, types and status lines, that no row shows a link, that the M3U source loads, and that the Xtream source loads or says it is waiting for its login and then loads once iCloud Keychain delivers it.

## Risks / Trade-offs

- Equal sort orders, from two devices adding at once, list in an undefined order (`source-management/m3u-source-is-saved`).
- [The check needs a person with two devices] → the check is on `docs/release/device-checklist.md`, and the change is archived before it runs. A failure there opens a fix change.
