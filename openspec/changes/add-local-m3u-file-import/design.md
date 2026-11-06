# Design

## Context

Boards: `openspec/specs/design-system/boards/iPhone-Import.dc.html`, `iPhone-Import-TooLarge.dc.html`, `iPhone-Import-Malformed.dc.html` (iOS; iPadOS and macOS show the same sheet centred), `iPad-Import.dc.html`, `iPad-Import-TooLarge.dc.html`, `iPad-Import-Malformed.dc.html` (iPadOS and macOS, including the drop target), and `iPhone-Onboard-3.dc.html` (the reading ring is reused from it).

Design-system requirements that apply: "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the link-list, single-stream and unreadable-file messages; the one-link offer to add it as a source; the reading state; the "imported before" row with Replace and Import as new; replace mode; the "Import a file instead" link on onboarding's playlist form; the file-source row in Sources and Settings on every platform, including Apple TV and its waiting-for-iCloud and waiting-for-login text.

Decisions this builds on: adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only).

## Goals / Non-Goals

**Goals:**
- One parser. The import check and the loader use the M3U parser and the same filter, so Live shows exactly what the summary counted.
- No login ever reaches the synced store or a log.

**Non-Goals:**
- An Apple TV sign-in path for a file source's logins. That follows the Apple TV Keychain decision from first-run onboarding.
- Matching a re-import on contents rather than file name.

## Decisions

- The previous revision of the old spec in git history holds the agreed texts for the summary rows and every error, and the order of the import checks.
- Storage, pending its decision: `SourceRecord` gains optional `playlistData` (external storage, synced as a CloudKit asset), `fileName` and `importedAt`; `kind` gains `m3uFile` with `url` nil. Lightweight migration. The CloudKit production schema needs the fields before release.
- The size limit is 16 MB, about 50 000 entries. It is checked before reading when the size is known, during reading otherwise, and before decoding. The owner can raise it to 32 MB if real files exceed it, or lower it on Apple TV if memory runs short.
- Core: `PlaylistImport.inspect(_:)` decides, in order, too large, decode (drop a UTF-8 byte-order mark, replace invalid bytes, accept UTF-16 with a mark), single HLS stream, link list, then `M3UParser` plus a filter that skips entries without a scheme. The loader uses the same filter.
- A single stream is refused, not offered as a one-channel source. The owner can reverse it.
- Logins: the query form (`username=…&password=…`), the Xtream path form (`/live/<user>/<pass>/<id>.ts`) and `user:pass@host` are replaced by placeholders and stored as one synchronizable Keychain item per source (adr-0003). The loader puts them back and never writes restored links to the store. Logs carry only the file name, byte count, outcome, number of moved logins and the source id.
- Edits to other changes, each its own PR: first-run onboarding (a file source counts as usable; the loading row names the file; the "Import a file instead" link), sources and settings (a record with no link is not skipped when it is a file source; delete calls the guide store's remove; the file source row shows "Imported <date> · <file>", has no Refresh and offers Re-import), guide data (guide links for a file source come from the file header), and live TV on iPhone, iPad and Mac plus the tvOS shell (waiting for iCloud is a terminal state shown where waiting for login is).
- Document types: the Antenna target registers M3U and M3U8 as an alternate viewer, not plain text. The Apple TV target registers nothing. The Mac build is not sandboxed, so the open panel and drops need no entitlement.
- Shared files land in `Documents/Inbox` on iOS. That copy is deleted after reading, whether or not the user imports. Security-scoped access is released before the sheet shows.
- Reading and checking run off the main actor, can be cancelled, and stay within the M3U parser's parse time. Store changes are batched with a reload delay of about one second.
- Re-import updates the same record, so channel ids that survive keep their favorites.
- Ship as a stack: core checks and login stripping, then the sheet and ways in, then sync and waiting, then drag and drop.

## Risks / Trade-offs

- Open question: should Replace be offered on matching contents rather than matching file name? Can be settled during implementation.
- Open question: dropping several files imports the first. Should each get its own sheet? Can be settled during implementation.
- Open question: the reviewer suggested splitting this into four changes (core checks and login stripping, the sheet and ways in, sync and waiting, drag and drop). Kept as one, shipped as a stack; the owner decides.
- [Two devices re-importing the same source at once lose one copy without notice] → accepted for now.
- [iCloud storage full leaves the source on this device only with no message] → accepted for now.
- [Old Windows encodings show replacement characters in names] → accepted; only UTF-8 and UTF-16 with a mark are decoded.
