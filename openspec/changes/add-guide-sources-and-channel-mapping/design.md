# Design

## Context

See proposal.md for why. Guide downloading, storage and lookup live in `guide-data`; this change turns its single link per source into a list and routes every channel lookup through hand-picked matches.

Boards, under `openspec/specs/design-system/boards/`: `iPad-GuideSources.dc.html` (iPadOS, macOS), `iPhone-GuideSources.dc.html` and `iPhone-GuideSources-Diagnosis.dc.html` (iOS), `TV-GuideSources.dc.html` (tvOS). Reused: `TV-Onboard-3-M3U.dc.html` and `iPhone-Onboard-2-M3U.dc.html` (the add-link form), `iPad-Search-Capped.dc.html` (the "Showing 200 of n" row), `iPad-Focus.dc.html` (keyboard focus ring).

Not drawn: the empty channel list ("every channel has a guide"); waiting for the guide; channels not loaded; the add-link form on each platform; guide actions on iPad, Mac and Apple TV, and swipe actions on iPhone; the search with no result or no guide; the search cap row; the offline, turned-off, waiting-for-login and reading status lines; the Re-enter link action; every reason card other than "Guide id not in the guide"; the "Guide from" card with Remove match; the collapsed list with "Show n channels"; drag handles and the context menu.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”, “Loading shows real progress per step”.

On iPad and Mac: Sources & Settings, a playlist, then Guide. The middle column shows the guides with their status, Add guide URL, and "Channels without guide" with a count. Selecting a guide shows Move up, Move down, Turn off, Retry now and Remove; rows also drag. Selecting a channel shows its reason and a search field filled with its name. Picking an entry fixes the match and drops the count by one. On iPhone it is one scrolling screen with a pushed channel detail. On Apple TV it slides over the live picture, which keeps playing; the search field opens the system keyboard and Menu goes back to the settings sheet.

## Goals / Non-Goals

**Goals:**
- Reorder and turn-on need no download.

**Non-Goals:**
- Matching by name a channel that has a guide id, fuzzy name matching, cross-playlist matches, merging programmes by time, and sweeping orphaned settings (it could delete a record whose source is still syncing).

## Decisions

- The agreed texts and the search ranking bands are under Copy and Search ranking below. Use them rather than writing new ones.
- Record: a new kind of synced record, `GuideSettingsRecord` with `sourceID: UUID?`, `payload: Data?` and `modifiedAt: Date`, every property optional or defaulted, nothing unique. The payload is a JSON `GuideSettings` from AntennaCore: the guide order, per guide an on/off flag, per added link its stored parts, per channel id a match, each entry with its own `modifiedAt`, and removals kept as tombstones so a merge can tell a removal from an edit the other device never saw. Duplicate records for one source merge per entry by the later timestamp, then are written back as one. Nothing is written until the user changes something. A record that does not decode is treated as empty and left alone.

  Options considered for the storage:
  1. One record per source holding everything (chosen). One fetch per screen, one CloudKit record per playlist, and the per-entry merge keeps both sides of two devices editing different channels at once.
  2. One record per match and per added link. CloudKit merges each row on its own, but a 2,000-channel playlist can mean 2,000 records, every one a duplicate risk resolved in code, and the order of guides still needs a record of its own.
  3. `NSUbiquitousKeyValueStore`. Ruled out by the hard constraints, and its 1 MB total is shared by every source.
- Matches are keyed by channel id. Since change `fix-m3u-channel-ids`, an M3U id is a hash of the guide id, name and group with an ordinal for repeats, so it holds no link and survives a reorder, a new password and a server move. It changes when the provider renames the channel or moves it to another group; the match then sits on the old id like a channel that left, as favorites do. Xtream, Stalker, Jellyfin and Channels DVR ids are the provider's own and survive a rename.
- One lookup: `GuideIndex.key(for: Channel) -> GuideKey?` returns the hand-picked entry, else the entry matched by name, else the playlist's own id. Every screen, Search, reminders and Top Shelf call it, through the store, instead of `GuideKey(channel:)`, which stays as the playlist's own id for the diagnosis. The index carries each source's matches, so a new match publishes a new index and every screen follows within one frame.
- Settings per playlist have a size cap of 2,000 matches and 50 added links, which keeps the payload far under CloudKit's 1 MB record limit; past it, matches for channels no longer in the playlist go first.
- Added links: the whole link goes to the synchronizable iCloud Keychain under service `se.codecrave.antenna.sources` with account `<sourceID>.guide.<linkID>`, never to the synced record, which keeps only the scheme, host and port for the row and the Re-enter form. A plain link with no user, password or query and a one-segment `.xml`, `.xml.gz` or `.gz` path is stored whole in the record instead. Storing the whole link rather than its secret parts means one Keychain item per link and no reassembly rules. Every link is shown through the guide store's `redacted(_:)`; no secret part reaches an identifier, label or log line.
- A channel id is never shown or logged. Since change `fix-m3u-channel-ids`, M3U ids come from the guide id, name and group, hold no link, and survive a reorder, so matches for M3U channels without `tvg-id` survive one too.
- The `guide-data` revision lands first as its own slice: the guide list per source replaces the single-link resolver; progress and failures are per guide; every lookup of a channel's guide goes through one store function that applies matches; caches are keyed by the source id and the guide reference (`provider`, `playlist(n)`, `saved`, `added(id)`) with a 64-bit FNV-1a hash of the resolved link to notice a changed link, never the link text.
- Per-guide status lives beside the index, not in it: download progress changes four times a second and would otherwise re-render every screen that reads the guide. Only the Guide sources screen reads it. `GuideProgress` events stay per source, so onboarding and the source status lines keep working; a failure is sent per source only while no guide of the source has loaded.
- Header links are tracked by position (`playlist(n)`), as the spec's "The header reorders its links" scenario asks, which settles the open question below.
- Sources that bring their own guide. The Xtream provider guide, the Stalker portal guide, and the Jellyfin and Channels DVR server guides are all the one "Provider guide" row of their source, first in the default order when no guide link was saved. It can be turned off but not removed. Every kind takes added links and hand-picked matches. A Jellyfin guide is asked for by channel ids, so its picker entries are only the channels the server has, named by their id when the server sends no name. A Stalker source with a saved guide link keeps the portal guide turned off, as Xtream does.
- Winning rule: per guide id, the highest enabled guide with at least one programme for it supplies all of that channel's programmes. A guide that lists an id with no programmes does not win it.
- Parse results of every enabled guide are kept for the life of the process so reorder and turn-on need no download. The storage decision may change this.
- The search reuses the search change's folding and token rules (`ChannelFilter.fold` and its tokens), runs on each keystroke, and offers only entries of the same playlist's guides.
- Matching by name. A channel qualifies only when it has no guide id (missing or blank) and no hand-picked match or undo. Its name and every entry's display name are folded with the search change's rules, split into tokens, and stripped of quality marks: `hd`, `fhd`, `uhd`, `sd`, `4k`, `hevc`, `h265`, `1080p`, `720p`, `50fps`, `60fps`, and a trailing `+1` is kept. The confidence is the share of tokens that agree after stripping. A match is applied only at full confidence, both token lists equal, and only when exactly one distinct entry id across the source's turned-on, loaded guides has those tokens. Anything less is neither applied nor suggested; the picker's ranking already puts an equal name first, so the user sees it on the top row. Name matches are worked out off the main actor after each guide load and each channel list, and published with the index; they are never synced, since every device works out the same answer from the same guides.
- Undoing a match by name stores a match with no entry for that channel, which syncs, so the channel stays unmatched after refreshes and on other devices. Picking an entry by hand replaces it. Removing that hand-picked match goes back to the playlist's id, and since the channel has none, to matching by name again.
- Deleting a source deletes its guide settings and their Keychain items in the same save. A settings record whose source is missing is ignored, never deleted, because the source may still be syncing.
- The provider's own guide stays off when the user saved their own guide link, to keep traffic as it is today. The owner can reverse it.
- Multiple guides and hand-matching stay in one change because the reasons need per-guide status and the search needs every guide's channel list. The owner can still split it.
- Test layers: guide listing, winning order, reasons and match survival run as core tests; turn-off, failures, undo and privacy as integration tests; adding, the channel list and picking as UI tests; sync on two devices.

## Copy

`<source>`, `<channel>`, `<guide>` and `<id>` are names filled in at run time. `<guide>` is the guide's display name below. Counts use the locale's grouping separator.

Guide names, first line of each guide row:

| Guide | Name | Second line |
|---|---|---|
| The provider's own guide | "Provider guide" | none |
| A link from the playlist header | "From the playlist" | the redacted link |
| The guide link saved with the source | "Guide URL" | the redacted link |
| A link the user added | the link's host | the redacted link; for a link whose parts sit in the Keychain, the host followed by "/…", for example "epg.example.com/…" |

Guide status line:

| State | Text | Style |
|---|---|---|
| Loaded | "Loaded · <channels with guide> of <channels> channels · <days> days" | normal |
| Started, no bytes yet | "Downloading" | normal |
| Downloading | "Downloading · <bytes>", bytes formatted as in `add-first-run-onboarding`, with an indeterminate ring | normal |
| After the last byte | "Reading the guide…" | normal |
| Offline | "Offline · retries when you're back online" | muted |
| Provider guide, login not on this device | "Waiting for login to sync from iCloud"; on Apple TV "Sign in to <source> on this Apple TV" | muted |
| Added link, its login not on this device | "Waiting for this guide's login to sync from iCloud"; on Apple TV "This guide link needs its login on this Apple TV" | muted |
| Failed | "Could not download · <reason>" | error |

"Loaded" counts the playlist's channels whose effective id (match or playlist id) has a programme ending after now in this guide alone. Failure reasons: "Server returned <n>" for an HTTP status, "Timed out", "Network error", "Not a guide file" for a malformed file or an unsupported encoding, "No programmes in the guide" for an empty guide, "Too large", "Login rejected", "Could not read login". Failed and offline rows offer Retry now, which reloads that guide only. A row whose login is missing offers Re-enter link, which opens the add form filled with the stored scheme and host and keeps the guide's place in the list.

Guide actions: "Move up", "Move down", "Turn off" or "Turn on", "Retry now", "Remove". Remove is offered only for links the user added. The add button reads "Add guide URL".

Add form errors:
- Empty text, or text without an `http` or `https` scheme: "Enter a valid URL."
- A link already in the list, compared on the full link including login and query: "This guide is already in the list." An added link whose Keychain item is missing on this device is never reported as a duplicate.

Reasons, checked in this order; the first that holds applies. Once any enabled guide has finished loading, "Not downloaded yet" no longer applies.

| Reason | When | Row label | Title | Body |
|---|---|---|---|---|
| Playlist loading | an M3U playlist has not delivered its guide links yet | "Loading" | "Waiting for the playlist" | "Antenna reads the guide links from the playlist when it finishes loading." |
| No guide | no enabled guide | "No guide" | "This source has no guide" | "Add a guide URL to get programme information for <source>." |
| Waiting for login | no enabled guide has finished, at least one is missing its login, and every other enabled guide failed | "Waiting for login" | "Waiting for the login to sync" (muted) | "The provider guide needs this source's login, which has not reached this device from iCloud yet." |
| Not downloaded | no enabled guide has finished and at least one is pending or downloading | "Not downloaded yet" | "The guide has not been downloaded yet" | "Downloading the guide · <bytes>" while a download runs, else "Antenna downloads the guide when the source finishes loading." |
| Offline | every enabled guide failed offline and none has finished | "Offline" | "You're offline" (muted) | "The guide downloads when you're back online." |
| Every guide failed | every enabled guide failed and none has finished | "Guide failed" | "The guide could not be downloaded" (error style) | one line per guide, "<guide> · <status line>" |
| Match not found | a hand-picked match exists and no enabled guide has any programme for its id, past or future | "Mapping not found" | "The mapped entry “<id>” has no programmes" | "Pick another entry below, or remove the mapping to go back to the playlist's id." |
| No guide id | no match and the channel's guide id is missing or blank | "No guide id" | "The source gives this channel no guide id" | "The playlist has no tvg-id for <channel>, and no guide entry has exactly its name. Pick an entry below." |
| Id not found | the id is in no finished guide's channel list and has no programmes | "Id not found" | "Guide id “<id>” is not in the guide"; with more than one finished guide "Guide id “<id>” is not in any of the <c> guides" | "“<guide>” does not list “<id>”." or "None of the <c> guides for <source> lists “<id>”.", then "Pick an entry below." |
| No programmes | a guide lists the id and no guide has a programme for it | "No programmes" | "The guide lists “<id>” but has no programmes for it" | "<guide> knows the channel but carries no programmes for it. Pick another entry below, or wait for the provider to fill it." |
| Guide ended | the id has programmes but none ending after now | "Guide ended" | "The guide for “<id>” has run out" | "<guide> lists programmes for this channel but none after now. Wait for the next guide refresh or pick another entry below." |
| Has a guide | the id has a programme ending after now | not listed | "Guide from <guide>" | "“<display name>” (<id>) · <days> days · Mapped by you", or "· Matched by name" or "· Matched by tvg-id" in place of the last part |

Variants:
- Waiting for login on Apple TV: title "Sign in on this Apple TV", body "The provider guide needs this source's login. Sign in from Sources & Settings."
- No guide id for an Xtream source: "The provider sends no epg_channel_id for <channel>" replaces the first clause of the body.
- `<c>` is the number of enabled guides that have finished loading on this device. A match with only past programmes is "Guide ended", not "Match not found".

Suffix lines, added to the body of every reason except Every guide failed, Offline and Waiting for login, with t enabled guides:
- "<k> of <t> guides could not be downloaded." when k enabled guides last failed with an error other than offline or missing login.
- Then "1 guide is still downloading." or "<j> guides are still downloading." when j enabled guides are pending or downloading.
- No suffix when both are 0.

Channel column, the first state that holds wins:

| State | Header | Column shows |
|---|---|---|
| The playlist has no channels (not loaded, failed, waiting for its login, or Stalker) | "Channels without guide" | "Channels have not loaded for <source>" (muted); the guide rows and Add guide URL still work |
| One reason covers the whole playlist (Playlist loading, No guide, Waiting for login, Offline, Every guide failed) | "Channels without guide · <n>" | that reason's card and a "Show <n> channels" button that shows the rows |
| Every enabled guide pending or downloading | "Channels without guide" | one row "Waiting for the guide…" with an indeterminate ring |
| No channel lacks a guide | "Channels without guide · 0" | "Every channel in <source> has a guide" |
| Otherwise | "Channels without guide · <n>" | the rows in All channels order, each with logo or initials, name, number and row label |

Below the channel column, when any channel was matched by name: a "Matched by name · <n>" header and its rows, each with logo or initials, name, number and the matched entry's display name. Selecting one shows its "Guide from" card. The card of a channel mapped by you or matched by name has a "Remove match" button.

The filter (iPhone, iPad and Mac only) is hidden in every state but the last. It narrows the rows by name and number on each keystroke, and the header count keeps the unfiltered total.

Picker:
- The field starts with the channel's name. An empty field shows no rows and no message.
- Result row detail line: "<id> · <guide> · <n> programmes", with "1 programme" for one and "no programmes" for none. `<guide>` is the guide that would win the id.
- More than 200 results: 200 rows, then "Showing 200 of <n>".
- No match: "No guide entry matches “<query>”" with the caption "Try a shorter name or the channel's tvg-id."
- No guide of the playlist has finished: "The guide has not been downloaded yet." with no caption.
- Over the size cap with nothing left to drop: "Too many mappings for this source. Remove some to add more." in the error style.

## Identifiers

`guideSources.row.<n>` for the n-th guide row (0-based, in list order), with `.status` and `.actions` children; `guideSources.add`; `guideSources.addForm.field`, `guideSources.addForm.save`, `guideSources.addForm.error`; `guideSources.channels.header`, `guideSources.channels.row.<n>`, `guideSources.channels.filter`, `guideSources.channels.showAll`, `guideSources.channels.empty`; `guideSources.named.header`, `guideSources.named.row.<n>`; `guideSources.reason.title`, `guideSources.reason.body`; `guideSources.picker.field`, `guideSources.picker.row.<n>`, `guideSources.picker.empty`; `guideSources.removeMatch`; and `settings.details.guide.sources` for the Guide row in a source's details. Rows are numbered by position, never by link, id or name, so nothing secret or provider-specific reaches an identifier.

## Layout

- iPhone: Settings, a source, then the Guide row pushes Guide sources: the guides, Add guide URL, Channels without guide with the filter, then Matched by name, in one scrolling list. A channel row pushes its detail: the reason or Guide from card, Remove match where it applies, and the picker.
- iPad and Mac: the same push from the source's details. The screen splits in two: the guides and channel lists on the left, the selected channel's detail and picker on the right, which is empty until a channel is selected.
- Apple TV: the same push inside the settings sheet over the live picture, two columns as on iPad. Guide actions are a confirmation dialog on select; a channel opens its detail in the right column, and its search field opens the system keyboard.

## Search ranking

The picker matches the folded query over each entry's display name and id, using the folding and token rules of change `add-search`. Results rank by band, then alphabetically by display name, then by guide order:

1. The folded display name equals the folded query.
2. The display name starts with the full query.
3. A word of the display name starts with the first token.
4. The display name contains the full query.
5. Every token is found in the display name.
6. Every token is found in the display name or the id, with at least one found only in the id.

The picker shows one row per distinct id across the playlist's enabled guides, with the display name and count of the highest guide that has programmes for it, or of the first guide listing it when none has. A guide that lists an id without a channel element shows the id as the name. Matched text is highlighted in the name, or in the detail line when a token is found only in the id.

Example: guide entries "Sport One HD" (`sport1.se`), "Sport One" (`sportone`), "Eurosport One" (`eurosport1`), "One Sport" (`one.sport`) and "News One" (`nyheter.se`); query "Sport One". Results: "Sport One" (band 1), "Sport One HD" (band 2), "Eurosport One" (band 4), "One Sport" (band 5). "News One" is absent because "sport" is in neither its name nor its id.

## Risks / Trade-offs

- [One record per playlist can lose a change when two devices edit at once] → per-entry merge with tombstones; the storage decision may pick a finer shape.
- [A provider renames an M3U channel] → its hand-picked match no longer applies, as its favorite does not. The channel shows in the list again and can be picked once more.
- [Matching by name picks the wrong channel when two guides name different channels the same] → only a unique name across every turned-on guide is applied; the user sees each match under "Matched by name" and can undo it.

## Implementation decisions

- `GuideLookup.key(for:)` is the one app-side lookup. It reads the store the app runs on through a weak static reference set when the store is made, because reminders, the Search index and the Guide's open-at-a-programme code have no view environment to read it from. With no store, as in previews and scripted UI test launches, a channel's key is its own guide id. Search builds its index off the main actor, so it takes `GuideIndex.key(for:)` from the index it already holds.
- A source's guides load in one pass, top first. A failed guide shows on its row at once, but `GuideProgress.failed` for the source is sent only when the pass ends with nothing loaded, and then for the highest failed guide. Onboarding and the source status lines read that event, so one broken guide among working ones never reads as a failed source there.
- Programmes from a portal or Jellyfin guide carry no channel names, so their entries are named after the source's channel with that guide id.
- Matches by name are worked out again on each guide load, each channel list and each settings change, and published with the index. They need a programme in the matched entry, since an entry without one gives the channel nothing.
- Guide settings reach the engine through the source list it reads, and a change, saved here or arriving through iCloud, is handed over by a modifier inside `SourceDeletions`, which both shells already attach. A tombstone keeps the cap honest: removed matches count toward it and go first when a new match needs room.
