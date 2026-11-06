# Proposal

## Why

> As a user of a less common service (a Stalker portal, Jellyfin, Channels DVR) or of a playlist file on disk, I want to use it like any other source.

> As a household setter-upper, I want sources I add on one device to appear on my other devices, so I never type a URL or password twice.

> As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text.

Some providers hand out a playlist file rather than a link, and some users build their own `.m3u` from several providers and have nowhere to host it. Today the only way in is a link, so these users cannot add their channels at all. A file picked on iPhone also has to reach the Apple TV, where the file does not exist, so the contents have to travel with the source rather than a path to it.

Not reviewed yet.

## What Changes

- A new kind of source, an imported playlist file, whose contents are copied into Antenna once.
- Ways in on iPhone, iPad and Mac: an "Import a file" button in Sources and Settings and on onboarding's playlist form, sharing a file to Antenna from Files, Mail or Finder's Open With, and dragging a file onto the window on iPad and Mac.
- One import sheet for every way in: the file's name and size, a summary of what it holds, a name, a guide link, and Import.
- Clear messages for files that cannot be imported: too large, not a channel list, a list of links, a single stream, or unreadable.
- Re-importing a file onto the same source so favorites keep working, and spotting a file name imported before.
- A file source changes only when re-imported. It has no Refresh, and Refresh all skips it.
- The contents sync to every device, Apple TV included, with a waiting state until they arrive.
- Every login found inside the file's stream links moves to the Keychain, so the synced copy holds the links without logins.
- Deleting a file source removes its contents and login with it.

Out of scope:
- Importing on Apple TV, and signing in to a file source's logins on Apple TV.
- Watching the original file for changes or keeping a link or path to it.
- Importing a guide file (XMLTV).
- `.pls`, `.xspf`, `.json` or Kodi playlists, and compressed playlists.
- Exporting a source as a file, or merging two files into one source.
- The Sources and Settings screen itself.
- VLC and Kodi player options inside the playlist.

## Capabilities

### New Capabilities
- `local-m3u-file-import`: importing a playlist file on iPhone, iPad and Mac as a source whose contents sync to every device.

### Modified Capabilities
- `guide-data`: a file source's guide links come from the file's header.
- `tvos-shell`: a file source whose contents have not arrived shows as waiting for iCloud.

## Impact

- Platforms: iOS, iPadOS, macOS import. tvOS shows a synced file source but cannot import.
- Depends on: `m3u-playlists`, `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, and the changes `add-first-run-onboarding`, `add-live-tv-on-iphone-ipad-mac`, `add-sources-and-settings`.
- Needs from other changes: `add-first-run-onboarding` counts a file source as usable, names the file in its loading row and adds "Import a file instead". `add-sources-and-settings` adds the Import a file button and a file-source row with Re-import and no Refresh. `add-live-tv-on-iphone-ipad-mac` shows waiting for iCloud where it shows waiting for login.
- Blocked on: a new decision on storing imported playlist text in the synced store (where it lives, how big it may be, the schema change, and moving every login found in its links, in the query, Xtream path and `user:pass@host` forms, to the Keychain). The change stays unaccepted until that decision is accepted.
