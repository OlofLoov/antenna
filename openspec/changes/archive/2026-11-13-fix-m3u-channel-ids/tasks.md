# Tasks

## 1. Ids in AntennaCore

- [x] 1.1 Build M3U ids from the guide id, name and group with an ordinal for repeats, and verify core tests citing `m3u-playlists/stable-and-unique-ids` and `m3u-playlists/title-fallback`
- [x] 1.2 Report each channel's earlier id in the parse and for imported files from the stored text, and verify core tests citing `m3u-playlists/earlier-ids-map-to-the-new-ones`
- [x] 1.3 Update the core tests and fixtures that expected link-based ids, and verify Recents and the last channel keep an M3U channel with a core test citing `session-restore-and-recently-watched/links-with-passwords-are-never-stored`

## 2. Rewrite in the app

- [x] 2.1 Rewrite favorites and own-group members with earlier ids after each load, merging duplicates, and verify integration tests citing `favorites/favorites-saved-before-the-id-change-carry-over`
- [x] 2.2 Check that a new favorite of an M3U channel stores no link or login, and that the Apple TV keeps an M3U channel as its last channel, with integration tests citing `favorites/favorites-reference-stable-channel-ids` and `tvos-shell/back-to-the-last-channel-on-launch`
- [x] 2.3 Mark the notes in `add-group-management`, `add-guide-sources-and-channel-mapping`, `add-app-intents`, `add-timeshift-catch-up-and-start-over` and the archived session-restore design as no longer blocked
- [x] 2.4 Run the favorites, Live, Recents and Groups UI test classes on local simulators (iPhone: LiveUITests, RecentsUITests, GroupsUITests, RestoreUITests; iPad: LiveRegularUITests; Apple TV: the Recents, Groups and channel overlay tests in ShellUITests)
- [x] 2.5 Check on two devices that a rewritten favorite syncs once. The device check is in `docs/release/device-checklist.md`.

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
