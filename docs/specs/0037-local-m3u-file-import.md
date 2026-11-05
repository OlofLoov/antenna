# 0037. Local M3U file import on iPhone, iPad and Mac

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Blocked on: a new ADR on storing imported playlist text in the synced store: where it lives, how big it may be, the schema change, and moving every login found in its links (query, Xtream path and `user:pass@host` forms) to the Keychain. The spec stays Draft until that ADR is Accepted.
- Builds on specs: 0001, 0004, 0006, 0010, 0013, 0014, 0015, 0023
- Amends on acceptance: 0006 (Import a file instead; a file source counts as usable), 0023 (Import a file button; a file-source row with Re-import and no Refresh), 0014 (guide links from the file header), 0010 and 0015 (waiting for iCloud)
- Platforms: iOS, iPadOS, macOS (import); tvOS shows a synced file source but cannot import
- User stories: US-6, US-2, US-7

## Summary

For people whose provider sends a playlist file (an `.m3u` file: a text list of channel names and stream links) instead of a link, and for people who build their own and have nowhere to host it. Once this ships, they can bring the file into Antenna on iPhone, iPad or Mac by picking it, sharing it from another app, or dragging it onto the window, see what is in it before importing, and watch its channels like any other source. The file's contents sync through iCloud, so the channels also appear on Apple TV and other devices. On Apple TV, a file whose stream links needed a login shows as waiting for its login until Antenna offers a way to sign in there. It does not watch the original file for changes, import guide files or other playlist formats, or import on Apple TV itself.

## Design

Boards: `docs/design/boards/iPhone-Import.dc.html`, `iPhone-Import-TooLarge.dc.html`, `iPhone-Import-Malformed.dc.html` (iOS; iPadOS and macOS show the same sheet centred); `iPad-Import.dc.html`, `iPad-Import-TooLarge.dc.html`, `iPad-Import-Malformed.dc.html` (iPadOS, macOS, including the drop target); `iPhone-Onboard-3.dc.html` (the reading ring is reused from it).
Design rules that apply: DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15.
Not drawn: the link-list, single-stream and unreadable-file messages; the one-link offer to add it as a source; the reading state; the "imported before" row with Replace and Import as new; replace mode; the "Import a file instead" link on onboarding's playlist form; the file-source row in Sources and Settings on every platform, including Apple TV and its waiting-for-iCloud and waiting-for-login text.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Some providers hand out a playlist file rather than a link, and some users build their own `.m3u` from several providers and have nowhere to host it. Today the only way in is a link, so these users cannot add their channels at all. A file picked on iPhone also has to reach the Apple TV, where the file does not exist, so the contents have to travel with the source rather than a path to it.

## Scope

In:
- A new kind of source, an imported playlist file, whose contents are copied into Antenna once.
- Ways in on iPhone, iPad and Mac: an "Import a file" button in Sources and Settings (0023) and on onboarding's playlist form, sharing a file to Antenna from Files, Mail or Finder's Open With, and dragging a file onto the window on iPad and Mac.
- One import sheet for every way in: the file's name and size, a summary of what it holds, a name, a guide link, and Import.
- Clear messages for files that cannot be imported: too large, not a channel list, a list of links, a single stream, or unreadable.
- Re-importing a file onto the same source so favorites keep working, and spotting a file name imported before.
- A file source changes only when re-imported; it has no Refresh, and Refresh all skips it.
- Syncing the contents to every device, Apple TV included, with a waiting state until they arrive.
- Moving every login found inside the file's stream links to the Keychain, so the synced copy holds the links without logins.
- Deleting a file source together with its contents and login.

Out (explicitly):
- Importing on Apple TV, and signing in to a file source's logins on Apple TV (a follow-up of 0006's Apple TV Keychain ADR).
- Watching the original file for changes or keeping a link or path to it.
- Importing a guide file (XMLTV, the guide file format).
- `.pls`, `.xspf`, `.json` or Kodi playlists, and compressed playlists.
- Exporting a source as a file, or merging two files into one source.
- The Sources and Settings screen itself (0023).
- VLC and Kodi player options inside the playlist.

## User flow

iPhone:
1. In Settings, tap "Import a file…". The Files picker opens.
2. Pick a file. The import sheet shows its name and size, then "Reading <file>…" while it is checked.
3. The summary appears: how many channels and groups, whether a guide link was found, and how many entries were skipped. The name is filled in from the file name and the guide link from the file.
4. Tap Import. The sheet closes, the source appears in the list, and its channels show in Live within a few seconds.
5. Sharing an `.m3u` file to Antenna from Files or Mail opens the same sheet at step 2.

iPad and Mac: the same, with the sheet centred. On Mac the picker is the open panel and Finder's Open With lists Antenna. Dragging a file over the window shows where it will land; dropping it opens the sheet.

Re-import: the file source's details offer "Re-import…", which opens the sheet in replace mode.

Apple TV: nothing to do. The source and its channels arrive through iCloud; until they do, the source shows as waiting for iCloud.

Onboarding: the playlist form has "Import a file instead", and Import continues to onboarding's loading step.

## Acceptance criteria

Ids keep their numbers from the earlier draft, so some numbers are missing.

### AC-1 Bring a file in
Given Settings or onboarding on iPhone, iPad or Mac, or a playlist file in another app
When the user picks a file with "Import a file", or shares it to Antenna, or opens it with Antenna from Finder
Then the import sheet opens for that file.

### AC-3 Drop a file on the window
Given Settings, onboarding's welcome or the add-source sheet on iPad or Mac
When the user drags a playlist or text file over the window and drops it
Then a drop target appears during the drag and the import sheet opens for the first file dropped.

### AC-5 See what's in the file before importing
Given a playlist file with 412 channels in 18 groups, a guide link and 3 entries that are not links
When the import sheet has read it
Then it says "412 channels in 18 groups", that a guide link was found, and that 3 entries were skipped, with the name and guide link filled in.

### AC-6 Import and watch
Given the import sheet showing a file's summary
When the user taps Import
Then the source is saved with the file's contents, its channels appear in Live without a relaunch and match the summary's count, its guide downloads like any playlist's, and no network request is made for the playlist itself.

### AC-8 A file too large is refused before it is read
Given a file larger than 16 MB
When the user picks, shares or drops it
Then the sheet says how big the file is and that the limit is 16 MB, suggests splitting it or hosting it as a link, and nothing is saved.

### AC-9 A file that is not a channel list is explained
Given a file with no channel entries, a plain list of links, a single video stream, or one that cannot be read
When the sheet has checked it
Then the sheet says which of these it is and what to do instead, and Import stays disabled.

### AC-14 Re-import onto the same source
Given a file source with favorites
When the user re-imports a newer copy of the file
Then the source keeps its name and place in the list, its channels are replaced, and favorites of channels still in the file keep working.

### AC-17 Channels reach Apple TV
Given a file whose links carry no login, imported on iPhone
When an Apple TV signed into the same iCloud account is on
Then the source shows as waiting for iCloud until the contents arrive, then its channels appear and play there without a relaunch, without the Apple TV ever touching the file.

### AC-19 No import on Apple TV
Given the app on Apple TV
When the user moves through any screen
Then no import control appears, and the app is not offered as a handler for playlist files.

### AC-23 Import during onboarding
Given onboarding's playlist form
When the user chooses "Import a file instead" and imports a file
Then onboarding continues to its loading step with the playlist row naming the file.

### AC-24 Deleting removes everything
Given a file source
When the user deletes it
Then its contents, its guide and any login moved from its links are gone.

### AC-26 Logins in stream links stay private
Given a playlist whose stream links carry a username and password, in the query, in the path or before the host
When the user imports it
Then the logins are moved to the Keychain before anything syncs, channels still play, and no login reaches the synced store or a log; the synced copy holds the links without their logins.

## Edge cases

- A second file arriving while the import sheet is open is ignored.
- Dragging something that is not a file (an image, text, a web link) shows no target.
- A file holding exactly one link offers to add that link as a source.
- A file whose name was imported before asks whether to replace that source or import it as new.
- A file whose links carry a login, on Apple TV: the source shows as waiting for its login and its channels do not play there, until an Apple TV sign-in path exists (a follow-up of 0006's Apple TV Keychain ADR).
- A login from the links that has not reached another iPhone, iPad or Mac yet: the source there shows as waiting for its login.
- A provider changes the password: streams fail until the file is re-imported.
- Offline: import works fully offline; only the guide download waits for the network.
- A file named `.m3u` that holds a web page: content decides, so it is refused as not a channel list.
- A file whose text is in an old Windows encoding: names may show a replacement character.
- Not signed into iCloud: the source works on this device only, as the Settings footer says. iCloud storage full: it works on this device only and nothing says so.
- The paywall is up when a file is shared: the sheet waits until the app is unlocked.
- Two devices re-import the same source at once: one copy wins and the other is lost without notice.
- An older app version shows the file source in Settings with no channels and does not crash.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-3 | ui |
| AC-5 | core |
| AC-6 | integration |
| AC-8 | integration |
| AC-9 | core |
| AC-14 | integration |
| AC-17 | device |
| AC-19 | ui |
| AC-23 | ui |
| AC-24 | integration |
| AC-26 | core |

## Open questions

- Decided: the limit is 16 MB, about 50 000 entries. The owner can raise it to 32 MB if real files exceed it, or lower it on Apple TV if memory runs short.
- Should Replace be offered on matching contents rather than matching file name? Can be decided in the plan.
- Dropping several files imports the first. Should each get its own sheet? Can be decided in the plan.
- Decided: a single stream is refused, not offered as a one-channel source. The owner can reverse it.
- The reviewer suggested splitting this into four specs (core checks and login stripping, the sheet and ways in, sync and waiting, drag and drop). Kept as one, shipped as a stack of PRs in that order; the owner decides.

## Notes for the plan

- The previous revision of this spec (git history) holds the agreed texts for the summary rows and every error, and the order of the import checks.
- Storage (pending ADR): `SourceRecord` gains optional `playlistData` (external storage, synced as a CloudKit asset), `fileName` and `importedAt`; `kind` gains `m3uFile` with `url` nil. Lightweight migration; the CloudKit production schema needs the fields before release. The size limit is checked before reading when the size is known, during reading otherwise, and before decoding.
- Core: `PlaylistImport.inspect(_:)` decides, in order, too large, decode (drop a UTF-8 byte-order mark, replace invalid bytes, accept UTF-16 with a mark), single HLS stream, link list, then 0001's `M3UParser` plus a filter that skips entries without a scheme. The loader uses the same filter, so Live shows exactly what the summary counted. No second parser.
- Logins: the query form (`username=…&password=…`), the Xtream path form (`/live/<user>/<pass>/<id>.ts`) and `user:pass@host` are replaced by placeholders and stored as one synchronizable Keychain item per source (ADR-0003); the loader puts them back and never writes restored links to the store. Logs carry only the file name, byte count, outcome, number of moved logins and the source id.
- Other specs' edits, each its own PR: 0006 (a file source counts as usable; the loading row names the file; the "Import a file instead" link), 0023 (a record with no link is not skipped when it is a file source; delete calls the guide store's remove; the file source row shows "Imported <date> · <file>", has no Refresh, and offers Re-import), 0014 (guide links for a file source come from the file header), 0010 and 0015 (waiting for iCloud is a terminal state shown where waiting for login is).
- Document types: the Antenna target registers M3U and M3U8 as an alternate viewer, not plain text; the Apple TV target registers nothing. The Mac build is not sandboxed, so the open panel and drops need no entitlement.
- Shared files land in `Documents/Inbox` on iOS; delete that copy after reading, whether or not the user imports. Security-scoped access is released before the sheet shows.
- Reading and checking run off the main actor, can be cancelled, and stay within 0001's parse time. Store changes are batched with a reload delay of about one second.
- Re-import updates the same record, so channel ids that survive keep their favorites.

## Dropped

- Moved to the implementation plan: AC-2a, AC-2b, AC-2c, AC-6b, AC-8c, AC-12, AC-12a, AC-12b, AC-13c, AC-13d, AC-13e, AC-17b, AC-18c, AC-20, AC-20a, AC-22, AC-22a, AC-22b, AC-22c, AC-26c, AC-26d, AC-26e, AC-26f, AC-26g, AC-27.
- Moved to Edge cases: AC-2e, AC-3b, AC-13, AC-13b.
- Moved to Scope: AC-15.
- Merged into AC-1: AC-2, AC-2d.
- Merged into AC-3: AC-3a.
- Merged into AC-5: AC-4.
- Merged into AC-6: AC-6a, AC-7, AC-16.
- Merged into AC-8: AC-8a, AC-8b.
- Merged into AC-9: AC-10, AC-11, AC-21.
- Merged into AC-14: AC-13a.
- Merged into AC-17: AC-17a, AC-18, AC-18a, AC-18b.
- Merged into AC-26: AC-25, AC-26a, AC-26b.
