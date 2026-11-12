# Design

## Context

Boards: `openspec/specs/design-system/boards/iPhone-Import.dc.html`, `iPhone-Import-TooLarge.dc.html`, `iPhone-Import-Malformed.dc.html` (iOS; iPadOS and macOS show the same sheet centered), `iPad-Import.dc.html`, `iPad-Import-TooLarge.dc.html`, `iPad-Import-Malformed.dc.html` (iPadOS and macOS, including the drop target), and `iPhone-Onboard-3.dc.html` (the reading ring is reused from it).

Design-system requirements that apply: "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the link-list, single-stream and unreadable-file messages; the one-link offer to add it as a source; the reading state; the "imported before" row with Replace and Import as new; replace mode; the "Import a file instead" link on onboarding's playlist form; the file-source row in Sources and Settings on every platform, including Apple TV and its waiting-for-iCloud and waiting-for-login text.

## Goals / Non-Goals

**Goals:**
- One parser. The import check and the loader use the M3U parser and the same filter, so Live shows exactly what the summary counted.
- No login ever reaches the synced store or a log.

**Non-Goals:**
- An Apple TV sign-in path for a file source's logins. That follows the Apple TV Keychain decision from first-run onboarding.
- Matching a re-import on contents rather than file name.

## Decisions

- The order of the import checks, the login rules, and the agreed texts for the summary rows and every error are in the sections below.
- Storage, pending its decision: `SourceRecord` gains optional `playlistData` (external storage, synced as a CloudKit asset), `fileName` and `importedAt`; `kind` gains `m3uFile` with `url` nil. Lightweight migration. The CloudKit production schema needs the fields before release.
- The size limit is 16 MB, about 50 000 entries. It is checked before reading when the size is known, during reading otherwise, and before decoding. The owner can raise it to 32 MB if real files exceed it, or lower it on Apple TV if memory runs short.
- Core: `PlaylistImport.inspect(_:)` decides, in order, too large, decode (drop a UTF-8 byte-order mark, replace invalid bytes, accept UTF-16 with a mark), single HLS stream, link list, then `M3UParser` plus a filter that skips entries without a scheme. The loader uses the same filter.
- A single stream is refused, not offered as a one-channel source. The owner can reverse it.
- Logins: the query form (`username=…&password=…`), the Xtream path form (`/live/<user>/<pass>/<id>.ts`) and `user:pass@host` are replaced by placeholders and stored as one synchronizable Keychain item per source. The loader puts them back and never writes restored links to the store. Logs carry only the file name, byte count, outcome, number of moved logins and the source id.
- Edits to other changes, each its own PR: first-run onboarding (a file source counts as usable; the loading row names the file; the "Import a file instead" link), sources and settings (a record with no link is not skipped when it is a file source; delete calls the guide store's remove; the file source row shows "Imported <date> · <file>", has no Refresh and offers Re-import), guide data (guide links for a file source come from the file header), and live TV on iPhone, iPad and Mac plus the tvOS shell (waiting for iCloud is a terminal state shown where waiting for login is).
- Document types: the Antenna target registers M3U and M3U8 as an alternate viewer, not plain text. The Apple TV target registers nothing. The Mac build is not sandboxed, so the open panel and drops need no entitlement.
- Shared files land in `Documents/Inbox` on iOS. That copy is deleted after reading, whether or not the user imports. Security-scoped access is released before the sheet shows.
- Reading and checking run off the main actor, can be canceled, and stay within the M3U parser's parse time. Store changes are batched with a reload delay of about one second.
- Re-import updates the same record, so channel ids that survive keep their favorites.
- Ship as a stack: core checks and login stripping, then the sheet and ways in, then sync and waiting, then drag and drop.

## Import checks

`PlaylistImport.inspect(_:)` runs these checks in order, and the first that applies decides the outcome:

1. Too large: more than `maximumBytes` (16 MB) gives `.tooLarge(bytes:)`, before any decoding, so an oversized file that is not UTF-8 is still "too large" and not "no channels". Exactly `maximumBytes` passes. When the file's `fileSize` is known the reader does not read it at all; when it is unknown the reader reads at most `maximumBytes + 1` bytes.
2. Decode: drop a leading UTF-8 byte-order mark and decode as UTF-8, replacing each invalid byte with U+FFFD and keeping line endings. UTF-16 with a little- or big-endian mark is decoded as UTF-16, and the stored text is UTF-8. Windows-1252 bytes come out as U+FFFD, and UTF-16 without a mark ends as no channels. CRLF needs no conversion, because the M3U parser treats `\r\n` as one break.
3. Single HLS stream: a line starting `#EXT-X-TARGETDURATION`, `#EXT-X-MEDIA-SEQUENCE` or `#EXT-X-STREAM-INF` gives `.hlsStream`, whatever else the file holds. `#EXT-X-SESSION-DATA` in a channel list does not count.
4. Link list: when no line starts with `#EXTINF` and every non-empty line that does not start with `#` is an absolute `http` or `https` URL, at least one, the outcome is `.linkList(urls)` in file order.
5. Playlist: `M3UParser`, then a filter that skips entries whose stream URL has no scheme. The outcome is `.playlist(text:, playlist:, skipped:)`. A group left with no channel after the filter is not counted. When nothing is left the outcome is `.noChannels(sawEntries:)`, with `sawEntries` true only when there were `#EXTINF` entries whose links all lacked a scheme. An empty file, `#EXTM3U` alone, an HTML page, a PNG and `#EXTINF` lines with no link lines are all `sawEntries` false.

`PlaylistImport.channels(from:)` applies the same filter, so the loader lists exactly the channels the summary counted.

## Logins in links

- Two link forms are matched: the query form (`get.php?username=u1&password=p1&…`) and the path form, a path of exactly four segments whose first is `live`, `movie` or `series` and whose last is `<id>.<ext>` for any extension. `/live/u2/p2/9.m3u8` matches, `/live/u/p/8/9.ts` does not. `user:pass@host` is stripped too.
- `PlaylistImport.stripCredentials` returns one `StreamCredential` per distinct (host and port, username, password), in first-seen order, so the same login under two hosts is two entries. The text gets `{antenna.<token>.user.N}` and `{antenna.<token>.pass.N}` in their place, where N is the credential's index and `<token>` is a per-import value stored with the list. `restoreCredentials` gives back the original text byte for byte.
- Text in the file that only looks like a placeholder, such as `{antenna.user.0}` in a title, is left unchanged through stripping, storing and restoring.
- A file with no login in its links stores the decoded text as is, with `credentialKey` nil.
- Replacing a source's content with a file that has no logins sets `credentialKey` to nil and deletes the old Keychain item.
- Placeholders but no Keychain item on this device: the source shows as waiting for login and makes no stream request, then loads when the item arrives. A malformed item, or one with fewer credentials than the placeholders reference, fails the source, and no request carries placeholder text.

## Copy

Sheet, inspected file:

- `import.file` shows the file name and its size as `ByteCountFormatStyle(style: .file)`.
- Channels row: "<n> channels in <g> groups", with the first eight group names and "and <k> more" beneath. Numbers use `formatted()`, so sv-SE reads "1 240 channels in 3 groups" with U+00A0 as the separator.
- Guide row, only when the header has a guide link: "Guide link found" with the host beneath.
- Skipped row, only when entries were skipped: "<n> entries skipped" with "Not links" beneath.
- Name is prefilled with the file name without its extension, for example "home-playlist", and an empty Name saves as that. Guide URL is prefilled with the first header guide link. A Guide URL that does not parse saves as no guide link.

Errors (`import.error` title, then body). Import is disabled and nothing is saved:

| Case | Title | Body |
|------|-------|------|
| too large, size known | "This file is <size>. Antenna imports playlists up to 16 MB." (for example "This file is 41.7 MB. …") | "Split the file, or host it and add the link as an M3U source instead." |
| too large, size unknown | "This file is larger than 16 MB. Antenna imports playlists up to 16 MB." | "Split the file, or host it and add the link as an M3U source instead." |
| no channels, no entries | "No channels found in <file>." | "Antenna reads M3U playlists: #EXTINF lines, each followed by a stream link. This file has no such pair." |
| no channels, entries without links | "No channels found in <file>." | "The entries in this file are not links." |
| one link | "This file is a link, not a playlist." | "If it points to a playlist or a stream, add it as a source." |
| several links | "This file is a list of links, not a playlist." | "Add each link as its own M3U source." |
| single stream | "This is a single stream, not a channel list." | "Add the channel's playlist instead." |
| unreadable | "Could not read <file>. Make sure it is downloaded and try again." | none |

- Too large and unreadable offer `import.pickFile`. With one link, `import.addAsURL` reads "Add the link as a source" in its place; it closes the sheet and opens the add-source sheet with M3U selected and the link in the URL field (onboarding's when onboarding shows, otherwise the Settings one).
- A source whose Keychain item is unusable fails with "<name>: its saved login is unreadable. Re-import the file."

Same file name and re-import:

- When a file source with the same file name exists, a row reads "You imported <file> before as <name>", naming the one with the lowest `sortOrder`, then the earliest `createdAt`. `import.replace` reads "Replace <name>" (white) above `import.import` reading "Import as new" (surface). Guide URL is prefilled with that source's guide link, or the file header's when it has none.
- Replace mode, from a source's Re-import: the title is "Re-import <name>", there is no Name field, and `import.import` reads "Replace". The same-name row and `import.replace` never show in replace mode. A file that fails a check leaves the source unchanged.
- Replace keeps `id`, `name`, `sortOrder` and `createdAt`, and updates the content, `importedAt`, the guide link, the logins and, on re-import, `fileName`. When the source was deleted in the meantime, Replace inserts a new one.

Other states:

- Reading: `import.progress` inside `import.file` with a 26 pt indeterminate ring and "Reading <file>…" at 16 pt in place of the summary. Import is disabled. `import.cancel` stops the read and saves nothing.
- Drop target (iPad and Mac): `import.dropTarget` reads "Drop to import <file>", or "Drop to import a playlist" when the item has no suggested name, with the muted line "M3U, M3U8 and text files, up to 16 MB" beneath. It accepts a file conforming to `public.m3u-playlist` or `public.plain-text`, or a file URL ending in `m3u`, `m3u8` or `txt`, and shows nothing for images, strings or web links. A drop takes the first accepted file by its index in the drop and ignores the rest.
- Onboarding: "Import a file instead" is a 15 pt accent link under the Playlist URL field, identifier `import.pickFile`. After the import, the loading step's `onboarding.row.playlist` reads "Playlist imported" with the file name beneath.
- Sources list row for a file source: the name, with the file name beneath, or "Waiting for iCloud" while the content has not arrived. No Refresh.
- Waiting for iCloud in Live and the tvOS shell: "<name> · waiting for iCloud" in the slot waiting for login uses, and "<name>: waiting for its playlist to sync from iCloud" where the empty and error states list sources without a login.

## Risks / Trade-offs

- Open question: should Replace be offered on matching contents rather than matching file name? Can be settled during implementation.
- Open question: dropping several files imports the first. Should each get its own sheet? Can be settled during implementation.
- Open question: the reviewer suggested splitting this into four changes (core checks and login stripping, the sheet and ways in, sync and waiting, drag and drop). Kept as one, shipped as a stack; the owner decides.
- [Two devices re-importing the same source at once lose one copy without notice] → accepted for now.
- [iCloud storage full leaves the source on this device only with no message] → accepted for now.
- [Old Windows encodings show replacement characters in names] → accepted; only UTF-8 and UTF-16 with a mark are decoded.

## Implementation decisions

- The size limit is 16 000 000 bytes, decimal like the sizes `ByteCountFormatStyle` shows, so a file the sheet calls "16.2 MB" is never accepted.
- A file source's record keeps `url` nil, as decided. Its `SourceDescriptor` gets an `antenna-file:<id>?imported=<ms>` stand-in instead of making `url` optional across the app. The stamp changes with each import, so the screens that key their load on the descriptor load again after a re-import.
- `SourceRecord` also gains `playlistToken`, the value inside the placeholders. Replace keeps it when the new text does not contain it, so the channel ids stay the same.
- Channel ids come from the stored text with its placeholders, and links, logos and guide links from the text with the logins put back. A favorite's channel id therefore never holds a login, and a changed password does not change the ids.
- The logins item reuses `CredentialStoring`: one item per source, keyed by the record id, its username field set to `antenna.stream-logins` and its password field holding the JSON list of `StreamCredential`. No new Keychain code is needed.
- The loader reads the text through `PlaylistFileStore`, which holds the app's `ModelContainer` and opens its own `ModelContext` off the main actor. Whether the text has arrived is a count query on `playlistData != nil`, so the 5-second login check never reads the text.
- The header's guide link is not copied into `epgURL` while the Guide URL field still holds it. The loader reads it from the restored text, so a login in the guide link stays out of the synced store too.
- `SourceRefresher` leaves file sources out of Refresh all and the schedule once they have loaded in a run.
- XCUITest cannot drive the system file picker or the share sheet reliably. In a Debug build, `-ui-testing-import-file good,big` answers each "Import a file" and "Choose another file" with the next fixture from `UITestingImport`, and `-ui-testing-open-file good` puts one fixture in the inbox at launch the way `onOpenURL` does. Both hand a file URL to the same `ImportSheet` and `ImportReader` path a picked or shared file takes; only the picker and the system's delivery are skipped. Logins stay in memory under these arguments.
- `ImportInbox` holds a shared or opened file. It sits on the window root in `AntennaApp`, above every gate, and the sheet shows from `PlatformRoot` once the gates let it through, so a file shared while the paywall is up waits for the unlock. A file arriving while any import sheet is open, or while another waits, is ignored.
- "Choose another file" shows for every refused file except a one-link file, which offers "Add the link as a source" in its place. The Malformed board shows it for a file with no channels, so the board wins over the copy table's narrower list.
- Settings and the onboarding form each present their own import sheet from the picker. A file imported from onboarding's playlist form becomes a connection with the channels the sheet read, so the checklist starts at "Playlist imported" with the file name and nothing is fetched.
- The sheet reads the file through `NSFileCoordinator`, so a file in iCloud Drive that is not downloaded yet is fetched first instead of read as empty.
- Waiting for iCloud reuses the waiting-for-login state in Live and the Apple TV shell, with a `waitsForICloud` flag on the source row for the wording. The 5-second login check already loads a waiting source once `hasLogin` turns true, and for a file source that needs the text first, so the channels appear without a relaunch when the text arrives. A new state would have touched every switch over it in screens other changes are editing.
- `LiveSource` moved out of `LiveModel.swift` into its own file to keep that file under the 500-line limit.
- Re-import is `import.reimport` in a file source's details, the same picker and sheet in replace mode. The details show no link fields and no Refresh for a file source, since it has no link.
- The sources row and details start with "Imported <date> · <file>" for a file source, above the usual status line.
- Drops are taken on Settings, onboarding's welcome screen and the add-source form, on iPhone too, since the same modifier serves all three. XCUITest cannot start a drag from another app, so `-ui-testing-drop good|image|text` gives the drop target the item a drag would carry: the target shows for an accepted item, and tapping it runs the same load as a drop. Which items are taken is `PlaylistDropRule`, tested on its own.
- Deleting a file source needs nothing new: the text goes with the record, and `SourceRemoval` already deletes the Keychain item and the guide.
