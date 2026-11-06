# Design

## Context

See proposal.md for why. Guide downloading, storage and lookup live in `guide-data`; this change turns its single link per source into a list and routes every channel lookup through hand-picked matches.

Boards, under `openspec/specs/design-system/boards/`: `iPad-GuideSources.dc.html` (iPadOS, macOS), `iPhone-GuideSources.dc.html` and `iPhone-GuideSources-Diagnosis.dc.html` (iOS), `TV-GuideSources.dc.html` (tvOS). Reused: `TV-Onboard-3-M3U.dc.html` and `iPhone-Onboard-2-M3U.dc.html` (the add-link form), `iPad-Search-Capped.dc.html` (the "Showing 200 of n" row), `iPad-Focus.dc.html` (keyboard focus ring).

Not drawn: the empty channel list ("every channel has a guide"); waiting for the guide; channels not loaded; the add-link form on each platform; guide actions on iPad, Mac and Apple TV, and swipe actions on iPhone; the search with no result or no guide; the search cap row; the offline, turned-off, waiting-for-login and reading status lines; the Re-enter link action; every reason card other than "Guide id not in the guide"; the "Guide from" card with Remove match; the collapsed list with "Show n channels"; drag handles and the context menu.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”, “Loading shows real progress per step”.

Decisions this builds on: adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only).

On iPad and Mac: Sources & Settings, a playlist, then Guide. The middle column shows the guides with their status, Add guide URL, and "Channels without guide" with a count. Selecting a guide shows Move up, Move down, Turn off, Retry now and Remove; rows also drag. Selecting a channel shows its reason and a search field filled with its name. Picking an entry fixes the match and drops the count by one. On iPhone it is one scrolling screen with a pushed channel detail. On Apple TV it slides over the live picture, which keeps playing; the search field opens the system keyboard and Menu goes back to the settings sheet.

## Goals / Non-Goals

**Goals:**
- Reorder and turn-on need no download.

**Non-Goals:**
- Automatic name matching, cross-playlist matches, merging programmes by time, and sweeping orphaned settings (it could delete a record whose source is still syncing).

## Decisions

- `docs/specs/0021-guide-sources-and-channel-mapping.md` at 0bce26a holds the agreed texts: guide status lines, each reason's title and body, row labels, empty and waiting states, and the search ranking bands. Use them rather than writing new ones.
- Record (pending the decision record, adr-0002 rules): one guide-settings record per source holding the encoded guide order and on/off flags, added links, matches, and removal tombstones so a merge can tell a removal from an edit the other device never saw. Duplicate records merge per entry by the later timestamp, then are written back as one. Nothing is written until the user changes something. A record that does not decode is treated as empty and left alone.
- Settings per playlist have a size cap; past it, matches for channels no longer in the playlist go first.
- Added links: the username, password, path and query go to the Keychain (adr-0003), except a plain link with no password or query and a one-segment `.xml`, `.xml.gz` or `.gz` path, which is stored whole. Every link is shown through the guide store's `redacted(_:)`; no secret part reaches an identifier, label or log line.
- A channel id is never shown or logged while M3U ids embed the stream URL. Until the `m3u-playlists` follow-up, M3U channels without `tvg-id` get position-based ids and their matches break on reorder.
- The `guide-data` revision lands first as its own slice: the guide list per source replaces the single-link resolver; progress and failures are per guide; every lookup of a channel's guide goes through one store function that applies matches; caches are keyed by a hash of the guide reference, never the link text.
- Winning rule: per guide id, the highest enabled guide with at least one programme for it supplies all of that channel's programmes. A guide that lists an id with no programmes does not win it.
- Parse results of every enabled guide are kept for the life of the process so reorder and turn-on need no download. The storage decision may change this.
- The search reuses the search change's folding and token rules, runs on each keystroke, and offers only entries of the same playlist's guides.
- Deleting a source deletes its guide settings and their Keychain items in the same save. A settings record whose source is missing is ignored, never deleted, because the source may still be syncing.
- The provider's own guide stays off when the user saved their own guide link, to keep traffic as it is today. The owner can reverse it.
- Multiple guides and hand-matching stay in one change because the reasons need per-guide status and the search needs every guide's channel list. The owner can still split it.
- Test layers: guide listing, winning order, reasons and match survival run as core tests; turn-off, failures, undo and privacy as integration tests; adding, the channel list and picking as UI tests; sync on two devices.

## Risks / Trade-offs

- [One record per playlist can lose a change when two devices edit at once] → per-entry merge with tombstones; the decision record may pick a finer shape.
- Open question: one synced record per playlist (assumed) or one per match and per added link? The decision record settles it.
- Open question: should guide links from the playlist header be tracked by link rather than by position, so a reordered header does not shuffle them? Can be decided during implementation.
