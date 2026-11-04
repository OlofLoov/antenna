# 0021. Guide sources per playlist and manual channel-to-guide mapping

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- ADR needed: one `GuideOverridesRecord` per source in the synced container of ADR-0002, holding the guide order and enabled flags, user-added guide URLs and channel mappings as the JSON encoding of AntennaCore's `GuideOverrides`; the alternative is one record per mapping and one per guide URL. Every criterion below is written against the per-source record and names that assumption where it matters (AC-13a to AC-13e, AC-25, AC-27, AC-29). Migration note: `GuideOverridesRecord` is a new model, additive; no existing record changes. The ADR must be accepted before the implementing PR opens, and a different record shape reopens this spec.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0014 (download, join, `GuideKey`, `GuideLoadingState`, `GuideError`, `GuideProgress`, `redacted(_:)`), 0013 (catalogue, `RowKey`, All channels order, initials), 0012 (folding and ranking bands reused by the picker), 0004 (sources, URL validation wording), 0006 (error style, byte and guide status strings), 0010 (Sources & Settings entry in the sidebar), 0023 (Sources and Settings, source deletion), 0015 (`shell.settingsSheet` on tvOS), 0007, 0009 and 0010 for the "No programme information" states this screen explains.
- Takes over three items 0014 lists as out: several guide URLs per source, manual channel-to-guide mapping, and the reason a channel has no guide. Supersedes 0014/AC-1 with AC-1 here. On acceptance, 0014's header gains "AC-1 superseded by 0021/AC-1; `GuideProgress`, `GuideIndex` and `GuideStore` shapes amended by 0021" and its README row says the same; 0014's implementing PR takes the shapes listed under "Required of other specs" rather than the originals.
- Blocked, like 0013 and 0005, on the 0001 follow-up that hashes `streamURL` out of `Channel.id`: a mapping is keyed by `channelID` the way `FavoriteRecord` is, so no mapping may be written to the synced store before that change merges (ADR-0003). Core criteria can be implemented and tested before it.
- Blocked on (implementing PR, not acceptance): the 0014 revision listed under "Required of other specs", merged as its own PR so the accepted 0014 is not changed by this one.
- Blocked on (implementing PR, not acceptance): a route into `guideSources.root`. Either 0023's Guide row (Required of other specs), or an interim `-antenna.uiTest` launch argument that opens `guideSources.root` for a source id and is used only by tests.

## Design

Boards: `docs/design/boards/iPad-GuideSources.dc.html` (iPadOS, macOS), `docs/design/boards/iPhone-GuideSources.dc.html` and `docs/design/boards/iPhone-GuideSources-Diagnosis.dc.html` (iOS), `docs/design/boards/TV-GuideSources.dc.html` (tvOS).
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-8, DR-11, DR-12, DR-13, DR-15. Deviations: DR-3, the status line of a failed guide and the diagnosis title for a failed guide use `#FF5F57` text, 0006's error style, because the accent reads as a link; DR-6 does not apply, the channel rows here are logo tile, name, number and a reason, with no programme and no progress bar, because every listed channel has no programme; DR-7 therefore does not apply either; DR-1 holds on tvOS, the screen is drawn over the live picture behind the settings sheet.
States on the boards:
- `iPad-GuideSources`: sidebar with Sources & Settings selected and the source list under a Sources eyebrow with "Sport Pack" selected; list column with the "Guide sources" header, three guide rows (a loaded one with "Loaded · 388 of 412 channels · 7 days" in muted 13 pt, a downloading one with an indeterminate ring and "Downloading · 12.4 MB", a failed one with "Could not download · Server returned 404" in the error style), the "Add guide URL" row with a plus glyph, the "Channels without guide · 24" header with the filter field, and channel rows (56 by 36 logo tile, name, muted number, muted 13 pt reason) with "Sport One" selected on the 0.12 surface; detail column with the diagnosis card (eyebrow "Sport One · 104", title "Guide id “sport1” is not in the guide" because one of the three guides has completed, body, the muted lines that one guide could not be downloaded and one is still downloading), the "Find a guide entry" field prefilled with "Sport One", and result rows (display name with the highlighted match, muted "id · guide name · programme count").
- `iPhone-GuideSources`: navigation bar with back "Sport Pack" and title "Guide", the same three guide rows at 15 pt name and 13 pt status, Add guide URL, the "Channels without guide · 24" header, channel rows (52 by 34 logo tile, 15 pt name, 12 pt muted number, 12 pt muted reason, chevron), tab bar with Settings selected.
- `iPhone-GuideSources-Diagnosis`: pushed screen with back "Guide", the diagnosis card, the prefilled search field, result rows at 15 pt with the 12 pt muted detail line.
- `TV-GuideSources`: 0.88 scrim over the live picture, title "Guide sources · Sport Pack" with the clock at the trailing edge, three columns: guide rows at 29 pt with 22 pt status lines and the same three states as the iPad board, channel rows at 24 pt with 20 pt reason, and the diagnosis panel with the result rows; the focused result row is the white card with muted-on-focus detail; the selected channel row sits on the 0.12 surface.
Not drawn, with their text styles:
- Empty channel list, `guideSources.empty`, "Every channel in <source> has a guide" centred in the channel column: muted 16 pt (iPad, Mac), 15 pt (iPhone), 24 pt (tvOS).
- Channel list while the source's first guide load runs, one row `guideSources.channels.loading` reading "Waiting for the guide…" in the same muted styles with an indeterminate ring.
- Add guide URL form: one field "Guide URL" with Save and Cancel, as 0006's M3U form (`TV-Onboard-3-M3U`, `iPhone-Onboard-2-M3U`); iPad and Mac show it as a popover anchored to the Add row at 390 pt wide; the error line under the field in the error style (15 pt iOS, 16 pt iPad, 22 pt tvOS).
- Guide actions on tvOS, shown in the detail column when a guide row is selected: rows "Move up", "Move down", "Turn off" or "Turn on", "Retry now", "Remove" at 29 pt on the 0.08 surface, 64 pt tall, the focused one as the white card; Remove is absent for built-in entries.
- Picker with no result, `guideSources.picker.empty`, "No guide entry matches “<query>”" at body size with the muted caption "Try a shorter name or the channel's tvg-id."; with no guide loaded, "The guide has not been downloaded yet." alone.
- Picker cap row, `guideSources.picker.cap`, "Showing 200 of <n>" in the muted caption as `iPad-Search-Capped`.
- Offline status line on a guide row, "Offline · retries when you're back online" in the muted colour, not the error style.
- A guide that is turned off: name in the muted colour and the status line "Off"; the URL line stays.
- Status lines "Waiting for login to sync from iCloud" (iOS, iPadOS, macOS), "Sign in to <source> on this Apple TV" (tvOS) and "Reading the guide…", all in the muted colour at the status size of the row (13 pt iPhone and iPad, 22 pt tvOS).
- iPad and Mac detail column when a guide row is selected: the same action list as the tvOS one ("Move up", "Move down", "Turn off" or "Turn on", "Retry now", "Remove"), 44 pt rows at 16 pt on the 0.06 surface, Remove absent for built-in entries.
- iPhone swipe actions on a guide row: Turn off (or Turn on), Retry now and Remove as system swipe actions in the 0.12 surface; Remove absent for built-in entries.
- Diagnosis cards for every AC-14 case other than `.idNotFound`: the drawn card with that case's title and body; the `.allGuidesFailed` card lists one line per guide in the error style (15 pt iPhone, 15 pt iPad, 24 pt tvOS); the `.offline` and `.waitingForLogin` cards use the muted colour for the title.
- Picker field under hardware-keyboard focus on iPad and Mac: a 2 pt inset ring in the Text colour, as `iPad-Focus.dc.html` draws for a row.
- Diagnosis card for `.ok`, same card with the title "Guide from <guide name>" and `guideSources.mapping.remove` as a 44 pt (64 pt on tvOS) text button under the body when the match came from a mapping.
- Drag handles in edit mode on iPhone and iPad; the context menu on iPad and Mac.
- Collapsed channel list of AC-15e: the diagnosis card in the channel column, under it the row `guideSources.channels.showAll` "Show <n> channels" at the row size of the column, 44 pt tall (64 pt on tvOS).
- Add guide URL on tvOS: the field and Save and Cancel rows in the detail column, 64 pt rows, the focused one as the white card; select on the field opens the system keyboard.
- Re-enter URL action of AC-22b: one more row in the guide action list, "Re-enter URL", in the action list's style; it opens the add form prefilled with the stored scheme and host.
- Status line "Waiting for this guide's login to sync from iCloud" (iOS, iPadOS, macOS) and "This guide link needs its login on this Apple TV" (tvOS), muted, at the status size of the row.
macOS uses the iPad board in a window of at least 1194 by 834; the sidebar is the 0010 Mac sidebar.
The boards in the repo are exports; the private design canvas needs the same screens.

## Problem

Provider guides are the most common support topic for IPTV players and users blame the app when the grid says "No programme information" (research note, "Diagnose, don't blame"). Antenna today downloads one guide per source and matches by exact `tvg-id`. A channel with no `tvg-id`, an id spelled differently from the guide's, or a provider guide that is missing half the channels leaves the user with no way to find out why and no way to fix it short of editing the playlist.

## Scope

In:
- `GuideSourceRef` in AntennaCore: `.sourceEPGURL` (`SourceRecord.epgURL`), `.playlistHeader(Int)` (the index into `Playlist.epgURLs`), `.provider` (Xtream `xmltvURL()`, resolved from the Keychain credential at load time and never stored), `.custom(UUID)` (user-added, keyed by an opaque `guideID`; the stored URL parts live on the `GuideEntryOverride`, AC-22a). `Codable`, `Hashable`, `Sendable`.
- `GuideOverrides` in AntennaCore: `id` (the record's UUID, the merge tie-breaker), `sourceID`, `order: [GuideEntryOverride]` (ref, `isEnabled`, `updatedAt`, and for `.custom` the stored scheme, host and port, the path when AC-22a allows it, and an optional `credentialKey`), `mappings: [ChannelGuideMapping]` (`channelID`, `epgID`, `updatedAt`), tombstones `removedMappings` (`channelID`, `updatedAt`) and `removedGuides` (`guideID`, `updatedAt`) so a merge can tell a removal from an edit the other device never saw, `updatedAt`. `Codable` so the app layer can store it in one record. `GuideOverrides.merged(_:)` for duplicate records (AC-13b to AC-13d).
- `GuideOverridesRecord` in `Apps/Shared/Persistence/`, assumed by the pending ADR: `id: UUID? = nil`, `sourceID: UUID? = nil`, `payload: Data? = nil` (the JSON of `GuideOverrides`), `updatedAt: Date? = nil`; no unique attribute, no relationship (ADR-0002). The encoded payload is capped at 500 KB (AC-29), half CloudKit's 1 MB record limit. The app layer maps the record to and from this value; AntennaCore never sees SwiftData (ADR-0005).
- `GuideResolver.entries(kind:epgURL:playlistEPGURLs:overrides:) -> [GuideEntry]` in AntennaCore, replacing 0014's `GuideURLResolver.resolve` (AC-1). A `GuideEntry` is a ref, `isEnabled`, the URL when it is known without a credential, and a display name (AC-22). A `.custom` entry can carry a `credentialKey` (AC-22a).
- Join with priority: for each key the highest-priority enabled guide that has at least one programme for its id supplies every programme; lower guides fill only keys the higher ones leave empty (AC-6).
- Per-guide parse results (`XMLTVParser.Result` per `GuideSourceRef`) are retained on the worker for the life of the process, or in the cache the 0014 storage ADR chooses; the published `GuideIndex` holds only winning programmes plus the channel names of every enabled guide. AC-3 and AC-4 re-join from the retained results and issue no request. If the storage ADR drops retained results for disabled guides, AC-4's re-enable gains a download and AC-3 is unaffected because both guides stay enabled.
- `GuideStore` (0014) gains `channelsWithoutGuide(for: UUID) -> [RowKey]`, `diagnosis(for: Channel) -> GuideDiagnosis`, `guideEntries(for: UUID) -> [GuideEntry]` with each entry's loading state, `guideChannels(for: UUID) -> [GuideChannel]` and `update(overrides: GuideOverrides)`. Writes go through an app-layer `GuideOverridesStore` (`@MainActor`) with `setMapping(epgID:for:)`, `removeMapping(for:)`, `addGuide(url:to:)`, `removeGuide(_:from:)`, `move(_:to:in:)` and `setEnabled(_:for:in:)`; each writes the record and calls `update(overrides:)`. Criteria that name these calls mean these two types.
- Per-guide loading, progress and failure, with the source's key state derived from its guides (AC-7, AC-8).
- `GuideIndex` keeps the `<channel>` display names of every guide and exposes `guideChannels(for sourceID:)` for the picker (AC-9).
- Mapping a channel to a guide id of its own source (AC-10 to AC-12). The effective id for the join is the mapping's `epgID` when one exists, else `Channel.epgID`. `GuideStore.key(for: Channel) -> GuideKey?` is the one place that applies it (AC-10b).
- `GuideDiagnosis` and `GuideStore.diagnosis(for:)`, a pure function of the index, the loading states and the overrides (AC-14).
- The Guide sources screen for one source: guide list with add, reorder, enable, remove and retry; the list of channels without a guide; the diagnosis for a selected channel; the picker; prefix `guideSources.`.
- Sync of `GuideOverrides` through the ADR-0002 container, including the duplicate-record merge.
- Offline and credential-missing behaviour for every action above.
- Lazy containers for the guide list, the channel list and the picker results on every platform.

Out (explicitly):
- Merging programmes of one channel from several guides by time (filling evening gaps from a second guide). A later guide-merging spec; here one guide wins a key outright.
- Mapping a channel to a guide entry of another source. A later spec, once the catalogue can address keys across sources.
- Fuzzy automatic matching by name when `tvg-id` is missing. A later matching spec; here the picker suggests, the user picks.
- Marking a channel "no guide, stop asking". A later spec.
- Guide URL handling in onboarding beyond 0006/AC-4a's single Guide URL field (0006).
- The Sources and Settings screen itself, source editing, and the row that opens this screen (0023). This spec defines the screen from `guideSources.root` inward.
- The route from "No programme information" in 0007, 0009 and 0010 into this screen (revisions of those specs; AC-24 defines what the screen does when opened with a channel).
- Where programmes persist and how a cache survives relaunch (0014's storage ADR).
- Refresh interval and schedule (0014/AC-13 applies per guide unchanged).
- Picking the language of a guide with several `<display-name>` elements (0002 open question).
- Sweeping overrides records orphaned for a long time, and their Keychain items. A later housekeeping spec; it needs a local first-seen date and a completed CloudKit import before it may delete.
- Splitting this spec into a multi-guide spec and a mapping and diagnosis spec. The reviewer asked for it; kept as one because the diagnosis needs the per-guide states and the picker needs the multi-guide channel list. Listed under Open questions.

Required of other specs:
- 0014: the changes below land as a 0014 revision PR before this spec's implementing PR. AC-1 is superseded by AC-1 here. `GuideKey` for a `Channel` comes from `GuideStore.key(for: Channel) -> GuideKey?`, which applies the mapping; the sentence "a channel with `epgID` nil has no key" gains "and no mapping", and `loadingState(for:)`, `current(for:)` and `programmes(for:in:)` taking a channel go through `key(for:)`. `GuideStore.refresh(source:)` becomes `refresh(source:guide:)` with `guide: nil` meaning every enabled guide. `GuideProgress.downloading` and `.failed` gain `guide: GuideSourceRef`; `.loaded` stays per source and is emitted once per join. `GuideIndex` is built from `[(GuideSourceRef, XMLTVParser.Result)]` per source plus `GuideOverrides`, keeps `channelNames`, and gains `guide(for: GuideKey) -> GuideSourceRef?` and `guideChannels(for: UUID) -> [GuideChannel]`. `update(channels:)` and a new `update(overrides:)` both re-run the join. `remove(sourceID:)` also drops the source's overrides from the index. The one-at-a-time rule applies per guide download; the join still runs once per source after every guide of that source has finished or failed, and once more per `update`. The per-device timestamp of 0014/AC-13 and any cache file of 0014/AC-15 are keyed by `sourceID` plus a stable hash of the `GuideSourceRef`'s `Codable` form, never by the URL text.
- 0001 follow-up (the one this spec is blocked on): a channel without `tvg-id` gets an id derived from its name and a hash of its stream URL, not from its position, or mappings for such channels are lost on every playlist reorder; until then AC-12 is tested with `tvg-id` channels only.
- 0006/AC-12a to AC-12c: the guide row aggregates the source's enabled guides. Bytes are summed across guides in progress; "Guide could not be loaded" appears only when every enabled guide failed; the loaded text uses the AC-8 `.loaded` counts.
- 0007, 0009 and 0010: every lookup of a channel's guide goes through `GuideStore.key(for:)` (AC-10b), so a mapped channel shows its programmes in the overlay, the grid and browse.
- 0007/AC-7, 0009/AC-12, 0010/AC-9: the "No programme information" and "Guide unavailable" placeholders gain an action that opens `guideSources.root` for that channel's source with the channel selected (AC-24). Names (`overlay.guideInfo`, `guide.guideInfo`, `browse.guideInfo`) are those specs' to fix.
- 0023: a "Guide" row per source in `settings.detail`, with the AC-15 count as its detail, opens `guideSources.root`; on tvOS from inside `shell.settingsSheet` (0015/AC-12). 0023/AC-4's "No guide" reads `GuideStore.guideEntries(for:)` being empty instead of `GuideURLResolver.resolve`. 0023's source deletion (AC-20c) deletes the source's `GuideOverridesRecord` and its AC-22a Keychain items in the same save (AC-27). 0023's out-of-scope line for multiple guide URLs and mapping points to 0021.
- 0004/AC-6 and the sync path of 0014/AC-18a: deleting a `SourceRecord` deletes its `GuideOverridesRecord` (AC-27).

## User flow

iPadOS and macOS, regular width:
1. The user opens Sources & Settings in the sidebar, selects a source, then its Guide row. The list column shows the source's guides with their status, Add guide URL, and the channels that have no guide with a count. The detail column is empty until a row is selected.
2. Selecting a guide row shows its actions in the detail column; a context menu on the row offers the same. Dragging reorders. Add guide URL opens a popover with one field; Save validates, stores the URL and starts its download; the new row shows "Downloading".
3. Selecting a channel row shows its diagnosis in the detail column: why it has no guide and, when a guide is loaded, the search field prefilled with the channel name over the matching guide entries.
4. Selecting a result saves the mapping. The card changes to "Guide from <guide>", the channel leaves the list, and the count drops by one. Remove mapping on the card reverses it.

iOS and compact width:
1. Settings tab, source, Guide. One scrolling screen: guides, Add guide URL, channels without guide.
2. Swipe actions and a context menu on a guide row offer Turn off, Retry now and Remove; Edit enables drag reorder. Add guide URL presents a sheet.
3. Tapping a channel row pushes the diagnosis screen with the card, the search field and the results. Tapping a result saves the mapping and pops back to the list.

tvOS:
1. From the settings sheet (0015/AC-12) the user selects a source, then Guide. The screen slides over the dimmed picture, which keeps playing. Focus starts on the first guide row.
2. Moving right from a guide row reaches the channel list; moving down inside the guide list past the last row reaches Add guide URL. Select on a guide row shows its actions in the detail column and moves focus there; Menu returns focus to the row. Select on Add guide URL shows the field, Save and Cancel in the detail column (AC-2c).
3. Select on a channel row shows its diagnosis and moves focus to the search field, prefilled with the channel name; select on the field opens the system keyboard. Moving down from the field reaches the results. Select on a result saves the mapping and returns focus to the channel list, where the next row is focused because the mapped one left.
4. Menu from the channel list or the guide list closes the screen back to the settings sheet.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Guide entries per source
Given each source row below, with `overrides` nil
When `GuideResolver.entries(kind:epgURL:playlistEPGURLs:overrides:)` runs
Then it returns the entries in that row, in that order, all enabled unless the row says otherwise, an entry whose URL equals an earlier entry's URL after trimming whitespace is dropped (the first wins), and no request is issued during resolution; `.provider` has no URL, the app layer builds `XtreamClient.xmltvURL()` from the credential at load time.

| Source | Entries |
|--------|---------|
| M3U, `epgURL` set, header URLs [u1, u2] | `.sourceEPGURL`, `.playlistHeader(0)`, `.playlistHeader(1)` |
| M3U, `epgURL` nil, header URLs [u1] | `.playlistHeader(0)` |
| M3U, `epgURL` nil, no header URLs | none; the source's keys report `.unavailable` (0014/AC-11) |
| Xtream, `epgURL` nil | `.provider` |
| Xtream, `epgURL` set | `.sourceEPGURL`, `.provider` with `isEnabled` false |
| M3U, `epgURL` u1, header URLs [u1, u2] | `.sourceEPGURL`, `.playlistHeader(1)` |
| Stalker, `epgURL` set | `.sourceEPGURL` |
| Stalker, `epgURL` nil | none |

### AC-1a Stored order wins
Given the Xtream row with `epgURL` set and `overrides.order` [`.custom(c1)` enabled, `.provider` enabled, `.sourceEPGURL` disabled]
When entries are resolved
Then the result is `.custom(c1)`, `.provider`, `.sourceEPGURL` with the stored flags; a stored ref whose target no longer exists (`.sourceEPGURL` when `epgURL` is nil, `.playlistHeader(3)` when the playlist has two header URLs) is dropped; a ref the playlist introduced since the order was stored is inserted immediately after the last stored ref of the same kind, or at the end of the order when the kind has none, enabled.

### AC-2 Add a guide URL
Given the Guide sources screen for source S with two guides and an online network
When the user enters `https://epg.example.com/guide.xml.gz` in `guideSources.add.field` and activates `guideSources.add.save`
Then `GuideOverrides.order` for S gains one `.custom(guideID)` entry, enabled, at the end, the record is written, `refresh(source: S, guide: .custom(guideID))` starts within one second, and no other guide is downloaded.

### AC-2a Invalid guide URL
Given the add form
When the user saves text without an `http` or `https` scheme, or empty text
Then `guideSources.add.error` reads "Enter a valid URL." (0004/AC-1 wording), the form stays open, nothing is written and no request is issued.

### AC-2b Duplicate guide URL
Given a source whose entries already resolve to a URL equal to the entered one after trimming whitespace, compared on the full URL including userinfo and query (a header URL, `epgURL`, or a custom one rebuilt with its Keychain parts; a custom one whose Keychain item is absent on this device is never reported as a duplicate)
When the user saves it
Then `guideSources.add.error` reads "This guide is already in the list." and nothing is written.

### AC-2d Row and form after adding
Given AC-2 has saved a URL
When the screen updates
Then `guideSources.guide.2` exists with its status per AC-23 and the add form is gone.

### AC-2c Add a guide URL on tvOS
Given focus on `guideSources.add` on tvOS
When the user presses select, then select on `guideSources.add.field`, types the URL on the system keyboard and dismisses it, then selects `guideSources.add.save`
Then select on `guideSources.add` shows `guideSources.add.field`, `guideSources.add.save` and `guideSources.add.cancel` in the detail column with focus on the field; select on the field opens the system keyboard; select on Save runs AC-2 and returns focus to the new guide row; Menu or `guideSources.add.cancel` closes the form with nothing written and returns focus to `guideSources.add`.

### AC-3 Reorder changes priority without a download
Given guides G1 and G2 loaded for S, both carrying programmes for id "b", G1 first
When the user moves G2 above G1 (drag, context menu "Move up", or the tvOS action)
Then `GuideOverrides.order` is written with G2 first, `update(overrides:)` re-runs the join, `guide(for: GuideKey(S, "b"))` is G2 and its programmes are the ones queryable within five seconds, and no request is issued.

### AC-4 Turn a guide off and on
Given G1 and G2 loaded for S
When the user turns G2 off
Then `isEnabled` is false in the written record, G2's programmes and channel names leave the index within five seconds, keys only G2 covered report `.noData`, and `refreshIfStale(now:)` never downloads G2.

### AC-4a Turn a guide on with its parse result retained
Given G2 turned off per AC-4 and the fixture retains G2's parse result on the worker
When the user turns G2 on
Then `isEnabled` is true in the written record, the join re-runs from the retained result, G2's keys are queryable within five seconds, and no request is issued.

### AC-4b Turn a guide on without a retained result
Given G2 turned off per AC-4 and the fixture holds no parse result for G2
When the user turns G2 on
Then `isEnabled` is true in the written record and `refresh(source: S, guide: G2)` starts within one second.

### AC-5 Remove a custom guide
Given `.custom(c1)` in S's order
When the user removes it
Then the ref leaves `order`, a `removedGuides` tombstone with the current time is written, its programmes leave the index within five seconds, any cached file for it is deleted, its Keychain item of AC-22a is deleted, and `guideSources.guide.<i>.remove` does not exist for `.sourceEPGURL`, `.playlistHeader` or `.provider` rows; those can only be turned off.

### AC-6 Join with priority
Given enabled guides G1 (first) with programmes for ids "a" and "b", G2 with programmes for "b" and "c", G3 with a `<channel id="d">` element but no programme for "d", and G1 also listing `<channel id="c">` with no programme
When `GuideIndex` is built for channels with ids a, b, c, d
Then key a has G1's programmes, key b has G1's programmes and none of G2's, key c has G2's programmes because a guide that lists an id without programmes does not win it, key d has none and reports `.noData`; `guide(for:)` returns G1, G1, G2 and nil; G2's programmes for "b" are not counted as `unmatched` in AC-8; overlap resolution (0014/AC-6) runs within the winning guide only; disabled guides take no part.

### AC-7 Key state from several guides
Given a source with enabled guides G1 and G2 on a device that has never completed a load of either
When `loadingState(for:)` is read for its keys during the states below
Then it is the key state of the row, one parameterised test per row; a `.credentialMissing` guide counts as neither failed nor completed, `.failed` carries the error of the first failed guide in priority order, and 0014/AC-11a stickiness holds once any guide has completed on this device.

| G1 (first) | G2 | Key state |
|------------|----|-----------|
| pending | in progress | `.loading` |
| completed | failed `.httpStatus(500)` | `.loaded` or `.noData` per key |
| failed `.network` | completed | `.loaded` or `.noData` per key |
| failed `.httpStatus(500)` | failed `.network` | `.failed(.httpStatus(500))` |
| `.credentialMissing` | failed `.httpStatus(500)` | `.failed(.httpStatus(500))` |
| `.credentialMissing` | pending | `.loading` |
| `.credentialMissing` | `.credentialMissing` | `.unavailable` (0014/AC-1a) |
| disabled | disabled | `.unavailable` |
| M3U source, header URLs not registered yet, no `epgURL` | no G2 | `.loading` (0014/AC-11) |

### AC-8 Progress per guide
Given a source with two enabled guides
When both load
Then `progressStream()` emits `.downloading(sourceID:, guide:, bytesReceived:, expectedBytes:)` per guide under 0014/AC-9's cadence, `.failed(sourceID:, guide:, error)` per failing guide, and one `.loaded(sourceID:, channelsWithGuide:, channelsTotal:, days:, unmatched:)` per join after the last enabled guide of the source has finished or failed, with the counts of 0014/AC-10 computed over the merged index; `unmatched` is the number of programmes in enabled guides whose id is no channel's effective id in S.

### AC-9 Guide channel list
Given loaded guides G1 with `<channel id="x"><display-name>Sport One HD</display-name></channel>`, two programmes for "x" and one for "y" (no `<channel>` element for "y"), and G2 with `<channel id="x"><display-name>Sport 1</display-name></channel>` and no programmes
When `guideChannels(for: S)` is read
Then it lists one `GuideChannel` per (guide, id) pair in guide priority order, and within a guide the ids with a `<channel>` element in document order followed by ids found only in programmes in order of their first programme: ("x", "Sport One HD", G1, 2), ("y", "y", G1, 1) using the id as display name when the guide has no `<channel>` for it, ("x", "Sport 1", G2, 0); the count is the number of programmes for that id in that guide at any time, computed during the join from the parse results, so it holds when the guide lost the key under AC-6 and when retained results are dropped; disabled guides contribute nothing.

### AC-10 Mapping overrides the playlist id
Given channel C of S with `epgID` "sport1" and a loaded guide with programmes for "sport1.se" and none for "sport1"
When `setMapping(epgID: "sport1.se", for: C)` runs
Then `GuideOverrides.mappings` for S holds (`C.id`, "sport1.se", now) and is written, `update(overrides:)` re-runs the join, C's key is `GuideKey(S, "sport1.se")`, `current(for:)` and `programmes(for:in:)` for C return the "sport1.se" programmes, and `Channel.epgID` is unchanged.

### AC-10b Mapped channel without tvg-id
Given channel C of S with `epgID` nil, mapped to "x", and a loaded guide with programmes for "x"
When `key(for: C)`, `loadingState(for: C)` and `current(for: C)` are read
Then `key(for: C)` is `GuideKey(S, "x")`, `loadingState(for: C)` is that key's state (not the source-level state 0014 gives a channel with no key), and `current(for: C)` returns the "x" programme; with the mapping removed `key(for: C)` is nil.

### AC-10a Mapping to an id with no programmes
Given C mapped to "ghost", an id no loaded guide of S has programmes for
When the join runs
Then C's key is `GuideKey(S, "ghost")`, it reports `.noData`, and `diagnosis(for: C)` is `.mappedToMissing("ghost")`.

### AC-11 Remove a mapping
Given C mapped per AC-10
When `removeMapping(for: C)` runs
Then the entry leaves `mappings`, a `removedMappings` tombstone for C with the current time is added, the record is written, the join re-runs and C's key is `GuideKey(S, "sport1")` again with its original state.

### AC-12 Mapping identity
Given mappings for channels C1 (`id` "k1") and C2 (`id` "k2") of S, and a playlist refresh that keeps "k1", renames the channel, and drops "k2"
When `update(channels:)` runs with the new list
Then C1's mapping still applies by `id` regardless of name or number, C2's mapping stays in `mappings` untouched, applies to no channel and is not counted in AC-15; a mapping is matched on (`sourceID`, `channelID`) only.

### AC-13a Overrides change observed
Given an in-memory container with S's `GuideOverridesRecord` and a loaded guide
When a changed record with a new mapping is saved through a second context, as a sync import would
Then the app layer observes the change, calls `update(overrides:)`, the mapped programmes are queryable within five seconds, and no request is issued.

### AC-13e Overrides sync between devices
Given a mapping saved on device A
When device B, signed into the same iCloud account, receives the record
Then the mapped channel shows its programmes on B within five seconds of the record arriving.

### AC-13b Duplicate records merge: mappings
Given two `GuideOverrides` values for the same `sourceID` (a sync race per ADR-0002) where R1 (`updatedAt` 10:00) maps C to "a" (10:00), E to "e" (09:00) and F to "f" (09:30), and R2 (`updatedAt` 10:05) maps C to "b" (10:05) and D to "c" (10:05) and holds a `removedMappings` tombstone for F at 10:03
When `GuideOverrides.merged([R1, R2])` runs
Then the result maps C to "b", D to "c" and E to "e", has no mapping for F and keeps F's tombstone: per `channelID` the entry with the later `updatedAt` wins, mapping or tombstone, and a mapping present in one record only is kept unless the other holds a later tombstone for it.

### AC-13c Duplicate records merge: order and flags
Given R1 (`updatedAt` 10:00) orders [G1, G2, `.custom(k)` added 09:58] and R2 (`updatedAt` 10:05) orders [G2, G1] with G1 disabled, first with no tombstone for k in R2, then with a `removedGuides` tombstone for k at 10:01 in R2
When `merged([R1, R2])` runs
Then the first case gives [G2, G1 disabled, `.custom(k)` enabled] and the second [G2, G1 disabled]: the result is the later record's list followed by the refs present only in the earlier record that no later tombstone removes, in the earlier record's relative order; equal `updatedAt` values are decided for the record with the larger `id`.

### AC-13d Duplicate records merge: write-back
Given two `GuideOverridesRecord`s for S in the container
When the app layer observes them
Then it writes one record holding `merged([R1, R2])` with `updatedAt` equal to the later of the two, deletes the other, and calls `update(overrides:)` once.

### AC-14 Diagnosis
Given the conditions in the table, for a channel C of source S
When `diagnosis(for: C)` runs
Then it returns the case of the first row whose condition holds, in table order; one parameterised core test per row, including the mixed condition of `.waitingForLogin`; once any enabled guide has completed, `.notDownloaded` no longer applies and a guide still downloading is reported by AC-14c's suffix line.

| Case | Condition | Row label | Title | Body |
|------|-----------|-----------|-------|------|
| `.sourceLoading` | an M3U source whose playlist has not delivered `register(epgURLs:for:)` yet | "Loading" | "Waiting for the playlist" | "Antenna reads the guide links from the playlist when it finishes loading." |
| `.noGuideURL` | no enabled entry | "No guide" | "This source has no guide" | "Add a guide URL to get programme information for <source>." |
| `.waitingForLogin` | no enabled guide has completed, at least one failed with `.credentialMissing` (0014/AC-1a, AC-22b), and every other enabled guide failed with any error | "Waiting for login" | "Waiting for the login to sync" (muted) | "The provider guide needs this source's login, which has not reached this device from iCloud yet." On tvOS the title is "Sign in on this Apple TV" and the body "The provider guide needs this source's login. Sign in from Sources & Settings." |
| `.notDownloaded` | no enabled guide has completed a load and at least one is pending or in progress | "Not downloaded yet" | "The guide has not been downloaded yet" | "Downloading the guide · <bytes per 0006/AC-12a>" while a download is in progress, else "Antenna downloads the guide when the source finishes loading." |
| `.offline` | every enabled guide failed with `.offline` and none has completed | "Offline" | "You're offline" (muted) | "The guide downloads when you're back online." |
| `.allGuidesFailed([(GuideSourceRef, GuideError)])` | every enabled guide failed and none has completed | "Guide failed" | "The guide could not be downloaded" (error style) | one line per guide, "<guide> · <status text per AC-23>" |
| `.mappedToMissing(epgID)` | a mapping exists and no enabled guide has any programme for its id, past or future (a mapped id with only past programmes is `.noUpcoming`) | "Mapping not found" | "The mapped entry “<id>” has no programmes" | "Pick another entry below, or remove the mapping to go back to the playlist's id." |
| `.noEPGID` | no mapping and `Channel.epgID` nil or blank after trimming | "No guide id" | "The source gives this channel no guide id" | "The playlist has no tvg-id for <channel>, so nothing can be matched automatically. Pick an entry below." For an Xtream source "The provider sends no epg_channel_id for <channel>" replaces the first clause. |
| `.idNotFound(epgID)` | the effective id is in no completed guide's channel list and has no programmes | "Id not found" | "Guide id “<id>” is not in the guide" when one guide has completed, "… in any of the <c> guides" when c > 1 | "“<Guide>” does not list “<id>”.", or "None of the <c> guides for <source> lists “<id>”.", followed by "Pick an entry below." |
| `.noProgrammes(epgID, GuideSourceRef)` | a loaded guide lists the id in `<channel>` and no guide has a programme for it | "No programmes" | "The guide lists “<id>” but has no programmes for it" | "<Guide> knows the channel but carries no programmes for it. Pick another entry below, or wait for the provider to fill it." |
| `.noUpcoming(epgID, GuideSourceRef)` | the key has programmes but none with `stop > now` | "Guide ended" | "The guide for “<id>” has run out" | "<Guide> lists programmes for this channel but none after now. Wait for the next guide refresh or pick another entry below." |
| `.ok(epgID, GuideSourceRef, mapped: Bool)` | the key has at least one programme with `stop > now` | not listed | "Guide from <guide>" | "“<display name>” (<id>) · <days> days · Mapped by you" or "· Matched by tvg-id", where days follows 0014/AC-10 for this key alone |

### AC-14a Diagnosis texts
Given each case of the AC-14 table on iPhone, iPad, Mac and tvOS, for an M3U and an Xtream source
When the diagnosis card is shown
Then `guideSources.diagnosis.title` and `guideSources.diagnosis.body` read the Title and Body columns, with the tvOS variant of `.waitingForLogin` on tvOS and the Xtream variant of `.noEPGID` for an Xtream source; "<guide>" is the entry's display name (AC-22) and "<c>" the number of enabled guides that have completed a load on this device.

### AC-14b Row label
Given a channel listed in `guideSources.channels`
When the row is rendered
Then `guideSources.channel.<rowKey>.reason` reads the Row label column of its AC-14 case.

### AC-14c Suffix lines
Given a case other than `.allGuidesFailed`, `.offline` and `.waitingForLogin`, with t enabled guides
When the body is rendered
Then it ends with "<k> of <t> guides could not be downloaded." when k > 0 enabled guides last failed with an error other than `.offline` or `.credentialMissing`, then with "1 guide is still downloading." or "<j> guides are still downloading." when j > 0 enabled guides are pending or in progress; with k and j both 0 there is no suffix line.

### AC-15 Channels without guide
Given source S with 412 channels of which 388 have a key with at least one programme with `stop > now`, and 0013's All channels order
When `channelsWithoutGuide(for: S)` is read and the list is rendered
Then it holds the other 24 channels in All channels order, `guideSources.channels.header` reads "Channels without guide · 24", and each `guideSources.channel.<rowKey>` shows the logo tile or initials (0013/AC-7), name, number and the AC-14 row label in `guideSources.channel.<rowKey>.reason`; with no filter active and the rows shown, the header count equals the number of rows; a channel whose last programme's `stop` passes joins the list within five seconds (0007/AC-21 timing).

### AC-15a Every channel has a guide
Given `channelsWithoutGuide(for: S)` is empty, S has contributed channels and at least one guide has completed
When the screen is shown
Then `guideSources.empty` reads "Every channel in <source> has a guide", the header reads "Channels without guide · 0", and `guideSources.filter` is hidden.

### AC-15b Filter
Given the AC-15 list on iPad, Mac or iPhone
When the user types in `guideSources.filter`
Then the rows narrow by 0012/AC-2 over name and by 0012/AC-3 over number on each keystroke with no debounce, the header count keeps the unfiltered total, and clearing the field restores every row; tvOS has no filter.

### AC-15c Waiting for the guide
Given every enabled guide of S is pending or in progress and none has completed
When the screen is shown
Then the channel list is replaced by one row `guideSources.channels.loading` reading "Waiting for the guide…" with an indeterminate ring, the header reads "Channels without guide" with no count, and `guideSources.filter` is hidden.

### AC-15d No channels loaded
Given S has contributed no channels (not yet loaded, failed, waiting for its login, or Stalker)
When the screen is shown
Then `guideSources.channels.header` reads "Channels without guide" with no count, `guideSources.channels.unavailable` reads "Channels have not loaded for <source>" in the muted colour at `guideSources.empty`'s sizes, `guideSources.filter` is hidden, and the guide rows and Add guide URL still work.

### AC-15e Same reason for every channel
Given S with 20,000 channels (en-US locale; counts use the locale's grouping separator as 0023/AC-3) and a source-wide diagnosis (`.sourceLoading`, `.noGuideURL`, `.waitingForLogin`, `.offline` or `.allGuidesFailed`)
When the screen is shown
Then the channel column shows the diagnosis card for that case and `guideSources.channels.showAll` reading "Show 20,000 channels" instead of the rows, the header reads "Channels without guide · 20,000", and activating `guideSources.channels.showAll` shows the AC-15 rows.

### AC-15f Channel column precedence
Given S in any combination of the AC-15 to AC-15e conditions, including an M3U source with channels whose header URLs are not registered yet
When the screen is shown
Then the channel column shows the first that holds, in this order: AC-15d (no channels), AC-15e (source-wide diagnosis, which covers `.sourceLoading`), AC-15c (every enabled guide pending or in progress, with at least one enabled guide), AC-15a (empty list), AC-15.

### AC-16 Picker query
Given guide channels "Sport One HD" (id "sport1.se"), "Sport One" (id "sportone"), "Eurosport One" (id "eurosport1"), "One Sport" (id "one.sport") and "News One" (id "nyheter.se") for S, and channel C named "Sport One"
When the diagnosis for C is shown
Then `guideSources.picker.field` holds C's name, "Sport One", and the results are evaluated on each keystroke with no debounce under 0012/AC-2's folding and token rules over display name and id, ranked by band: (1) folded display name equals the folded query, (2) display name starts with the full query, (3) a word of the display name starts with the first token, (4) display name contains the full query, (5) every token is found in the display name, (6) every token is found in the display name or the id with at least one found only in the id; alphabetical by display name within a band, then guide priority; the order here is "Sport One" (band 1), "Sport One HD" (band 2), "Eurosport One" (band 4), "One Sport" (band 5); "News One" is absent because "sport" is in neither its name nor its id; the picker shows one row per distinct id across S's enabled guides, using the display name and count of the highest-priority guide that has programmes for that id, or of the first guide listing it when none has.

### AC-16d Result row
Given the AC-16 results
When a row is rendered
Then `guideSources.picker.result.<index>` shows the display name with the matched text highlighted (0012/AC-5 style), or the id highlighted in the detail line for a token found only in the id; the detail line reads "<id> · <guide> · <n> programmes", "1 programme" for one and "no programmes" for none, where <guide> is the guide that would win the key under AC-6.

### AC-16e Empty field
Given the diagnosis for C with the field cleared
When rendered
Then no result row, no `guideSources.picker.empty` and no `guideSources.picker.cap` exist.

### AC-16c Picker on tvOS
Given the diagnosis for C on tvOS
When the user selects `guideSources.picker.field`, edits the text and dismisses the keyboard
Then select opens the system keyboard prefilled with the field's text, and on dismissal focus is on `guideSources.picker.field` with the AC-16 results for the final text; narrowing while the keyboard is open is not required on tvOS.

### AC-16a Picker cap
Given more than 200 results
When rendered
Then 200 rows are shown followed by `guideSources.picker.cap` reading "Showing 200 of <n>"; typing more narrows the set.

### AC-16b Picker with nothing to pick
Given a query that matches no guide channel, or no completed guide for S
When rendered
Then `guideSources.picker.empty` reads "No guide entry matches “<query>”" with the caption "Try a shorter name or the channel's tvg-id.", or "The guide has not been downloaded yet." with no caption when no guide of S has completed, and no result row exists.

### AC-17 Pick an entry
Given the diagnosis for C showing results
When the user selects `guideSources.picker.result.1` ("Sport One HD")
Then AC-10 runs with "sport1.se", C leaves `guideSources.channels` (on iPhone, seen after the pop of AC-17b), the header count drops by one, and `GuideStore.current(for: C)` returns a "sport1.se" programme within five seconds.

### AC-17b Card after picking
Given AC-17 has run on iPad, Mac or tvOS
When the card updates
Then `guideSources.diagnosis.title` reads "Guide from <guide>" where <guide> is the guide that won the key under AC-6, the body ends "· Mapped by you", and `guideSources.mapping.remove` exists; on iPhone the diagnosis screen pops to the list instead.

### AC-17a Remove from the card
Given the AC-17 card
When the user activates `guideSources.mapping.remove`
Then AC-11 runs, the card shows C's new diagnosis and C returns to the list unless its playlist id now matches.

### AC-18a Focus in the guide column (tvOS)
Given the screen open with focus on `guideSources.guide.0`
When the user moves down past the last guide row, or right from any guide row
Then down reaches `guideSources.add` after the last row and stops there; right lands on the first channel row, or on `guideSources.channels.loading`, `guideSources.empty` or `guideSources.channels.unavailable` when that is what the column shows; every focused element is the white card (DR-2) and every focusable row is at least 64 pt tall (DR-5).

### AC-18b Guide actions (tvOS)
Given focus on a guide row
When the user presses select
Then the detail column shows that guide's actions with focus on the first; select on an action applies AC-3, AC-4, AC-5, AC-22b's re-entry or AC-23's retry; after Move up, Move down, Turn off, Turn on or Retry now focus stays on the same action row (whose label may change), after Remove focus moves to the guide row now at that position, or to `guideSources.add` when none is; Menu returns focus to the guide row and leaves the detail column as it was.

### AC-18c Channel column and picker (tvOS)
Given focus on a channel row
When the user presses select
Then the row's diagnosis is shown and focus moves to `guideSources.picker.field` when at least one guide of S has completed; otherwise focus stays on the row.

### AC-18e Down to the results (tvOS)
Given focus on `guideSources.picker.field` with results
When the user moves down
Then focus is on `guideSources.picker.result.0`.

### AC-18f Select a result (tvOS)
Given focus on a result for the channel row at position r
When the user presses select
Then AC-17 runs and focus moves to the channel row now at position r, to the new last row when r was last, or to `guideSources.empty` when no row remains.

### AC-18g Menu from the picker (tvOS)
Given focus on `guideSources.picker.field` or a result
When the user presses Menu
Then focus returns to the channel row and the mapping is unchanged.

### AC-18d Menu closes the screen (tvOS)
Given focus on a guide row, `guideSources.add` or a channel row
When the user presses Menu
Then `guideSources.root` is gone, `shell.settingsSheet` (0015/AC-12) is shown, focus is on the row in the settings sheet that opened the screen, and the engine state is unchanged (DR-1).

### AC-19 Huge guides
Given two guides of 100 000 programmes and 5 000 channel names each for one source of 20 000 channels, 3 000 of them mapped
When the join, `guideChannels`, `channelsWithoutGuide`, `diagnosis` and a picker query run
Then the join with priority finishes within 0014/AC-16's 2 s on the worker, `guideChannels` is built in that pass, `channelsWithoutGuide` returns within 100 ms, `diagnosis(for:)` within 1 ms per channel, a picker query over the 10 000 guide channels within 50 ms, all in a debug `swift test` run on the reference machine named in the test (same baseline as 0013/AC-14; benchmark, not CI-gated); each guide is downloaded and parsed one at a time under 0014/AC-20's limits; the published index holds only the programmes that won a key, the retained per-guide parse results (Scope) hold both guides, and resident memory on device with both retained plus the index stays within 0014's budget (150 MB on tvOS), measured on an Apple TV 4K before the implementing PR; if it does not, the ADR drops retained results and AC-3 and AC-4 gain a download.

### AC-20 Offline
Given no network
When the user adds a guide URL, reorders, turns a guide off or maps a channel
Then every write to `GuideOverrides` succeeds locally; the added guide's load fails with `.offline` (0014/AC-12), its status line reads "Offline · retries when you're back online" in the muted colour, retry follows 0014/AC-13 on the next launch or `.active`; the picker works against whatever guide this device holds (0014/AC-11a) and shows AC-16b's not-downloaded text when it holds none.

### AC-21 Credential not yet synced
Given an Xtream source whose Keychain item is absent on this device, with `.provider` and `.custom(c1)` (no `credentialKey`) enabled
When the screen is shown
Then the `.provider` row's status reads "Waiting for login to sync from iCloud" on iOS, iPadOS and macOS and "Sign in to <source> on this Apple TV" on tvOS (0006/AC-21; Keychain items do not sync there), in the muted colour; no request is issued for it (0014/AC-1a); c1 downloads and joins normally; the channel column shows AC-15d because the source has no channels (0004/AC-10); when the credential becomes readable (fake credential store flips) the provider guide starts loading at the next scene activation or the next time the screen appears, whichever comes first, without user action (0010/AC-18); there is no polling.

### AC-22 Guide names and redaction
Given entries of every kind, including a custom guide the user typed as `https://u:p@epg.example.com/x.xml?token=abc`, and the injected logger of 0014/AC-15
When the guide list is rendered
Then `guideSources.guide.<i>.name` reads "Provider guide" for `.provider`, "From the playlist" for `.playlistHeader`, "Guide URL" for `.sourceEPGURL`, the URL's host for `.custom`, and for every entry with a URL the second line is `redacted(url)` (0014/AC-15: no userinfo, query values as "…"), and for a `.custom` entry with a `credentialKey` the host followed by "/…", here "epg.example.com/…", on every device; the userinfo and the query values appear in no element's label, value or identifier and in no line the injected logger records.

### AC-22a Custom URL parts split
Given the user adds `https://u:p@epg.example.com/feeds/x.xml?token=abc&lang=en`, and separately `https://epg.example.com/guide.xml.gz`
When AC-2 saves each
Then for the first the `GuideEntryOverride` holds scheme `https`, host `epg.example.com`, no port, no path and a `credentialKey`, the userinfo, the whole path and the whole query are written to the Keychain under service `se.codecrave.antenna.sources` with account `<sourceID>.<credentialKey>` (ADR-0003), and the encoded `GuideOverrides` contains none of "u:p", "feeds", "x.xml", "abc" and "lang"; the load rebuilds the full URL before the request; the second, which has no userinfo, no query and a path of one segment ending in `.xml`, `.xml.gz` or `.gz`, is stored whole with no `credentialKey` and no Keychain item.

### AC-22b Custom guide whose login is missing
Given a `.custom` entry with a `credentialKey` whose Keychain item is absent on this device (iCloud Keychain has not delivered it, or tvOS, where logins never sync per 0023's footer text)
When the screen is shown
Then the load fails with `.credentialMissing` and no request is issued; `guideSources.guide.<i>.status` reads "Waiting for this guide's login to sync from iCloud" on iOS, iPadOS and macOS and "This guide link needs its login on this Apple TV" on tvOS, muted; `guideSources.guide.<i>.reenter` opens the add form prefilled with the stored scheme and host, and saving it writes a new Keychain item under the same `credentialKey`, keeps the `guideID` and position, and starts `refresh(source: S, guide: .custom(guideID))`.

### AC-23 Guide status line and retry
Given a guide whose last load ended in each `GuideError` case, one that is loading, and one that completed
When `guideSources.guide.<i>.status` is rendered
Then it reads "Loaded · <channelsWithGuide> of <channelsTotal> channels · <days> days" for a completed guide, where `channelsWithGuide` is the number of S's channels whose effective id (mapping or `epgID`) has at least one programme with `stop > now` in this guide alone, `channelsTotal` is 0014/AC-10's and `days` is 0014/AC-10's over this guide's programmes; "Downloading" until the first `.downloading` event, then "Downloading · <bytes>" with an indeterminate ring during 0014/AC-9 and "Reading the guide…" after the last byte (0006/AC-12a); "Could not download · <text>" in the error style for a failure, with text "Server returned <n>" for `.httpStatus(n)`, "Timed out", "Network error" for `.network`, "Not a guide file" for `.malformed` and `.unsupportedEncoding`, "No programmes in the guide" for `.empty`, "Too large" for `.tooLarge`, "Login rejected" for `.unauthorized`, "Could not read login" for `.credentialUnreadable`; `.offline` uses AC-20's muted text and `.credentialMissing` AC-21's for `.provider` and AC-22b's for `.custom`; `guideSources.guide.<i>.retry` exists for failed and offline rows and runs `refresh(source:guide:)` for that guide only.

### AC-24 Opened with a channel
Given another screen opens `guideSources.root` for source S with channel C
When the screen appears
Then `guideSources.channel.<C.rowKey>` is selected and visible, its diagnosis is shown, and on tvOS focus is on `guideSources.picker.field` when a guide has completed and on the channel row otherwise; when C is not in `channelsWithoutGuide` (its guide arrived meanwhile) the `.ok` card is shown and no row is selected.

### AC-25 Nothing written until the user acts
Given a source with no `GuideOverridesRecord`
When the screen is opened, browsed and closed
Then no record is inserted; the first add, reorder, toggle, removal or mapping inserts exactly one record for S.

### AC-26 Malformed custom guide
Given a custom guide URL that returns an HTML page, a corrupt gzip body, or random bytes
When it loads
Then 0014/AC-12 and AC-17 classify it (`.empty`, `.malformed`, `.unsupportedEncoding`), AC-23 shows the text, the source's other guides are unaffected and AC-7 derives the key state from them.

### AC-27 Source deleted
Given source S with a `GuideOverridesRecord`
When the `SourceRecord` is deleted on this device, or disappears from the synced container
Then for a local deletion the overrides record for S is deleted in the same save as the `SourceRecord` and its Keychain items of AC-22a are deleted with it; when the `SourceRecord` disappears from the synced container, `remove(sourceID:)` runs (0014/AC-18a) and the overrides record is deleted; an overrides record whose `sourceID` matches no `SourceRecord` is ignored by the index and never deleted by this path, because its `SourceRecord` may still be in transit (0004 edge case on out-of-order sync).

### AC-28 Hardware keyboard
Given a hardware keyboard on macOS, iPadOS or iOS
When keys are pressed
Then Return in `guideSources.add.field` runs AC-2 and Escape closes the form with nothing written; down arrow from `guideSources.picker.field` focuses `guideSources.picker.result.0` with the 0010/AC-14 focus ring, Up and Down move between results without mapping, Return on a focused result applies AC-17, and Escape returns focus to the field.

### AC-27a Source removed while the screen is open
Given `guideSources.root` open for S
When S's `SourceRecord` is deleted on another device and the deletion syncs, or on this device from another window
Then `guideSources.root` closes within five seconds to the screen that opened it (the source list in Sources and Settings, `shell.settingsSheet` on tvOS), and no record for S is written afterwards.

### AC-29 Record size cap
Given S's encoded `GuideOverrides` within 2 KB of the 500 KB cap
When a mapping is added that would push it over
Then the mappings whose `channelID` is in no current channel of S are dropped oldest `updatedAt` first until the new one fits, and the write succeeds; when no such mapping remains, nothing is written and `guideSources.diagnosis` shows "Too many mappings for this source. Remove some to add more." in the error style.

### AC-30 Dynamic Type
Given the largest accessibility text size on iPhone and iPad
When the guide list, the channel list and the picker are rendered
Then no `guideSources.guide.<i>.status` or `guideSources.channel.<rowKey>.reason` is truncated (they wrap), and the picker detail line truncates at its end with an ellipsis.

### AC-31 VoiceOver
Given VoiceOver on iOS, iPadOS or macOS
When focus lands on a guide row, a channel row and a result
Then the guide row reads its name, redacted URL and status; the channel row its name, number and reason label; the result its display name, id and programme count.

### AC-32 Undecodable overrides payload
Given S's `GuideOverridesRecord` whose `payload` does not decode as `GuideOverrides` (truncated JSON, or a newer schema with a required field this build lacks)
When the app loads overrides for S
Then S behaves as having no overrides (AC-1 entries, no mappings), the record is neither overwritten nor deleted until the user's first write per AC-25 replaces it, and nothing crashes.

## Edge cases and failure modes

- A guide URL list the user never touched behaves as 0014 did for M3U and Stalker and downloads every header URL for M3U, which can double traffic for playlists that list the same guide twice under two hosts; AC-1 and AC-2b dedupe exact URLs only.
- A playlist refresh that reorders its header URLs moves `.playlistHeader(i)` to another guide. Accepted; the ADR may choose to key header entries by URL instead.
- Two devices mapping different channels within one sync window: the per-source record means CloudKit keeps one version and AC-13b merges duplicates when both arrive, but a plain overwrite of the same record loses the earlier device's mapping. Listed as an open question for the ADR.
- `Channel.id` embeds the stream URL for M3U until the 0001 follow-up; the Blocked line applies and `channelID` is never shown or logged (ADR-0003).
- An M3U channel without `tvg-id`, the headline case for `.noEPGID`, gets a positional fallback id from `M3UParser` today, so its mapping dangles whenever the playlist reorders (0005 edge case). The 0001 follow-up requirement under "Required of other specs" removes this; until it merges, AC-12 is tested with `tvg-id` channels only and the dangling mapping stays in `mappings` as AC-12 describes.
- A custom guide with credentials (AC-22a) works on the device that added it and on devices where iCloud Keychain delivers the item; on Apple TV the item does not sync (0023's footer, 0006's pending ADR) and the row shows AC-22b's tvOS text with Re-enter URL.
- Mapping targets are limited to guides of the same source, so a user with a guide-less playlist adds a public guide URL to that source rather than borrowing another source's.
- An id that several channels of one source share (two qualities of one channel) shares one key; mapping one of them changes only that channel's key.
- The provider guide for an Xtream source whose `epgURL` is set starts disabled (AC-1), so AC-1's row five keeps 0014's traffic for users who added an EPG URL because the provider's is bad.
- Programme boundary: the `.ok` body's day count and the AC-15 list change as programmes expire; rows update within five seconds as 0007/AC-21.
- A mapping whose channel left the playlist stays in `mappings` (AC-12) until AC-29 needs the room or the source is deleted.
- A guide of 5 000 channel names is held once per guide in the index; the picker's folded strings are built on the first query and dropped when the screen closes.

## Test plan

Resolution, join with priority, guide channel list, mapping, merge, diagnosis, the channels-without-guide derivation and the picker ranking are swift-testing tests over fixtures in AntennaCore against `GuideResolver`, `GuideIndex`, `GuideOverrides`, `GuideDiagnosis` and the picker matcher. Persistence, progress, sync observation and deletion use an in-memory `ModelContainer`, a stubbed `URLSession`, a fake `CredentialStore` and an injected clock in the app layer. UI tests launch with fake sources, a fake `GuideStore` and an injected overrides store. Identifiers: `guideSources.root`, `guideSources.title`, `guideSources.guides`, `guideSources.guide.<index>`, `guideSources.guide.<index>.name`, `guideSources.guide.<index>.status`, `guideSources.guide.<index>.toggle`, `guideSources.guide.<index>.moveUp`, `guideSources.guide.<index>.moveDown`, `guideSources.guide.<index>.retry`, `guideSources.guide.<index>.remove`, `guideSources.guide.<index>.reenter`, `guideSources.add`, `guideSources.add.field`, `guideSources.add.save`, `guideSources.add.cancel`, `guideSources.add.error`, `guideSources.channels`, `guideSources.channels.header`, `guideSources.channels.loading`, `guideSources.channels.unavailable`, `guideSources.channels.showAll`, `guideSources.channel.<rowKey>`, `guideSources.channel.<rowKey>.reason`, `guideSources.filter`, `guideSources.empty`, `guideSources.diagnosis`, `guideSources.diagnosis.eyebrow`, `guideSources.diagnosis.title`, `guideSources.diagnosis.body`, `guideSources.mapping.remove`, `guideSources.picker`, `guideSources.picker.field`, `guideSources.picker.result.<index>`, `guideSources.picker.cap`, `guideSources.picker.empty`, `guideSources.clock` (tvOS).

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (`GuideResolver`, parameterised over the rows) | TBD |
| AC-1a | core | TBD |
| AC-2 | integration (in-memory container, header-recording stub) + ui | TBD |
| AC-2a | ui | TBD |
| AC-2b | integration + ui | TBD |
| AC-2d | ui | TBD |
| AC-2c | ui (tvOS) | TBD |
| AC-3 | integration (recorded requests, injected clock) + ui | TBD |
| AC-4 | integration | TBD |
| AC-4a | integration (retained fixture, recorded requests) | TBD |
| AC-4b | integration (no retained result) | TBD |
| AC-5 | integration + ui (absence of remove) | TBD |
| AC-6 | core (`GuideIndex`) | TBD |
| AC-7 | integration (parameterised over guide states) | TBD |
| AC-8 | integration (two-guide stub) | TBD |
| AC-9 | core (`GuideIndex`) | TBD |
| AC-10 | core (join) + integration (record written) | TBD |
| AC-10a | core | TBD |
| AC-10b | core (`key(for:)`); blocked for M3U channels without `tvg-id` until the 0001 follow-up, tested with an Xtream channel with no `epg_channel_id` | TBD |
| AC-11 | core + integration | TBD |
| AC-12 | core | TBD |
| AC-13a | integration (in-memory container, second context) | TBD |
| AC-13e | device | CloudKit cannot run in CI; manual two-device check |
| AC-13b | core (`GuideOverrides.merged`) | TBD |
| AC-13c | core | TBD |
| AC-13d | integration (write-back and delete) | TBD |
| AC-14 | core (parameterised over the table) | TBD |
| AC-14a | ui (parameterised over cases and platforms) | TBD |
| AC-14b | ui | TBD |
| AC-14c | core | TBD |
| AC-15 | core (derivation, order) + ui (count, reason labels) | TBD |
| AC-15a | ui | TBD |
| AC-15b | core (shared matcher) + ui | TBD |
| AC-15c | ui (fake GuideStore states) | TBD |
| AC-15d | ui (stubbed sources) | TBD |
| AC-15e | ui | TBD |
| AC-15f | ui (parameterised, includes `.sourceLoading` with channels) | TBD |
| AC-16 | core (ranking) + ui (prefill, highlight) | TBD |
| AC-16a | ui | TBD |
| AC-16b | ui | TBD |
| AC-16c | ui (tvOS) | TBD |
| AC-16d | core (dedupe, winner) + ui (highlight, singular) | TBD |
| AC-16e | ui | TBD |
| AC-17 | integration + ui (iPad, iPhone, tvOS) | TBD |
| AC-17a | ui | TBD |
| AC-17b | ui (iPad, tvOS, iPhone pop) | TBD |
| AC-18a | ui (tvOS) | TBD |
| AC-18b | ui (tvOS) | TBD |
| AC-18c | ui (tvOS) | TBD |
| AC-18d | ui (tvOS, fake engine) | TBD |
| AC-18e | ui (tvOS) | TBD |
| AC-18f | ui (tvOS) | TBD |
| AC-18g | ui (tvOS) | TBD |
| AC-19 | core benchmark + device (memory) | manual on Apple TV 4K for memory |
| AC-20 | integration (offline stub) + ui | TBD |
| AC-21 | integration (fake credential store) + ui | TBD |
| AC-22 | core (`redacted`) + ui (no raw URL in any attribute) | TBD |
| AC-22a | core (URL splitting) + integration (Keychain in simulator, header-recording stub) | TBD |
| AC-22b | integration (fake credential store) + ui | TBD |
| AC-23 | ui (parameterised over errors) + integration (retry request) | TBD |
| AC-24 | ui (launch argument with source and channel) | TBD |
| AC-25 | integration (record count) | TBD |
| AC-26 | integration (stub bodies) | TBD |
| AC-27 | integration (local delete and simulated disappearance) | TBD |
| AC-27a | ui (fake sources store) | TBD |
| AC-28 | ui (macOS; iPad and iPhone `typeKey`) | TBD |
| AC-29 | core (size, pruning order) + ui (error text) | TBD |
| AC-30 | ui (accessibility size launch argument) | TBD |
| AC-31 | ui (accessibility labels) | TBD |
| AC-32 | integration (corrupt payload fixture) | TBD |

## Dropped

- AC-27b (delete overrides orphaned for 30 days) moved out of scope; the sweep could delete a record whose `SourceRecord` is still in transit on a device offline for a month.

- AC-18 (focus and Menu on tvOS) is split into AC-18a to AC-18d; it held nine assertions and left the landing row and the last-row case undefined.
- AC-15's filter and loading clauses moved to AC-15b and AC-15c; AC-15 keeps derivation, header and row anatomy.
- AC-13b's order and write-back clauses moved to AC-13c and AC-13d; AC-13b keeps the mapping merge. AC-13a's device check moved to AC-13e.
- AC-14's text, label and suffix clauses moved to AC-14a to AC-14c; AC-14 keeps case selection.
- AC-16's row and empty-field clauses moved to AC-16d and AC-16e; AC-17's card clause to AC-17b; AC-18c's down, select and Menu steps to AC-18e to AC-18g; AC-4's turn-on clause to AC-4a and AC-4b; AC-2's row and form clause to AC-2d.

## Open questions

- Record shape for the ADR: one record per source (assumed here, simplest to sync and dedupe, loses concurrent edits from two devices) or one record per mapping and per custom URL (no clobbering, many small records, order needs its own field).
- Should the provider guide stay enabled when the user sets an `epgURL` on an Xtream source? Assumed off (AC-1 row five) to keep 0014's traffic; the user can turn it on.
- Should a header URL be identified by its URL rather than its index, so a reordered playlist header does not move the entry? Assumed index, because header URLs can carry credentials and the ADR decides what is stored.
- Should the per-key winner be the guide with the longest horizon rather than the first in order? Assumed order; a guide-merging spec can change it.
- Should the picker also suggest entries by number (`tvg-chno` against the guide's `<lcn>` element)? 0002 does not parse `<lcn>`.
- tvOS has no filter over the channel list; a source with thousands of channels without a guide is a long scroll. A search field on the channel column was considered and left out to keep one keyboard on the screen.
- Should the Guide row in Sources and Settings show the AC-15 count as a badge, so a user sees "24" without opening the screen? Assumed yes under "Required of other specs".
- Retaining every enabled guide's parse result (Scope) is what lets reorder and re-enable work offline and without a download; it costs memory on tvOS. AC-19's device measurement decides whether the storage ADR keeps it.
- The reviewer asked to split this spec into multiple guides (AC-1 to AC-8) and mapping with diagnosis (AC-9 onwards). Kept as one: the diagnosis needs per-guide states and the picker needs the multi-guide channel list, so the second half cannot ship first. The owner can still split before acceptance.
- The reviewer asked to gate acceptance, not only implementation, on the record ADR. Assumed implementation only, per the header, so the spec can be reviewed while the ADR is written.
- AC-29 caps the payload at 500 KB and prunes only mappings for channels gone from the playlist. A cap per mapping count is the alternative.
- AC-16 picks one row per id and lets the join decide the guide. Storing the picked guide with the mapping, so the user's pick beats priority, was the alternative.
- AC-22a moves the path, query and userinfo of every custom URL that is not a plain one-segment guide file to the Keychain, so such a guide added on iPhone needs AC-22b's Re-enter URL on Apple TV. Keeping non-secret parts in the record needs a list of secret names, which 0014/AC-15 says cannot be complete.
- Tombstones in `removedMappings` and `removedGuides` grow without bound apart from AC-29's pruning. The ADR may age them out after a period longer than any expected sync delay.
- Second-round findings left open: the reviewer asked to move AC-1 to AC-9, AC-10b and AC-19 into the 0014 revision; to split AC-14a, AC-20, AC-21, AC-24 and AC-27 per behaviour and AC-18a per assertion; criteria for macOS mouse drag and context menu, the tvOS Move up and Move down path, Re-enter URL focus on tvOS, and the screen with zero sources; and a note that UI tests read `<index>` identifiers after a reorder settles. AC-13e and AC-19's memory half are `device` rows, which `scripts/check-specs.sh` exempts.
- AC-22a splits credentials out of custom guide URLs into the Keychain. 0004 still stores `epgURL` and M3U URLs with embedded credentials in clear; a 0004 revision could adopt the same split.
