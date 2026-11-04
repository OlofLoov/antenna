# 0037. Local M3U file import on iPhone, iPad and Mac

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- ADR needed: where imported playlist text lives and how big it may be. This spec assumes a `Data` field with external storage on `SourceRecord`, synced as a CloudKit asset, capped at `PlaylistImport.maximumBytes` (16 000 000 bytes, "16 MB" in `ByteCountFormatStyle(style: .file)`). The alternative is a separate blob record related to `SourceRecord`. ADR-0003 keeps secrets out of the data model, so this spec assumes credentials inside stream URLs (`get.php?username=…&password=…`, `/live/<user>/<pass>/<id>.ts`) are stripped to the Keychain on import and put back at load (AC-26 to AC-26d); the ADR confirms that or supersedes ADR-0003 with a reason. Adding `playlistData`, `fileName` and `importedAt` to `SourceRecord` is a schema change, so the ADR carries the migration note (see Edge cases) and the iCloud quota cost of a 16 MB asset per source. This spec stays Draft until that ADR is Accepted, and no feature code is written before. The ADR also records that one Keychain item per file source holds a JSON list of credentials for any number of hosts, a format ADR-0003 does not describe yet. The ADR also states whether `playlistData` can be nil on a synced record under SwiftData mirroring; if it cannot, AC-18 to AC-18c remain as defensive behaviour for a failed asset download and the 0023 hint is dropped.
- Platforms: iOS, iPadOS, macOS (import). tvOS shows a synced file source but cannot import.
- Builds on specs 0001 (parsing), 0004 (`SourceRecord`, Settings list, loader, delete), 0006 (onboarding entry point and loading step), 0010 and 0015 (the waiting slot the waiting-for-iCloud state reuses), 0013 (tagging, favorites by `sourceID`), 0014 (guide URLs from the header). 0006 lists local file import as out of scope; this spec is that feature.
- Requires edits in other specs, each in its own PR (details under "Required of other specs"): 0006/AC-1 and AC-2, whose usable-source rule becomes "a `SourceRecord` with a non-nil `url`, or with `kind == .m3uFile` regardless of `playlistData`"; 0006/AC-10b, whose `onboarding.row.playlist` reads "Playlist imported" with the file name beneath for a file source; 0014/AC-1, whose table gains two `.m3uFile` rows identical to the first two M3U rows and whose `GuideURLResolver.resolve` takes `url: URL?`, ignored for `.m3uFile`; 0004's edge case "a `SourceRecord` with `url == nil` is silently skipped", which exempts `kind == .m3uFile`. Until those edits merge, the rules here hold for `.m3uFile` and the sibling specs hold for every other kind.
- Entry points owned elsewhere: `import.pickFile` in the Sources list and `import.reimport` are wired by the Sources and Settings spec (0023, not yet written; the number comes from the brief for this spec). Until it lands, AC-1 places `import.pickFile` in 0004/AC-7's Settings list, AC-27 defines the file source row there, and AC-14 is tested by presenting replace mode directly.

## Design

Boards: `docs/design/boards/iPhone-Import.dc.html` (iOS, full-screen sheet; iPadOS and macOS centre the same content in a 390 pt sheet as 0006 does), `iPhone-Import-TooLarge.dc.html`, `iPhone-Import-Malformed.dc.html`, `iPad-Import.dc.html` (the active drop target over Sources and Settings, with the detail of a file source), `iPad-Import-TooLarge.dc.html`, `iPad-Import-Malformed.dc.html`. The sources list and source detail on the iPad boards are context for the drop target; 0023 owns their design and may change them.
Design rules that apply: DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15. Deviation: DR-3, the done markers in `import.summary` and the "Import a file" links use the accent, as 0006's done markers and Fill in control do.
States on the boards:
- File inspected (iPhone-Import): `import.file` with name and size, `import.summary` with the channels row, the guide row and the skipped row, `import.field.name`, `import.field.guideURL`, the iCloud note at 13 pt muted, `import.import` enabled (52 pt, white).
- Too large (iPhone-Import-TooLarge, iPad-Import-TooLarge): `import.error` title 17 pt `#FF5F57`, body 15 pt `#D7DEE8`, `import.import` disabled (surface fill, muted text), `import.pickFile` as a 52 pt secondary control.
- No channels found (iPhone-Import-Malformed, iPad-Import-Malformed): same anatomy as too large with the AC-9 text.
- Active drop target (iPad-Import): `import.dropTarget` is a 200 pt tall zone with a 2 pt dashed ring in the Text colour and the 0.08 surface fill, 20 pt title, 15 pt muted line. Idle, the zone is absent; the whole window is the drop area and the ring appears on drag-over.
Not drawn, trivial variants of the drawn states:
- Link list (AC-10): the error anatomy with the AC-10 text; with one link, `import.addAsURL` ("Add the link as a source") replaces `import.pickFile` as the 52 pt secondary control.
- Single stream (AC-11) and unreadable file (AC-21): the error anatomy with their text.
- Login left in a link (AC-26e): the inspected state with `import.warning` under `import.summary`, 15 pt in the Text colour on the 0.06 surface, Import enabled.
- Interim file source row (AC-27): a 0004 Settings row with the name at 17 pt and `fileName` or "Waiting for iCloud" at 13 pt muted beneath.
- Reading (AC-22): `import.progress` inside `import.file` with a 26 pt indeterminate ring (as the guide row on iPhone-Onboard-3) and "Reading <file>…" at 16 pt in place of `import.summary`; `import.import` disabled.
- Same file name (AC-13): a 60 pt summary row "You imported <file> before as <name>" at 16 pt with the muted 13 pt detail, then `import.replace` (52 pt, white) above `import.import` reading "Import as new" (52 pt, surface).
- Replace mode (AC-14): the inspected state with the title "Re-import <name>", `import.field.name` hidden and `import.import` reading "Replace".
- "Import a file instead" on 0006's M3U form (AC-23): a 15 pt accent link under the Playlist URL field, identifier `import.pickFile`.
- tvOS source row for a file source and the waiting-for-iCloud row text: owned by 0023 and drawn with its boards. The waiting line inside Live and `shell.empty` (AC-18a) reuses the drawn waiting-for-login rows of 0010 and 0015.
These are drawn as boards before the implementing PR opens. The boards in the repo are exports; the design canvas needs the same screens.

## Problem

Some providers hand out a playlist file rather than a link, and some users build their own `.m3u` from several providers and have nowhere to host it. Today the only way in is a URL, so these users cannot add their channels at all. A file picked on iPhone also has to reach the Apple TV, where the file does not exist, so the content has to travel with the source rather than a path to it.

## Scope

In:
- `SourceKind.m3uFile` in AntennaCore. `SourceDescriptor.url` becomes optional and is nil for this kind.
- `PlaylistImport` in AntennaCore: `maximumBytes = 16_000_000`, `inspect(_ data: Data) -> Outcome` with cases `.playlist(text: String, playlist: Playlist, skipped: Int)`, `.linkList([URL])`, `.hlsStream`, `.noChannels(sawEntries: Bool)`, `.tooLarge(bytes: Int)`, and `channels(from text: String) -> (channels: [Channel], skipped: Int)`, the scheme filter the loader and `inspect` share. Outcomes are decided in this order: `.tooLarge` (byte count, before decoding), then decode (AC-12, AC-12a), then `.hlsStream` (any line starting `#EXT-X-TARGETDURATION`, `#EXT-X-MEDIA-SEQUENCE` or `#EXT-X-STREAM-INF`), then `.linkList` (AC-10 rule), then parse with `M3UParser` (0001) and the scheme filter; zero channels after the filter is `.noChannels` with `sawEntries` true when the parser produced at least one channel before the filter. There is no second parser. `PlaylistImport.stripCredentials(_ text: String) -> (text: String, credentials: [StreamCredential])` and `restoreCredentials(_ text: String, _ credentials: [StreamCredential]) -> String` (AC-26) are pure functions in the same type.
- `SourceRecord` gains `playlistData: Data?` (external storage), `fileName: String?`, `importedAt: Date?`. A file source has `kind == .m3uFile` and `url == nil`; `credentialKey` is nil unless AC-26 stripped credentials, in which case it names one `CredentialStore` item holding the `[StreamCredential]` list as JSON.
- Entry points on iOS, iPadOS and macOS: `import.pickFile` in the Settings source list (0004/AC-7, later 0023) and on 0006's M3U form, which opens the system file picker; the app registered as a handler for `public.m3u-playlist` so it appears in the share sheet for a file and in Finder's Open With, and receives the file through the open-URL path; drag and drop onto the app window on iPadOS and macOS.
- `project.yml`: `CFBundleDocumentTypes` for the M3U and M3U8 types on the Antenna target only (AC-2a). Plain text is accepted by the picker and drops but not registered, so Antenna does not appear in Open With for every text file. The AntennaTV target gets none. The Mac build is not sandboxed today (`Config/Antenna.entitlements` is empty), so the open panel and drops need no entitlement. If the macOS build is sandboxed later, `com.apple.security.files.user-selected.read-only` is added through `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` pointing at a macOS-only entitlements file; enabling the sandbox itself, and the network client entitlement it needs, is out of scope.
- Calling `remove(sourceID:)` (0014/AC-18a) and deleting the Keychain item from the 0004/AC-6 delete path for a `.m3uFile` source. Wiring the same call for other kinds belongs to 0004 (Required of other specs).
- One import sheet for every entry point: file, inspection summary, Name, Guide URL, Import. Replace mode for re-import and for a file name already imported.
- The loader decodes `playlistData` and runs it through `PlaylistImport.channels(from:)`, so Live shows exactly the channels the summary counted; `M3UParser` is never called on `playlistData` directly. No request is made for the playlist. Header guide URLs reach 0014 through `register(epgURLs:for:)`.
- No refresh for a file source. Re-import replaces the content on the same record so favorites whose `Channel.id` survives keep resolving.
- Sync of the content to every device, Apple TV included, and the waiting-for-iCloud state while the asset has not arrived. A file source whose Keychain item has not synced yet uses the existing waiting-for-login state (AC-26c).
- Accessibility identifiers with prefix `import.`.

Out (explicitly):
- Import on tvOS (no file picker, no share sheet). A later spec may add import through a paired iPhone; none is planned.
- Watching a file for changes, or a security-scoped bookmark to the original. The content is copied once.
- Importing an XMLTV guide file (a guide spec; 0014 downloads guides only).
- Importing `.pls`, `.xspf`, `.json` or Kodi playlists.
- Gzipped playlists (0001 lists them out).
- Exporting a source as a file.
- Merging two files into one source.
- The Sources and Settings screen itself: rows, ordering, delete, edit, refresh-all (0023).
- `#EXTVLCOPT` and `#KODIPROP` headers (0001 open question).

Required of other specs:
- 0006: the usable-source rule and row text in the header (AC-1, AC-2, AC-10b), and AC-23's flow as its own criterion. AC-4a's M3U form gains `import.pickFile` (AC-23 here). The welcome and add-source sheets accept drops on iPadOS and macOS (AC-3 here).
- 0004 (or 0023 once it owns the sheet): the `url == nil` skip exempts `.m3uFile`; the delete path calls `remove(sourceID:)` for every kind. AC-9's ordering by `sortOrder` is unchanged. The Settings add-source sheet gains identifiers `addSource.type` and `addSource.field.url`, asserted by AC-10 here.
- 0014: the two `.m3uFile` rows in AC-1 and `resolve(url: URL?)`.
- 0010 and 0015: waiting-for-iCloud is a fourth terminal state alongside loaded, failed and waiting-for-login in 0010/AC-16 and 0015/AC-11, and a source in it does not hold 0015/AC-2b's deadline. The waiting-for-iCloud line (AC-18a here) renders in the slot 0010/AC-24 and 0015/AC-11 give to waiting for login, and 0010/AC-18 and AC-20 list it where they list credential-less sources.
- 0023: a file source row shows "Imported <date> · <fileName>" where a URL source shows its refresh time, has no Refresh action, is skipped by refresh-all, offers `import.reimport` on iOS, iPadOS and macOS, and on tvOS reads "Imported from a file. Re-import on iPhone, iPad or Mac." with no action; the row, including its waiting-for-iCloud text, is focusable and reachable with the remote. 0023 also owns a hint for a record whose asset never arrives. AC-27 is the interim row until 0023 replaces it.

## User flow

iOS:
1. Settings source list, tap "Import a file…". The Files picker opens on M3U and plain-text files.
2. Pick a file. The import sheet shows the file name and size, then a ring and "Reading <file>…" while the file is inspected off the main actor.
3. The summary appears: channels and groups, whether a guide link was found, how many entries were skipped. Name is prefilled with the file name without extension, Guide URL with the first `url-tvg` link.
4. Tap Import. The sheet closes, the source appears in the list, and Live lists its channels within a few seconds (AC-6a). The guide, if any, downloads as for any M3U source.
5. Alternatively, in Files or Mail, share an `.m3u` file to Antenna. The app opens on the same sheet at step 2, over whatever was on screen, or once the root view is up at a cold launch.

iPadOS and macOS:
1. As above, with the sheet centred at 390 pt. On Mac the picker is the open panel and Finder's Open With lists Antenna.
2. Drag a file from Files, Finder or Mail over the Antenna window. A dashed ring appears where it will land; dropping shows the sheet at step 2. Dropping anything that is not a file of an accepted type does nothing.

Re-import: the file source's detail (0023) offers "Re-import…". The picker opens; the sheet opens in replace mode; Replace swaps the content on the same record.

tvOS: nothing to do. The source and its channels arrive through iCloud. Until the content has arrived, the source shows as waiting for iCloud and contributes no channels.

Onboarding (no sources yet): the M3U form of 0006 has "Import a file instead". Import leads to 0006's loading step with the playlist row naming the file.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Pick a file
Given the Settings source list (0004/AC-7; 0023's Sources and Settings when it lands) on iOS, iPadOS or macOS
When the user activates `import.pickFile`
Then the model's `fileImporterConfiguration` has `allowedContentTypes == [.m3uPlaylist, .plainText]` and `allowsMultipleSelection == false`; with an injected picker result `import.sheet` appears with `import.file` reading the file's name and its size as `ByteCountFormatStyle(style: .file)`; with an injected cancel no sheet appears and the store is unchanged.

### AC-2 Opened from another app, read
Given the app is registered as AC-2a
When an open-URL for a file arrives at launch or while the shell or onboarding is shown
Then `import.sheet` appears with `import.file` reading that file's name, and the injected reader reports security-scoped access stopped before the sheet appeared, also when the read failed (AC-21). A `false` return from `startAccessingSecurityScopedResource` is not an error; Inbox copies and Finder's Open With return it.

### AC-2a Document type registration
Given the Antenna target's built Info.plist
When it is read
Then `CFBundleDocumentTypes` has one entry with `LSHandlerRank == Alternate` and `CFBundleTypeRole == Viewer` whose `LSItemContentTypes` contains `UTType(filenameExtension: "m3u")` and `UTType(filenameExtension: "m3u8")` (one entry if both resolve to the same type) and no `public.plain-text`, and `LSSupportsOpeningDocumentsInPlace` is false or absent.

### AC-2b Inbox copy deleted (iOS, iPadOS)
Given an open-URL whose file is under the app's `Documents/Inbox`
When its bytes have been read, or the read has failed
Then the file no longer exists, whether or not Import follows.

### AC-2c Scene that shows the sheet
Given an open-URL arrives
When the sheet is shown
Then on iOS and iPadOS `import.sheet` is in the scene that received the open-URL, or in the key scene once the root view is up at a cold launch; on macOS it is in the frontmost existing window, or the first window at a cold launch; the number of open scenes or windows is unchanged.

### AC-2d Nothing of the file's location persisted
Given any import through the picker, an open-URL or a drop, completed or cancelled
When the store and `UserDefaults` are read
Then no `SourceRecord` field and no `UserDefaults` value contains a bookmark, a file URL or a path of the file.

### AC-2e File arriving while the sheet is shown
Given `import.sheet` is shown for file A, reading or inspected
When an open-URL for file B arrives
Then the sheet still shows A, B's bytes are not read and its Inbox copy, if any, is deleted; activating `import.pickFile` inside the sheet and picking B replaces A with B and inspects B.

### AC-3 Drag over the window (iPadOS, macOS)
Given the Settings source list, the 0006 welcome sheet or the add-source sheet, on iPadOS or macOS
When a drag enters the window whose item providers include a file of a type conforming to `public.m3u-playlist` or `public.plain-text` (any extension), or a file URL (as Finder provides on macOS) whose path extension is `m3u`, `m3u8` or `txt`
Then `import.dropTarget` appears reading "Drop to import <file>", or "Drop to import a playlist" when the provider has no `suggestedName`, with the muted line "M3U, M3U8 and text files, up to 16 MB" beneath.

### AC-3b Other payloads
Given the screens of AC-3
When a drag enters carrying only other payloads (an image, a string, a web URL)
Then no `import.dropTarget` appears.

### AC-3a Drop
Given `import.dropTarget` is shown
When the drag is dropped
Then `import.sheet` appears with the first accepted file by index in the drop's provider array, whatever order their loads complete in, and the rest are ignored; a drop whose providers hold no accepted file does nothing and the store is unchanged; a drop while `import.sheet` is already shown is ignored, as an open-URL is (AC-2e); only `import.pickFile` inside the sheet replaces its file.

### AC-4 Inspection of a playlist file
Given `Data` holding a UTF-8 playlist with the header `#EXTM3U url-tvg="http://a/epg.xml"`, 412 entries with `http` or `https` URLs across 18 groups, and 3 entries whose URL line has no scheme (`./local.ts`, `stream.ts`), of which 2 share groups with other entries and 1 is the only entry of group "Local"
When `PlaylistImport.inspect` runs
Then it returns `.playlist(text:, playlist:, skipped: 3)` where `playlist.channels` equals `M3UParser().parse(text).channels` minus the 3 channels whose `streamURL.scheme` is nil, in the parser's order, `playlist.channels.count` is 412, `playlist.epgURLs` is `[http://a/epg.xml]`, `playlist.groups.count` is 18 (a group with no channel left after the filter is not counted, so "Local" is absent), and `text` is the decoded file; `channels(from: text)` returns the same 412 channels and `skipped: 3`.

### AC-5 Summary and prefilled fields
Given the outcome of AC-4 for a file named `home-playlist.m3u`, and a second fixture of 1 240 channels in 3 groups with no header URL and no skipped entries
When `import.sheet` renders each
Then for the first `import.summary` has a row reading "412 channels in 18 groups" with the first eight group names and "and 10 more" beneath (as 0006/AC-10a), a row "Guide link found" with the host beneath, and a row "3 entries skipped" with "Not links" beneath; `import.field.name` holds "home-playlist"; `import.field.guideURL` holds the first of `epgURLs`; `import.import` is enabled; for the second, in sv-SE, the channels row reads "1 240 channels in 3 groups" (the separator is U+00A0, as `formatted()` produces) with the three names and no "and n more", and the guide and skipped rows are absent.

### AC-6 Import saves a file source
Given the AC-5 sheet for the first fixture, whose stream URLs carry no credentials, with Name "Home" and the prefilled Guide URL
When the user activates `import.import`
Then exactly one `SourceRecord` is inserted with `kind == .m3uFile`, `url == nil`, `credentialKey == nil`, `name == "Home"`, `fileName == "home-playlist.m3u"`, `epgURL` equal to the Guide URL field, `importedAt` equal to the injected clock, `playlistData == text.data(using: .utf8)`, `sortOrder` as 0004/AC-2, and the sheet is dismissed.

### AC-6a Imported source loads without relaunch
Given the Live section is shown with one loaded source
When AC-6's save commits and the injected clock is advanced by 2 seconds
Then the new source's channels are listed, with no user action, and its load ran once.

### AC-6b Empty name and bad guide URL
Given the AC-5 sheet with Name cleared, and Guide URL "not a url" in one case and empty in another
When the user activates `import.import`
Then the record's `name` is "home-playlist" (the file name without its extension), and `epgURL` is nil in both cases (`URL(string:)` returned nil, or the field was empty), as the 0004 Settings form stores it.

### AC-7 Loader reads the stored text
Given a `SourceRecord` with `kind == .m3uFile` and `playlistData` holding the AC-4 text, and a stubbed `URLSession` that fails every request
When sources load
Then the source contributes the AC-4 channels tagged with its `id` (0013/AC-1), in the order `PlaylistImport.channels(from:)` returns them, `channels.count` is 412 and not 415, the stub records no request, `register(epgURLs: [http://a/epg.xml], for:)` is called before `update(channels:)` (0014 call order), and `lastRefreshedAt` stays nil.

### AC-8 Too large, size known before reading
Given a picked or dropped file whose `fileSize` resource value is 41 700 000 bytes, locale en-US
When the sheet appears
Then the injected file reader records no read, `import.error` reads "This file is 41.7 MB. Antenna imports playlists up to 16 MB." with the body "Split the file, or host it and add the link as an M3U source instead.", `import.import` is disabled, `import.pickFile` is offered, and nothing is saved.

### AC-8a Too large, checked before decoding
Given `Data` of `maximumBytes + 1` bytes that is not valid UTF-8 and contains no `#EXTM3U`
When `PlaylistImport.inspect` runs
Then it returns `.tooLarge(bytes: maximumBytes + 1)` and not `.noChannels`.

### AC-8b Too large, size unknown
Given a file whose `fileSize` resource value is unavailable and whose content is larger than `maximumBytes`, locale en-US
When the sheet appears
Then the injected reader records one read with a limit of `maximumBytes + 1` bytes, `import.error` reads "This file is larger than 16 MB. Antenna imports playlists up to 16 MB." with the body "Split the file, or host it and add the link as an M3U source instead.", `import.import` is disabled, `import.pickFile` is offered, and nothing is saved.

### AC-8c Exactly at the limit
Given `Data` of exactly `maximumBytes` bytes holding a valid playlist
When `PlaylistImport.inspect` runs
Then it returns `.playlist`.

### AC-9 No channels
Given `Data` that is empty, only `#EXTM3U`, an HTML page containing an `<a href="http://x/y.m3u">` line, a PNG, `#EXTINF` lines with no URL lines, or `#EXTINF` lines whose URL lines all lack a scheme
When `PlaylistImport.inspect` runs
Then it returns `.noChannels(sawEntries:)` with `sawEntries` true only for the last case, and `import.sheet` renders `import.error` "No channels found in <file>." with the body "Antenna reads M3U playlists: #EXTINF lines, each followed by a stream link. This file has no such pair." when `sawEntries` is false and "The entries in this file are not links." when it is true, `import.import` disabled, and nothing is saved.

### AC-10 Link list
Given `Data` with no line AC-11 matches, whose non-empty lines, after dropping lines that start with `#`, are all absolute `http` or `https` URLs, at least one, and no line starts with `#EXTINF`
When `PlaylistImport.inspect` runs
Then it returns `.linkList(urls)` in file order; with exactly one URL `import.error` reads "This file is a link, not a playlist." with the body "If it points to a playlist or a stream, add it as a source." and `import.addAsURL` reads "Add the link as a source", which dismisses the sheet and presents the add-source sheet (0006's when onboarding is showing, otherwise the Settings add-source sheet of 0004/AC-2) with M3U selected (`onboarding.type.m3u` or `addSource.type`) and the URL field (`onboarding.field.url` or `addSource.field.url`) holding the link; with more than one URL `import.error` reads "This file is a list of links, not a playlist." with the body "Add each link as its own M3U source." and no `import.addAsURL`; nothing is saved either way.

### AC-11 Single stream
Given `Data` within the size limit with a line starting `#EXT-X-TARGETDURATION`, `#EXT-X-MEDIA-SEQUENCE` or `#EXT-X-STREAM-INF`, with or without `#EXTINF` lines or URL lines, and a second fixture, a channel list of `#EXTINF` entries that also carries an `#EXT-X-SESSION-DATA` line
When `PlaylistImport.inspect` runs
Then the first returns `.hlsStream` and `import.sheet` renders `import.error` "This is a single stream, not a channel list." with the body "Add the channel's playlist instead.", `import.import` disabled, and nothing is saved; the second returns `.playlist`.

### AC-12 Decoding UTF-8
Given `Data` that starts with the UTF-8 BOM, uses CRLF line endings and contains one `0xFF` byte inside a channel title
When `PlaylistImport.inspect` runs
Then the outcome is `.playlist` decoded by this rule: drop a leading UTF-8 BOM, decode as UTF-8 with each invalid byte replaced by U+FFFD, keep line endings. So `text` has no BOM and keeps CRLF, and `playlist.channels` equals the parse of a fixture with the same entries written with LF endings, no BOM and one U+FFFD in place of the `0xFF` byte. CRLF needs no conversion because 0001's `M3UParser` splits on `Character.isNewline`, which treats `\r\n` as one break, so no stream URL ends in `\r`.

### AC-12b Windows-1252 and UTF-16 without a BOM
Given the AC-4 playlist with one channel title in Windows-1252 (`Caf\xE9`) and no BOM, and the AC-4 playlist as UTF-16LE with no BOM
When `PlaylistImport.inspect` runs
Then the first returns `.playlist` with 412 channels and that title reading "Caf\u{FFFD}"; the second returns `.noChannels(sawEntries: false)`.

### AC-12a Decoding UTF-16
Given the AC-4 playlist encoded as UTF-16 with a little-endian BOM, and again with a big-endian BOM
When `PlaylistImport.inspect` runs
Then both return `.playlist` with the AC-4 channels, and the text AC-6 stores is UTF-8.

### AC-13 Same file name imported before
Given a `.m3uFile` record R named "Home" with `fileName == "home-playlist.m3u"`, a second `.m3uFile` record with the same `fileName` and a higher `sortOrder`, and a picked file of that name that inspects to `.playlist`
When `import.sheet` renders it
Then `import.summary` gains a row "You imported home-playlist.m3u before as Home", naming the record with the lowest `sortOrder` among those sharing the file name, and on equal `sortOrder` the earliest `createdAt`.

### AC-13a Replace keeps the record
Given AC-13's sheet, and `FavoriteRecord`s with `sourceID == R.id` of which one has a `channelID` the new text produces and one has a `channelID` it does not
When the user activates `import.replace`
Then R's `playlistData`, `importedAt`, `epgURL` (from the field) and, per AC-26a, `credentialKey` and its Keychain item are updated, `id`, `name`, `sortOrder` and `createdAt` are unchanged, no record is inserted, the first favorite resolves (0013/AC-8) and the second is in `unresolvedFavorites`.

### AC-13b Import as new
Given AC-13's sheet
When the user activates `import.import`
Then a second record is inserted as AC-6 and R is unchanged.

### AC-13c Same file name, controls and guide URL
Given AC-13's sheet, with R's `epgURL` `http://c/epg.xml` and the file's header `url-tvg="http://a/epg.xml"`, and a variant where R's `epgURL` is nil
When the sheet renders
Then `import.replace` reads "Replace Home" and `import.import` reads "Import as new"; `import.field.guideURL` holds `http://c/epg.xml`, and in the variant `http://a/epg.xml`.

### AC-13d Replace target deleted meanwhile
Given AC-13's sheet, and R is deleted on this device or by sync before the user acts
When the user activates `import.replace`
Then one record is inserted as AC-6 and the sheet is dismissed.

### AC-13e Replace drops old credentials
Given a `.m3uFile` record R with a `credentialKey`, and a file whose stream URLs carry no credentials
When the user replaces R's content with it (AC-13a or AC-14)
Then R's `credentialKey` is nil and `CredentialStore` has no item for the old key.

### AC-14 Re-import
Given `import.sheet` presented in replace mode for a `.m3uFile` record R (entry point `import.reimport`, wired by 0023; tests present the mode directly)
When the user picks a file that inspects to `.playlist` and activates `import.import`
Then the sheet title is "Re-import <R.name>", `import.field.name` is absent, `import.field.guideURL` is prefilled as AC-13c says, `import.import` reads "Replace", AC-13's same-name row and `import.replace` are never shown in replace mode, and the save updates R as AC-13a does, including `fileName` when it differs; a file that inspects to anything else behaves as AC-8 to AC-11 and R is unchanged.

### AC-15 No refresh
Given a `.m3uFile` record and a URL M3U record
When the 0004 load repeats on appearance, or `scenePhase` becomes `.active`
Then no request is made for the file source, its `lastRefreshedAt` stays nil, and the stub records exactly one request, for the URL source. The file source's guide, if any, follows 0014/AC-13 on its own; that is 0014's test.

### AC-16 Guide URLs flow to 0014
Given a `.m3uFile` record whose text has `url-tvg="http://a/epg.xml,http://b/epg.xml"` and `epgURL` nil, and another whose text has the same header and `epgURL` set to `http://c/epg.xml`
When `GuideURLResolver.resolve` runs for each after the loader's `register(epgURLs:for:)`
Then the results are `http://a/epg.xml` and `http://c/epg.xml`, matching 0014/AC-1 rows one and two for M3U; a file source with no header URL and `epgURL` nil resolves to none and its keys report `.unavailable`.

### AC-17 Content syncs to Apple TV
Given a file source imported on iPhone from a 15 MB file whose stream URLs carry credentials
When an Apple TV on the same iCloud account is online
Then the source appears in its Sources list, its channels are listed, playback of one works, and the Apple TV made no file access and no request for the playlist. Manual two-device check; CloudKit cannot run in CI.

### AC-17a Asset arrives after the record, device
Given two devices on one iCloud account and a file source imported on one while the other is in the background
When the second comes to the foreground
Then it shows the source as waiting for iCloud (AC-18a) or loaded, and once loaded shows its channels without relaunch. Manual check, run with AC-17.

### AC-17b Large file on Apple TV
Given the AC-22c fixture (16 MB, 50 000 entries) synced to an Apple TV HD
When sources load
Then the source's channels are listed within the 0001/AC-14 bound plus 2 seconds, and the app is not terminated for memory. Manual check with Instruments.

### AC-18 Waiting for iCloud, loader
Given a `SourceRecord` with `kind == .m3uFile` and `playlistData == nil`
When sources load
Then it contributes zero channels, is reported as waiting for iCloud, which is neither loaded nor failed and counts as terminal wherever 0010/AC-16, 0015/AC-10, 0015/AC-11 and 0015/AC-2b count waiting-for-login as terminal, no request is made for it, and its guide keys report `.unavailable` (0014/AC-11) because `register(epgURLs:for:)` has not run.

### AC-18a Waiting for iCloud, shown
Given the record of AC-18 on iOS, iPadOS, macOS or tvOS
When the Live section (0010) or `shell.empty` (0015/AC-11) is shown
Then `browse.group.waiting.<sourceId>` (regular width), `browse.banner.waiting.<sourceId>` (compact) or `shell.empty.source.<sourceId>` reads "<name> · waiting for iCloud" in the slot 0010/AC-24 and 0015/AC-11 use for waiting for login, and `browse.empty` and `browse.error` list it as "<name>: waiting for its playlist to sync from iCloud" where 0010/AC-18 and AC-20 list credential-less sources; on tvOS while a channel from another source plays nothing is shown and 0023's row is the only indication.

### AC-18b Waiting for iCloud, arrival
Given the record of AC-18
When `playlistData` becomes non-nil in the store and the injected clock is advanced by 2 seconds
Then its channels are listed and the waiting line of AC-18a is gone, with no user action, and its load ran once.

### AC-18c Waiting for iCloud, scene activation
Given the record of AC-18 is shown as waiting, and the store now holds `playlistData` for it
When `scenePhase` becomes `.active`
Then the source loads and its channels appear.

### AC-19 tvOS has no import
Given tvOS
When the Settings source list, the 0006 type picker and the M3U form are shown
Then no element with an identifier starting `import.` exists, focus moves through each screen with the remote through the same elements as without this spec, and the AntennaTV target's Info.plist has no `CFBundleDocumentTypes`.

### AC-20 Held while the paywall is shown
Given the paywall is shown (ADR-0006)
When an open-URL or drop arrives
Then no `import.sheet` is shown while the paywall is up.

### AC-20a Shown after the paywall
Given AC-20's held file
When the entitlement provider reports entitled in the same launch
Then `import.sheet` appears with `import.file` reading that file's name, and before Import no `SourceRecord` exists for it. If the app is terminated first the file is gone, because AC-2b deleted its Inbox copy; the user shares it again.

### AC-21 Unreadable file
Given a picked file whose read fails (an iCloud Drive file not downloaded, or a permission error)
When the sheet appears
Then `import.error` reads "Could not read <file>. Make sure it is downloaded and try again.", `import.import` is disabled, `import.pickFile` is offered, and nothing is saved.

### AC-22 Reading state
Given a fake reader that suspends until released
When the sheet appears
Then `import.progress` shows an indeterminate ring with "Reading <file>…" and `import.import` is disabled; after release the outcome renders and `import.progress` is gone.

### AC-22a Off the main actor
Given a fake reader and inspector that record whether they ran on the main actor
When a file is read and inspected
Then both record that they did not.

### AC-22b Cancel while reading
Given AC-22's suspended reader
When the user activates `import.cancel`
Then the sheet is dismissed, the reader's task observes cancellation, no outcome renders afterwards, and nothing is saved.

### AC-22c Inspection time
Given a 16 MB fixture of 50 000 entries
When `PlaylistImport.inspect` runs on the CI runner
Then it returns `.playlist` within the 0001/AC-14 bound. Benchmark, not CI-gated.

### AC-23 Import from onboarding
Given 0006's M3U form (0006/AC-4a) on iOS, iPadOS or macOS
When the user activates `import.pickFile` under the Playlist URL field and imports a file that inspects to `.playlist`
Then the record of AC-6 is saved, 0006's loading step follows with `onboarding.row.playlist` reading "Playlist imported" with the file name beneath and `onboarding.row.channels` as 0006/AC-10b, and the guide row follows AC-16; a zero-channel file never reaches the loading step because AC-9 disables Import.

### AC-24 Delete removes the content
Given a `.m3uFile` record with a `credentialKey`
When the user deletes it (0004/AC-6 path)
Then no `SourceRecord` with that `id` exists, `remove(sourceID:)` was called once on the guide store (0014/AC-18a), and `CredentialStore` has no item for that `credentialKey`.

### AC-25 Nothing from the file in logs
Given any inspection outcome and any import, from a fixture whose URLs carry credentials
When the injected logger is inspected
Then every line contains at most the file name, the byte count, the outcome case name, the number of stripped credentials and the `sourceID`; no line contains a line of the playlist text, a stream URL, a username, a password, or a guide URL other than through 0014's `redacted(_:)`.

### AC-26 Credentials stripped on import
Given a playlist whose stream URLs are `http://p.example:8080/get.php?username=u1&password=p1&type=ts&id=7`, `http://p.example:8080/live/u1/p1/8.ts`, `http://q.example/live/u2/p2/9.m3u8` and `http://r.example/9.ts`
When `PlaylistImport.stripCredentials` runs
Then it returns two `StreamCredential`s, (`p.example:8080`, u1, p1) and (`q.example`, u2, p2), in first-seen order, one per distinct (host and port, username, password) so the same pair under two hosts is two entries; the returned text has each username and password replaced by `{antenna.<token>.user.N}` and `{antenna.<token>.pass.N}`, N being the credential's index and `<token>` an injected per-import value stored with the list, in both the query form and the path form, which is a path of exactly four segments whose first is `live`, `movie` or `series` and whose last is `<id>.<ext>` for any extension (`/live/u2/p2/9.m3u8` matches, `/live/u/p/8/9.ts` does not); the `r.example` line is unchanged; and `restoreCredentials` on the result returns the original text byte for byte.

### AC-26a Credentials go to the Keychain
Given AC-26's playlist in an import sheet
When the user activates `import.import`
Then the record's `playlistData` holds the stripped text and contains neither "p1" nor "p2", `credentialKey` is non-nil, and `CredentialStore` holds the two credentials under that key as one synchronizable item (ADR-0003).

### AC-26b Loader restores credentials
Given the record of AC-26a
When sources load
Then each channel's `streamURL` equals the URL in the original file, and no restored URL is written to the store.

### AC-26c Credential not yet synced
Given a `.m3uFile` record with a `credentialKey` and `playlistData`, and `CredentialStore` with no item for that key
When sources load
Then, because a placeholder in `playlistData` has no credential to fill it, the source contributes zero channels, is reported as waiting for login and shown as 0010/AC-24 and 0015/AC-11 show it, and no request is made for its streams; when the item appears it loads as AC-18b does.

### AC-26d No credentials found
Given a playlist whose URLs match neither stripping pattern of AC-26
When it is imported
Then `credentialKey` is nil and `playlistData` equals the decoded text, as AC-6 says.

### AC-26e Login left in a link
Given a playlist with a stream URL carrying userinfo (`http://u:p@h.example/x.ts`)
When `import.sheet` renders it
Then `import.warning` reads "Some links contain a login and will sync to iCloud as text." and `import.import` stays enabled. The ADR may decide to strip userinfo instead, which removes this criterion.

### AC-26f Placeholder-like text in the file
Given a playlist that already contains the literal `{antenna.user.0}` in a title
When it is stripped, stored and restored at load
Then that title reads `{antenna.user.0}` unchanged.

### AC-26g Credential item unusable
Given a `.m3uFile` record whose Keychain item holds malformed JSON, or fewer credentials than its placeholders reference
When sources load
Then the source is reported as failed with "<name>: its saved login is unreadable. Re-import the file.", no stream request carries placeholder text, and no log line contains the item's contents.

### AC-27 Interim row in the 0004 list
Given 0023 has not landed and the 0004/AC-7 Settings list holds a `.m3uFile` record
When the list renders
Then its row shows the name with `fileName` beneath, has no Refresh action, and with `playlistData` nil the line beneath reads "Waiting for iCloud"; on tvOS the row takes focus and is reachable with the remote.

## Edge cases and failure modes

- Offline: import works fully offline, and a loaded file source lists its channels with every request failing (AC-7). The guide download of AC-16 fails per 0014/AC-12 and retries per 0014/AC-13.
- Huge file: 16 000 000 bytes is about 50 000 entries at the 300 bytes a typical `#EXTINF` plus URL takes. The limit is checked before reading when the size is known (AC-8), during reading otherwise (AC-8b), and in `inspect` before decoding (AC-8a). Parsing stays within 0001/AC-14.
- Credentials inside stream URLs: AC-26 to AC-26d strip the query and Xtream path forms. Other forms (credentials in a path the pattern does not match, `user:pass@host`) are stored as the file has them; the ADR decides whether `user:pass@host` is stripped too. AC-25 keeps every form out of logs.
- A provider rotates the password: the stripped text still loads, streams fail with the old password, and re-import (AC-14) writes the new one to the Keychain item.
- A plain M3U of bare stream URLs with no `#EXTINF` lines is a link list (AC-10), not a channel list. With one URL the offer reads "Add the link as a source", which fits a playlist link and a direct stream alike; with several nothing is offered.
- A relative URL entry (`./x.ts`) has no base to resolve against, so AC-4 skips it and AC-5 counts it. A URL with a scheme the player cannot play (`rtmp://`) is kept; playback failure is the playback spec's concern.
- A file with `#EXT-X-TARGETDURATION` or `#EXT-X-MEDIA-SEQUENCE` and `#EXTINF` lines is an HLS media playlist whose `#EXTINF` lines are segments, not channels; AC-11 refuses it ahead of AC-10 and AC-9. Other `#EXT-X-` lines, which some channel lists carry, do not trigger it.
- `#EXTINF` lines without a comma or title, duplicates, `#EXTGRP`, catch-up tags: 0001 governs; this spec adds no rule.
- Favorites of channels without `tvg-id` do not survive a re-import that reorders entries, because their `Channel.id` is positional (0001 edge case), until the 0001 follow-up on hashed ids lands. Favorites of channels with `tvg-id` survive unless the stream URL changed.
- Share sheet on iOS: the system copies the file to `Documents/Inbox`; AC-2 deletes that copy after reading.
- A file whose declared type is `public.plain-text` but whose content is a playlist is accepted; a file whose extension is `.m3u` but whose content is HTML lands in AC-9. Content decides, never the extension.
- Several open-URLs in a row: the first wins while the sheet is up (AC-2e).
- Open-URL over onboarding's welcome, type or details step: Import saves as AC-6 and continues with 0006's loading step as AC-23. Over the loading or ready step: Import adds a second source and 0006/AC-16b applies after.
- Not signed into iCloud: the store works locally, the file source is local to this device, and nothing tells the user (0004 edge case).
- Eviction: CloudKit mirroring may purge a downloaded asset and fetch it again. While `playlistData` reads nil the source is waiting for iCloud (AC-18); the ADR states whether this happens under SwiftData.
- Paywall: the picker entry points sit behind the paywall like every screen (DR-14); only open-URL and drop can arrive before it, which AC-20 covers.
- `token=`, `key=` and `auth=` query values are not recognised as credentials and sync as text. The ADR decides whether to widen AC-26.
- Sync lag: the record can arrive before its asset, and before its Keychain item. AC-18 to AC-18c and AC-26c cover it.
- iCloud quota: each file source costs up to 16 MB of the user's iCloud storage. When the upload fails (quota full, not signed in) the source works on this device and never reaches the others; SwiftData mirroring reports no per-record error, so nothing is shown here. 0023's hint for a record whose asset never arrives is the user's only signal, on the other device.
- Two devices re-import the same source at once: CloudKit keeps one `playlistData`; the loser's content is lost without notice (ADR-0002 consequence, same as `sortOrder`).
- Older app builds that do not know `m3uFile` read `kindRaw` as `.m3u` (0004 edge case) with `url == nil` and skip the record. A file source shows in their Settings list as an M3U source with no URL. They show no channels for it and do not crash.
- Migration note for the ADR: three optional fields on `SourceRecord`; SwiftData lightweight migration; the CloudKit production schema must carry the new fields before release.
- Memory: `playlistData` is read once per load and the `String` is released after parsing (AC-17b checks it on Apple TV HD); the record's other fields load without the asset because of external storage. SwiftData's external storage and CloudKit mirroring keep their own files under Application Support, which is why AC-24 asserts on the store and not on files.
- Dynamic Type at accessibility sizes: the sheet scrolls; Import stays at the bottom.
- VoiceOver: `import.summary` rows read title then detail; `import.dropTarget` is announced on drag-over.
- The file picker on macOS runs as the open panel. The Mac build is not sandboxed today, so the panel and drops need no entitlement (Scope says what changes if it is). Open With and the Dock icon drop deliver through the same open-URL path.

## Test plan

Inspection is pure over `Data` in AntennaCore. The sheet's logic lives in a `@MainActor` model taking an injected file reader (returns bytes, size or an error for a URL, records the byte limit it was asked for, owns start and stop of security-scoped access, and records the order of start, read and stop relative to the sheet appearing), picker result, clock, logger, entitlement provider, `ModelContainer` and `GuideStore`, so AC-1, AC-2 to AC-2e, AC-8, AC-8b, AC-20, AC-20a and AC-21 run without the picker. The sources model takes an injected clock and a `reloadDelay` for AC-6a and AC-18b, and an in-memory `CredentialStore` for AC-26a to AC-26c. Exact strings (AC-5, AC-8 to AC-11, AC-13c, AC-18a, AC-26e, AC-26g) are asserted on the view model's output; UI tests check identifiers and enabled state only, per `docs/conventions.md`. Tests pin `reloadDelay` at 1 second for AC-6a and AC-18b. The drop handler takes `[NSItemProvider]` so AC-3 and AC-3a run without a drag. The loader test reuses 0004's `URLSession` seam. Identifiers: `import.sheet`, `import.cancel`, `import.file`, `import.progress`, `import.summary`, `import.field.name`, `import.field.guideURL`, `import.error`, `import.warning`, `import.import`, `import.replace`, `import.addAsURL`, `import.pickFile`, `import.reimport`, `import.dropTarget`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | integration (configuration, injected result and cancel) + ui | TBD |
| AC-2 | integration (open-URL into the model, fake reader records access order) | TBD |
| AC-2a | integration (built Info.plist) | TBD |
| AC-2b | integration (temp directory as Inbox) | TBD |
| AC-2c | ui (iPad two scenes; macOS two windows) | TBD |
| AC-2d | integration (store and `UserDefaults` scanned after each path) | TBD |
| AC-2e | integration (second open-URL during each state) | TBD |
| AC-3 | integration (drop handler fed `NSItemProvider`s per payload type) + ui smoke on iPad with an in-app drag source | TBD |
| AC-3b | integration (drop handler) | TBD |
| AC-3a | integration (drop handler) + ui | TBD |
| AC-4 | core (`PlaylistImport`) | TBD |
| AC-5 | ui (two fixtures, sv-SE) | TBD |
| AC-6 | integration (in-memory `ModelContainer`, injected clock) | TBD |
| AC-6a | integration (store observation, injected clock) | TBD |
| AC-6b | integration | TBD |
| AC-7 | integration (stubbed session, fake `GuideStore`) | TBD |
| AC-8 | integration (fake reader reporting size) + ui | TBD |
| AC-8a | core | TBD |
| AC-8b | integration (reader with unknown size records the limit) + ui | TBD |
| AC-8c | core | TBD |
| AC-9 | core (parameterised) + ui (both bodies) | TBD |
| AC-10 | core + ui (one and many links) | TBD |
| AC-11 | core + ui | TBD |
| AC-12 | core | TBD |
| AC-12a | core | TBD |
| AC-12b | core | TBD |
| AC-13 | integration (two records sharing a name) + ui | TBD |
| AC-13a | integration (favorites fixture) | TBD |
| AC-13b | integration | TBD |
| AC-13c | ui | TBD |
| AC-13d | integration (record deleted before Replace) | TBD |
| AC-13e | integration (in-memory `CredentialStore`) | TBD |
| AC-14 | integration (replace mode presented directly) + ui | TBD |
| AC-15 | integration (stubbed session, injected clock) | TBD |
| AC-16 | core (`GuideURLResolver`) + integration | TBD |
| AC-17 | device | manual two-device check |
| AC-17a | device | manual, with AC-17 |
| AC-17b | device | manual, Apple TV HD with Instruments |
| AC-18 | integration | TBD |
| AC-18a | ui (iPhone, iPad and tvOS, including `browse.empty`) | TBD |
| AC-18b | integration (store mutation, injected clock) | TBD |
| AC-18c | integration (scenePhase driven, no notification) | TBD |
| AC-19 | ui (tvOS) + integration (tvOS Info.plist) | TBD |
| AC-20 | integration (entitlement provider flips) | TBD |
| AC-20a | integration (entitlement provider flips) | TBD |
| AC-21 | integration (reader throwing) + ui | TBD |
| AC-22 | integration (suspending reader) + ui | TBD |
| AC-22a | integration (actor-recording fakes) | TBD |
| AC-22b | integration (cancellation) + ui | TBD |
| AC-22c | core benchmark, not CI-gated | TBD |
| AC-23 | ui + integration | TBD |
| AC-24 | integration (store, fake `GuideStore`, in-memory `CredentialStore`) | TBD |
| AC-25 | integration (logger asserted against the fixture text) | TBD |
| AC-26 | core (`PlaylistImport.stripCredentials`, round trip) | TBD |
| AC-26a | integration (in-memory `CredentialStore`) | TBD |
| AC-26b | integration | TBD |
| AC-26c | integration + ui | TBD |
| AC-26d | core + integration | TBD |
| AC-26e | core + integration | TBD |
| AC-26f | core (round trip) | TBD |
| AC-26g | integration (malformed item, short list) | TBD |
| AC-27 | ui | TBD |

## Open questions

- Storage (ADR decides): a `Data` field with external storage on `SourceRecord`, as assumed, or a separate record. The field is simpler; the record keeps the asset out of every `SourceRecord` fetch for sure.
- Credential-bearing stream URLs (ADR decides): the spec strips the query and Xtream path forms to one Keychain item per source (AC-26). The alternative, syncing them inside `playlistData`, needs ADR-0003 superseded. Is `user:pass@host` stripped too (AC-26e assumes not)?
- 16 MB: enough for about 50 000 entries. Raise to 32 MB if real files exceed it; the cost is sync time and a longer parse on Apple TV.
- Should `import.replace` be offered on matching content rather than matching file name? Content equality catches re-exports with a new name; file name catches edits to the same file, which is the common case.
- Dropping several files: import the first (AC-3a), or queue a sheet per file?
- Should a file that inspects to `.hlsStream` be offered as a single channel named after the file? Today AC-11 refuses it.
- UTF-16 without a BOM and Windows-1252 are not detected (AC-12). Add detection if users report garbled names.
- `reloadDelay` of 1 second (AC-6a, AC-18b) is a choice; any value that batches CloudKit's bursts works.
- Entry point in Live's empty state (0010/AC-18) belongs to 0010; not decided here.
- 0023's number and title come from the brief for this spec; its branch did not exist when this was written.
- Size: the reviewer suggests splitting this spec into core inspection and stripping, the import sheet and entry points, sync and waiting states, and drag and drop. Kept as one spec with one stack of PRs in that order; the owner decides at review.
- A lower size limit on tvOS, where memory is tighter, if AC-17b fails on Apple TV HD.
