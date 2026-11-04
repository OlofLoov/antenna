# 0006. First-run onboarding and add-source flow

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005, 0006
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0004 (storage and validation of a source), 0010 (inline Live playback, missing-credential state on iOS), 0013 (catalogue, first channel), 0014 (guide progress), 0015 (tvOS shell), 0016 (VOD and series counts; `XtreamError.unauthorized`, 0016/AC-11, which supersedes 0003/AC-7 and adds `auth` to `XtreamAccountInfo.UserInfo`). Supersedes 0004/AC-8 for the no-sources case: onboarding replaces the empty Channels tab.
- Follow-up ADR (before the implementing PR): ADR-0003 assumes iCloud Keychain sync, which tvOS does not provide for kSecAttrSynchronizable items. This spec fixes the tvOS behaviour as "credential entered and kept on this Apple TV" (AC-21 and the tvOS Keychain copy on TV-Onboard-3, -SignIn, -Help and -5). If the amendment chooses another store, AC-21 and that copy are superseded by it.

## Design

Boards: `docs/design/boards/TV-Onboard-1.dc.html` to `TV-Onboard-5.dc.html` (tvOS), `docs/design/boards/iPhone-Onboard-1.dc.html` to `iPhone-Onboard-3.dc.html` (iOS; iPadOS and macOS centre the same sheet at 390 pt wide). State boards sit beside them as `<Board>-<State>.dc.html`.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-14, DR-15. Deviations: DR-3, done markers, the clipboard banner tint and its Fill in control, and the tvOS ready eyebrow use the accent because they are completion and link affordances; DR-5, the iPhone show-password control is 28 pt visually with a 44 pt hit area; DR-12, the tvOS keyboard card describes the iOS continuity-keyboard offer generically ("An unlocked iPhone or iPad nearby offers...") without asserting that an offer exists; kept because the alternative is no help at all for remote-only text entry.
States on the boards:
- Welcome with "What is a source?" (TV-Onboard-1, iPhone-Onboard-1).
- Help, `onboarding.help`, headings "M3U playlist" and "Xtream login", body copy at 29 pt on tvOS and 17 pt on iOS, `onboarding.help.done` (TV-Onboard-Help full screen, iPhone-Onboard-Help sheet).
- Type picker with the focused card and the dimmed Stalker card (TV-Onboard-2); the iOS segmented picker with the Stalker caption of AC-3 (iPhone-Onboard-2).
- Xtream details form with a focused field, the Keychain note and the tvOS keyboard card (TV-Onboard-3). The card's copy is static and names the platform, never the user's device. iPhone-Onboard-2 shows the clipboard banner of AC-17a over the fields as AC-17b fills them, plus a sample Name.
- M3U form (AC-4a) with the AC-23 error under it in the error style (TV-Onboard-3-M3U, iPhone-Onboard-2-M3U). The iPhone board shows the fields as AC-17c fills them, plus a sample Name.
- Connect in progress, AC-30, disabled control with an indeterminate ring; the tvOS board shows focus on Back per AC-34 (TV-Onboard-3-Connecting, iPhone-Onboard-2-Connecting).
- Clipboard banner after Fill in found no link, AC-17d (iPhone-Onboard-2-NoLink).
- Sign in on this Apple TV, AC-21 (TV-Onboard-SignIn).
- Loading checklist with the guide row indeterminate during download, AC-12a (TV-Onboard-4).
- "No live channels" row with `onboarding.browseMovies`, AC-32 (TV-Onboard-4-NoLive, iPhone-Onboard-3-NoLive).
- M3U checklist (AC-10b) with "No channels found" and disabled Start watching, AC-32; the tvOS board shows focus on Back per AC-34, the iPhone sheet is headed "Nothing to watch yet" with Back in the navigation bar and no Add another source (TV-Onboard-4-Empty, iPhone-Onboard-3-Empty).
- Ready with four tiles over the already-playing first channel, caption "Live · <number> <name>", `onboarding.nowPlaying` (TV-Onboard-5), and the ready list of AC-14b with the guide row indeterminate (iPhone-Onboard-3).
- Ready with two sources, AC-16b and AC-19b (TV-Onboard-5-Two, iPhone-Onboard-3-Two).
Fixed captions on the boards are copy the implementation must match: the loading subtitle "This runs once.", "The guide keeps loading behind the picture", "Press Menu to go back and check the link", the ready body copy ("The first channel is already playing. Press the touch surface for the channel list, press play/pause for the channel bar." on tvOS, "Everything below is loading. The guide finishes in the background while you watch." on iOS), and the banner subtitle "Antenna reads it only when you tap Fill in".
Error style: 15 pt iOS, 22 pt tvOS, `#FF5F57` text. Step segments on every tvOS board: 32 by 6 pt `#F2F4F8` for the current step, 6 by 6 pt `rgba(255,255,255,0.3)` for the others (AC-19a). The iPhone guide toggle was removed from iPhone-Onboard-2; opting out of the guide is out of scope.
Not drawn: AC-12b guide row done (title style, full 6 pt/4 pt accent bar); AC-12c guide row failed (error style, no bar) and the ready step with the guide tile omitted; AC-10a timeout row and AC-11 date/connection omissions (same row styles, text only); tvOS "Reading the guide…" (as iPhone-Onboard-3-Two). To be drawn before the implementing PR.

## Problem

A new user who has paid (ADR-0006) opens Antenna and sees an empty Channels tab with a sentence pointing at Settings. TiviMate users expect the app to ask for a playlist right away, show what it found while it loads, and drop them into live TV. Today adding a source is a Settings sheet with no feedback beyond the sheet closing.

## Scope

In:
- Onboarding shown when the entitlement is present and the store holds no `SourceRecord` with a non-nil `url`.
- tvOS steps: welcome, source type, details, loading checklist, ready. iOS, iPadOS, macOS: welcome, one add-source sheet (type picker plus details), ready sheet with the live checklist.
- Source types offered: M3U playlist, Xtream login. Stalker is shown disabled.
- Connect downloads the playlist (M3U) or calls the account endpoint (Xtream) before saving; the loading step reuses that response and never re-fetches.
- Validation and save through the same code path as 0004 (0004/AC-1 to AC-5 hold here).
- Loading checklist with per-step state and real counts, driven by 0013, 0014 and 0016.
- Start watching before the guide has finished; the first channel plays behind the tvOS ready step.
- Clipboard suggestion on iOS and iPadOS.
- Add another source from the ready step.
- Sign in on this Apple TV when every Xtream source lacks a credential on this device (AC-21, tvOS only).
- Accessibility identifiers with prefix `onboarding.`.

Out (explicitly):
- The paywall and entitlement checks (ADR-0006 follow-up spec). Onboarding takes an entitlement provider that reports entitled.
- Stalker portal handshake and form.
- Local M3U file import.
- Editing or deleting a source (spec 0004 and a later Sources spec).
- Opting out of the Xtream guide (needs a `SourceRecord` field and an ADR).
- Multiple EPG sources per playlist.
- Refreshing sources after onboarding (source refresh spec). Guide resume after relaunch is 0014/AC-14.
- Playback engine behaviour once the first channel plays (ADR-0001, playback spec).

## User flow

tvOS:
1. First launch after purchase. Welcome: the Antenna mark, "Welcome to Antenna", one sentence that no channels are included, Add a source focused, "What is a source?" below it, and a footer that sources added on iPhone or iPad appear here through iCloud (shown only when signed into iCloud).
2. Add a source shows three cards: M3U playlist, Xtream login (focused), Stalker portal (dimmed). Menu returns to welcome.
3. Details per AC-4a or AC-4b. The system keyboard offers the iPhone continuity keyboard; a side card explains it. A lock note says the login is saved in the Keychain on this Apple TV. Connect is below the form. Menu returns to the type picker with values kept. Initial focus is the first empty required field.
4. Connect validates, fetches, and on success saves and shows the loading step. Errors appear under the form.
5. Loading checklist rows turn done as data arrives. Start watching now is enabled once the channel row is done. When every row is done or failed the ready step appears.
6. Ready: the first channel is already playing behind the panel; four tiles, Start watching, Add another source, iCloud note. Start watching dismisses the panel.

iOS, iPadOS, macOS:
1. Welcome is a full-screen sheet with the mark, the same copy, three feature rows, Add a source and "What is a source?". On iPadOS and macOS the sheet is 390 pt wide and centred.
2. Add a source is one form: segmented type picker with a caption for Stalker, clipboard banner when a link is on the pasteboard, grouped fields for the chosen type, lock note, Connect.
3. Connect behaves as on tvOS. Success moves to the ready sheet.
4. Ready shows the checklist rows with their live state, the iCloud note, Start watching and Add another source. Start watching dismisses the sheet to the Live section with the first channel playing inline.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Onboarding replaces the empty app
Given an injected entitlement provider reporting entitled and a store with no `SourceRecord` whose `url` is non-nil
When the app reaches its root view
Then the onboarding welcome step is shown instead of the shell, and no network request is made.

### AC-2 Onboarding is not shown when a usable source exists
Given at least one `SourceRecord` with a non-nil `url` whose credential, if it needs one, is readable on this device
When the app reaches its root view
Then the shell is shown and onboarding is not.

### AC-3 Type picker
Given the welcome step
When the user activates Add a source
Then the type step lists M3U playlist and Xtream login as selectable and Stalker portal disabled with accessibility label "Stalker portal, coming later" and the not-enabled trait; on tvOS the card is focusable and select leaves the step unchanged; on iOS the segment reads "Stalker" and a caption under the picker reads "Stalker portals are coming later".

### AC-4a M3U form fields
Given the type step
When the user selects M3U playlist
Then the form shows Name (optional), Playlist URL and Guide URL (optional); on iOS, iPadOS and macOS the row labels are "Playlist" and "Guide" with the placeholder "Optional XMLTV link".

### AC-4b Xtream form fields
Given the type step
When the user selects Xtream login
Then the form shows Name (optional), Server, Username and Password with `onboarding.field.showPassword` that toggles the field between obscured and plain.

### AC-5 Back keeps entered values
Given a details form with text in every field
When the user goes back to the type step and forward to the same type again
Then every field still holds its text.

### AC-6 Validation reuses 0004
Given a details form
When the user activates Connect with an invalid URL or server
Then 0004/AC-1 applies and the error is rendered under the form as `onboarding.error`.

### AC-7 Xtream login is rejected
Given the account call throws `XtreamError.unauthorized` (0016/AC-11)
When the user activates Connect
Then `onboarding.error` reads "Could not sign in. Check the username and password.", no `SourceRecord` and no Keychain item are created, and the form keeps its values.

### AC-8 Offline connect
Given the request fails with `URLError` code `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed` (or 0016/AC-10's `.transport` of those codes)
When the user activates Connect
Then `onboarding.error` reads "You're offline. Connect to the internet and try again.", nothing is saved, and Connect stays enabled.

### AC-9 Successful connect saves as 0004 does
Given a details form whose account call succeeds (Xtream) or whose playlist downloads with a 2xx status (M3U; the channel count is judged on the loading step, AC-32)
When the user activates Connect
Then a `SourceRecord` and, for Xtream, a Keychain item exist exactly as 0004/AC-2 to AC-4 describe, and the loading step is shown titled "Setting up <source name>".

### AC-10a Checklist rows for Xtream
Given the loading step for an Xtream source whose server reports 412 live streams in 18 categories, 1 240 VOD streams and 86 series
When each response arrives
Then `onboarding.row.channels` turns done reading "412 live channels in 18 groups" (groups are 0013/AC-2 groups excluding Favorites and All channels) with the first eight group names and "and n more" beneath, and `onboarding.row.vod` turns done reading "1 240 movies and 86 series" with "Posters and descriptions load as you browse" beneath; counts use the locale's grouping separator (examples in sv-SE); if the lists have not arrived 20 seconds after the login row completed the row reads "Movies and series available" without counts; the row then counts as done and the ready step omits the vod tile.

### AC-10b Checklist rows for M3U
Given Connect succeeded for an M3U source with the downloaded playlist text
When the loading step appears
Then `onboarding.row.playlist` is done reading "Playlist downloaded" with the host beneath, `onboarding.row.channels` is done as in AC-10a from the same text, `onboarding.row.guide` is in progress, and no login or movies row exists.

### AC-11 Signed-in row
Given an Xtream login whose `user_info.exp_date` is Unix seconds as a number or numeric string and `max_connections` is numeric and greater than 0
When the login row completes
Then it reads "Signed in" with "Account active until <date in the locale's long style>" and " · 1 connection" or " · <n> connections" beneath; an absent, null, non-numeric or 0 `exp_date` omits the date; an absent, non-numeric or 0 `max_connections` omits the connections and its separator.

### AC-12a Guide row, downloading
Given the guide download is in progress (0014/AC-9)
When `progressStream()` reports bytes
Then `onboarding.row.guide` shows an indeterminate bar and "Downloading the guide · <bytes as ByteCountFormatStyle with one decimal>"; after the final byte and until `.loaded` or `.failed` it reads "Reading the guide…".

### AC-12b Guide row, loaded
Given 0014 emits `.loaded` with 388 of 412 channels and 7 days
When the row completes
Then it reads "Guide for 7 days · 388 of 412 channels" with a full bar.

### AC-12c Guide row, failed
Given 0014 emits `.failed`
When the row completes
Then it reads "Guide could not be loaded" in the error style and the ready step omits the guide tile.

### AC-13 Start watching before the guide is done (tvOS)
Given the channel row is done and the guide row is in progress
When the user activates `onboarding.startWatching`
Then onboarding is dismissed, the first channel per AC-15 plays, and the source's 0014 `loadingState` reaches `.loaded` after dismissal.

### AC-14a Ready step (tvOS)
Given the loading step with all rows done or failed, one source
When the ready step is shown
Then the AC-15 channel is already playing behind the panel with `onboarding.nowPlaying` reading "Live · <number> <name>", the eyebrow reads "<source name> added", the title "You're set", and tiles `onboarding.tile.channels` (live channels with group count), `.guide` (days with matched channel count), `.vod` (movies plus series total) and `.catchup` (the most common non-nil `catchupDays` across channels with `hasCatchup`, or "Catch-up" when all nil, with the count of such channels); a tile whose value is zero is omitted.

### AC-14b Ready list (iOS, iPadOS, macOS)
Given the ready sheet
When it is shown
Then it lists rows per AC-10a and AC-11 with the channels row reading "<n> live channels" over the detail "<n> groups" and the movies detail reading "In the Movies tab", the guide row per AC-12, and no catch-up row.

### AC-15 Start watching
Given the ready step
When the user activates Start watching
Then on tvOS the panel is dismissed and the channel keeps playing; on other platforms the lowest-numbered channel of the first source group in 0013/AC-2 order (skipping Favorites and All channels) plays inline in the Live section (0010/AC-6). The same channel is the one AC-14a plays.

### AC-16a Add another source, entry
Given the ready step
When the user activates `onboarding.addAnother`
Then the type step is shown, on tvOS with step segment 2 emphasised, and Back returns to the ready step.

### AC-16b Add another source, completion
Given a second source completed
When the ready step is shown
Then the title reads "2 sources added"; channel, group, matched-channel, movie, series and catch-up channel counts are summed across sources; guide days and catch-up days show the larger source's value; the eyebrow reads the source names joined by " · "; and on iOS, iPadOS and macOS the list shows one section per source with its rows.

### AC-16c First guide continues
Given the first source's guide download was running when the second source was added
When the second completes
Then the first source's `loadingState` reaches `.loaded` without a restart.

### AC-17a Clipboard banner
Given the pasteboard reports `probableWebURL` through pattern detection on iOS or iPadOS
When the add-source sheet appears
Then `onboarding.clipboardBanner` reads "A link is on the clipboard" with `onboarding.clipboardBanner.fill`, and the pasteboard has not been read.

### AC-17b Fill in with Xtream details
Given the banner and a pasteboard holding one URL with `username` and `password` query items
When the user activates Fill in
Then the pasteboard is read once, Xtream is selected, and Server (scheme, host, port), Username and Password are filled.

### AC-17c Fill in with a playlist link
Given the banner and a pasteboard holding a URL without those items
When the user activates Fill in
Then M3U is selected and Playlist URL is filled.

### AC-17d Fill in with no link
Given the banner and a pasteboard holding no URL
When the user activates Fill in
Then the banner reads "No link on the clipboard" and nothing is filled.

### AC-18 No clipboard banner otherwise
Given the pasteboard reports no `probableWebURL`, or the platform is macOS
When the add-source sheet appears
Then no banner is shown and the pasteboard is not read.

### AC-19a Step indicator (tvOS)
Given any of the five tvOS steps or the sign-in step (AC-21, segment 3), not `onboarding.help`
When it is shown
Then `onboarding.steps` has five segments; the current step's segment is 32 by 6 pt in `#F2F4F8` and the others 6 by 6 pt at 30% white.

### AC-19b Sheet titles (iOS, iPadOS, macOS)
Given the add-source or ready sheet
When it is shown
Then the add-source title is "Add a source" and the ready title is the source name (0004/AC-3 default) or "2 sources added" after AC-16b.

### AC-20 Leaving during load keeps the source
Given the loading step with the channel row done
When the app is backgrounded and relaunched
Then onboarding is not shown and one `SourceRecord` exists, with its Keychain item when the source is Xtream.

### AC-21 Credential missing on this Apple TV (tvOS)
Given every `SourceRecord` is Xtream and none has a readable Keychain item on this device
When the app reaches its root view on tvOS
Then the details step is shown with title "Sign in on this Apple TV", Server prefilled from the record with the lowest `sortOrder`, Username and Password empty, and a muted line naming any further sources still to sign in; Connect runs AC-7, AC-8, AC-23, AC-26 and AC-29, then writes the Keychain item under `credentialKey` (set to `id.uuidString` when nil) without inserting a `SourceRecord`, and repeats for the next record or shows the loading step for the last. Stalker records are ignored. The muted line reads "<n> more source(s) to sign in after this one: <names in sortOrder>" and is absent for the last record. Menu suspends the app (system default). The ready eyebrow reads "<source name> signed in" after this path. On iOS, iPadOS and macOS 0010/AC-18 applies and this step is not shown.

### AC-22 Start watching on iOS while loading
Given the ready sheet with the guide row in progress
When the user activates Start watching
Then AC-15 applies and the source's `loadingState` reaches `.loaded` after dismissal.

### AC-23 Server unreachable
Given a syntactically valid server or playlist URL that fails with a `URLError` other than the AC-8 codes
When the user activates Connect
Then `onboarding.error` reads "Could not reach <host>. Check the address and try again.", nothing is saved, and Connect stays enabled.

### AC-24 No duplicate on Connect
Given a `SourceRecord` with the same `kind` and `url` exists when Connect succeeds
When the save runs
Then no second record is inserted; for Xtream the Keychain item is written under the existing record's `credentialKey`, and the loading step proceeds for that record.

### AC-25 What is a source
Given the welcome step
When the user activates "What is a source?"
Then `onboarding.help` is shown as a sheet (iOS, iPadOS, macOS) or full screen (tvOS) with headings "M3U playlist" and "Xtream login", the copy in the board, and one `onboarding.help.done` control returning to welcome.

### AC-26 Account not active
Given `user_info.status` is present, non-empty and not "Active" (case-insensitive)
When the user activates Connect
Then `onboarding.error` reads "This account is <status in lowercase>." and nothing is saved; an absent or empty status is treated as active.

### AC-27 Loading becomes ready
Given the loading step
When every row is done or failed
Then the ready step is shown within one second; while any row is in progress the loading step stays and `onboarding.startWatching` is enabled per AC-13.

### AC-28 Menu and Back after save
Given the loading or ready step
When the user presses Menu (tvOS) or Back
Then nothing changes on the loading step while a row is in progress, except the AC-32 "No channels found" case; on the ready step the shell is shown as if Start watching had been activated; Back never returns to the details form once a `SourceRecord` has been saved, except through the zero-channel row (AC-32).

### AC-29 Other HTTP errors
Given a server URL that answers a non-2xx status other than 401 or 403, or a playlist URL that answers any non-2xx status
When the user activates Connect
Then `onboarding.error` reads "The server answered with an error (<status>). Check the address and try again.", nothing is saved, and Connect stays enabled.

### AC-30 Connect in progress
Given Connect was activated and the check is running
When the user activates Connect again
Then no second request is made; `onboarding.connect` is disabled and shows an indeterminate indicator until the result; Back or Menu cancels the request and keeps the values.

### AC-31 Empty required field
Given a required field is empty
When the user activates Connect
Then `onboarding.error` reads "Enter the <field name>." for the first empty field in form order and no request is made; field names in the message: "server address", "username", "password", "playlist URL".

### AC-32 Zero channels
Given Connect succeeded for an Xtream source with zero live streams, or an M3U playlist that parsed to zero channels
When the loading step (tvOS) or the ready sheet (iOS, iPadOS, macOS) is shown
Then with a non-zero movies row `onboarding.row.channels` reads "No live channels" in the muted style and `onboarding.browseMovies` replaces Start watching, dismissing onboarding to the Movies section; with zero of both the row reads "No channels found" in the error style and Start watching is disabled; on iOS, iPadOS and macOS the sheet shows `onboarding.back` in the navigation bar, hides `onboarding.addAnother`, and the heading reads "Nothing to watch yet". A source with zero live channels and a non-zero movies row reaches the ready step per AC-27 with no `onboarding.nowPlaying`, nothing playing behind the panel, the channels tile omitted and `onboarding.browseMovies` in place of Start watching. With zero of both AC-27 does not apply: the loading step stays until Back, which cancels any guide download, deletes the `SourceRecord` only if this Connect inserted it (AC-24) plus any Keychain item this Connect wrote, and returns to the details form with values kept.

### AC-33 Malformed server reply
Given the account call throws `DecodingError`
When the user activates Connect
Then `onboarding.error` reads "The server replied with something Antenna could not read." and nothing is saved.

### AC-34 Initial focus (tvOS)
Given a tvOS step appears
When focus settles
Then it is on `onboarding.addSource` (welcome), `onboarding.type.xtream` (type step), the first empty required field or `onboarding.connect` when none is empty (details), `onboarding.startWatching` or `onboarding.browseMovies` when enabled, else `onboarding.back` (loading), and `onboarding.startWatching` (ready); while AC-30 runs focus moves to `onboarding.back`.

### AC-35 iCloud notes
Given the injected identity provider reports not signed in
When the welcome or ready step is shown
Then `onboarding.icloudNote` is absent; when it reports signed in the note is present with the board copy.

## Edge cases and failure modes

- Entitlement lapses during onboarding: the paywall replaces onboarding at the next root evaluation; a saved source stays saved (ADR-0006).
- No guide at all (M3U without guide URL, Xtream without EPG): the guide row is omitted and the ready step omits the guide tile.
- Source added on another device during onboarding: AC-24 prevents a duplicate when the user finishes.
- tvOS text entry: the system keyboard presents the continuity keyboard notification on nearby iPhones; no app code is involved.
- tvOS Menu: on welcome, the system default (suspend); on the type and details steps Menu equals Back; after save AC-28.
- Credential saved on tvOS is not synced elsewhere (see the follow-up ADR in the header); the tvOS notes say the source syncs, never the login.
- Keychain write failure: 0004/AC-5 applies.
- Not signed into iCloud (checked through an injected identity provider): the footer note is hidden on welcome and ready.
- A saved source with zero channels on tvOS lands in 0015/AC-11 after relaunch; on other platforms 0010/AC-18.
- Dynamic Type at the largest accessibility size: the form scrolls; Connect stays visible at the bottom.
- VoiceOver: each checklist row is one element reading state, title and detail.

## Test plan

Add-source and loading logic live in a `@MainActor` model that takes an injected `XtreamClient`, `URLSession`, `CredentialStore`, `GuideStore`, entitlement and identity providers, and clock, as 0004's test plan requires. Clipboard detection sits behind a `PasteboardPatterns` protocol. AC-13, AC-14a, AC-15 and AC-22 assert that `onboarding.*` is gone or the panel is dismissed and that the fake engine received `load` with the chosen channel's `streamURL` (recorded to a temp file, never an accessibility attribute). Identifiers: `onboarding.welcome`, `onboarding.addSource`, `onboarding.help`, `onboarding.help.done`, `onboarding.back`, `onboarding.type.m3u`, `onboarding.type.xtream`, `onboarding.type.stalker`, `onboarding.field.name`, `onboarding.field.server`, `onboarding.field.username`, `onboarding.field.password`, `onboarding.field.showPassword`, `onboarding.field.url`, `onboarding.field.epgURL`, `onboarding.connect`, `onboarding.error`, `onboarding.row.login`, `onboarding.row.playlist`, `onboarding.row.channels`, `onboarding.row.vod`, `onboarding.row.guide`, `onboarding.startWatching`, `onboarding.browseMovies`, `onboarding.addAnother`, `onboarding.clipboardBanner`, `onboarding.clipboardBanner.fill`, `onboarding.icloudNote`, `onboarding.steps`, `onboarding.nowPlaying`, `onboarding.tile.channels`, `onboarding.tile.guide`, `onboarding.tile.vod`, `onboarding.tile.catchup`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (injected entitlement, empty store) | TBD |
| AC-2 | integration (in-memory ModelContainer, fake credential store) | TBD |
| AC-3 | ui (tvOS and iOS) | TBD |
| AC-4a, AC-4b | ui | TBD |
| AC-5 | ui | TBD |
| AC-6 | integration | TBD |
| AC-7 | integration (client throwing `unauthorized`) | TBD |
| AC-8 | integration (each listed code) | TBD |
| AC-9 | integration | TBD |
| AC-10a | integration (parameterised per row) | TBD |
| AC-10b | integration | TBD |
| AC-11 | integration (string and numeric values, absent, 0, 1) | TBD |
| AC-12a, AC-12b, AC-12c | integration (fake GuideStore progress) | TBD |
| AC-13 | ui (tvOS) + fake engine | TBD |
| AC-14a | integration + ui (tvOS) | TBD |
| AC-14b | ui (iOS) | TBD |
| AC-15 | ui + fake engine | TBD |
| AC-16a, AC-16b, AC-16c | ui + integration | TBD |
| AC-17a to AC-17d | integration (fake pattern detector and pasteboard) + ui | TBD |
| AC-18 | integration (iOS and macOS) | TBD |
| AC-19a | ui (tvOS, frames) | TBD |
| AC-19b | ui (iOS) | TBD |
| AC-20 | ui (relaunch) + integration | TBD |
| AC-21 | integration + ui (tvOS) | TBD |
| AC-22 | ui (iOS) | TBD |
| AC-23 | integration (`.cannotFindHost`) | TBD |
| AC-24 | integration | TBD |
| AC-25 | ui | TBD |
| AC-26 | integration | TBD |
| AC-27 | integration (injected clock) | TBD |
| AC-28 | ui (tvOS) | TBD |
| AC-29 | integration (404, 500) | TBD |
| AC-30 | integration (delayed stub) + ui | TBD |
| AC-31 | integration | TBD |
| AC-32 | integration + ui | TBD |
| AC-33 | integration | TBD |
| AC-34 | ui (tvOS) | TBD |
| AC-35 | ui (injected identity provider) | TBD |

## Open questions

- ADR amending 0003 for tvOS: CloudKit-encrypted field in SwiftData, or keep the Keychain and rely on AC-21 as the permanent tvOS path.
- Clipboard: support provider message formats beyond a single URL?
