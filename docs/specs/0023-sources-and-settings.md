# 0023. Sources and Settings: edit, delete, refresh and app preferences

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- ADR needed: where app preferences persist. Written against one synced `SettingsRecord` in the ADR-0002 container (every field defaulted, no uniqueness; when sync yields more than one record the newest `updatedAt` is read and the others are deleted). Per-device facts (last successful load per source) stay in `UserDefaults`, as 0015 does for the last channel and 0014 for its timestamp. If the ADR chooses `UserDefaults` for preferences too, AC-37 to AC-39 change their storage and nothing else does.
- Blocked on the ADR amending ADR-0003 for tvOS that 0006 names (Keychain items do not sync to Apple TV). AC-7's tvOS text, AC-9's footer and AC-14 hold under the Keychain outcome and change wording only under a CloudKit-encrypted-field outcome.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0004 (storage, validation and Keychain rules for a source), 0006 (add flow and its error strings; the "Sign in on this Apple TV" step of AC-21), 0013 (catalogue, `tagged`, `groupOrder`, favorites resolution), 0014 (`GuideStore`, progress, `remove(sourceID:)`), 0015 (`shell.settings` and `shell.settingsSheet`), 0010 (Settings tab and sidebar entry), 0016 (`accountInfo()` and `XtreamError`).
- Supersedes 0004/AC-7 (rows show name and status, not the URL), 0004/AC-6 (delete now needs confirmation and also removes favorites and guide data), 0004/AC-9's "loads for the first time" (sources load on every store change and on a schedule), and 0004/AC-10 and AC-11 (per-source outcomes live in `SourceRefresher.states`; nothing is recorded on `SourceRecord`). Fixes the three gaps 0004 records: no delete affordance on tvOS and macOS, channels loaded once per launch, the duplicate `category_id` crash. Fills 0005's "cleaning up favorites whose source was deleted" and the source-refresh loop that 0013 and 0014 list under "Required of other specs".

## Design

Boards: `docs/design/boards/TV-Settings.dc.html` (tvOS, list with a focused source row and its detail), `TV-Settings-Delete.dc.html` (delete confirmation), `TV-Settings-Preferences.dc.html` (preferences pane); `iPad-Settings.dc.html` (iPadOS and macOS, sidebar | list | detail) and `iPad-Settings-Delete.dc.html`; `iPhone-Settings.dc.html` (list), `iPhone-Settings-Detail.dc.html` (source detail and edit form), `iPhone-Settings-Delete.dc.html` (alert).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15. Deviations: DR-1, deleting the playing channel's source calls `stop()` because its stream no longer exists (AC-21); DR-3, the iPhone navigation actions (Edit, Save, Cancel, Back) use the accent because they are links; DR-5, iPhone source rows are 60 pt with a 16 pt error line added when a refresh failed, so a row is never under 60.
States on the boards: the three source rows on every list board are in three states, loaded ("412 channels · Guide 7 days · 12 minutes ago"), waiting for login (muted "Waiting for login from iCloud" on iPad and iPhone, "Not signed in on this Apple TV" on tvOS) and refresh failed (counts kept, error line "Could not refresh: You're offline. Connect to the internet and try again." in the error style); the kind badge (`M3U`, `XTREAM`) in the badge style; the Add a source and Refresh all rows; the Preferences and About rows (iPhone shows the preference values inline); the iCloud footer; the focused source row on tvOS (Focus token) with the detail pane for it; the detail's status block, fields, Keychain note and the action row (Refresh now, Move up, Move down, Delete source); the delete confirmation with Cancel focused on tvOS; the tvOS preferences pane with the focused row.
Colour and type named in a criterion are checked by the impl-reviewer against the board, not by UI tests (as 0015). Error style: `#FF5F57` text (0006); in a source row 13 pt on iOS, iPadOS and macOS and 22 pt on tvOS; under the form 15 pt on iOS, 14 pt on iPadOS and macOS, 22 pt on tvOS. Delete source uses the same colour as text on the surface fill. Kind badges are 12 pt on iOS and iPadOS and 18 pt on tvOS, at the DR-4 floor.
Not drawn: the detail while Save runs (Save disabled, indeterminate ring in place of its label, 0006/AC-30 style); `settings.detail.error` under the form on every platform (error style, same place as `onboarding.error` on the 0006 boards); the loading row of AC-5 (status line text with a 16 pt indeterminate ring on iOS and iPadOS, 24 pt on tvOS, before the text); the Stalker row of AC-8 and the `url == nil` row of AC-7a (status line in the muted style of the waiting row); the AC-9 test b footer (same style, other text); the "Not loaded yet" status block of AC-11 (one line in the status block's first-line style) and its failed variants (last line in the error style); the M3U detail form (Name, Playlist URL, Guide URL in the same field rows, no Login group, no Keychain note); the iPad and macOS Preferences pane (the tvOS preference rows at 52 pt, 16 pt label, 15 pt muted value, chevron) and About pane (`settings.about.version` at 15 pt muted); the iPhone preference option screen (a pushed grouped list of 48 pt rows, 17 pt, checkmark glyph at the trailing edge of the current value); the option list a tvOS preference row opens (rows of 76 pt, 28 pt label, checkmark glyph at the trailing edge of the current value, same geometry as the preferences pane); the "Sign in on this Apple TV" form, which is 0006's `TV-Onboard-SignIn.dc.html` with the title replaced by the source name and `settings.detail.signIn` as the Connect button; iPhone edit mode with drag handles (system appearance); macOS, which uses the iPad board at regular width.

## Problem

Once a source is added there is no way to fix a typo in its URL, change a password the provider rotated, see whether it loaded, or remove it on Apple TV or Mac. Channels load once per launch, so a source added on iPhone shows nothing on an Apple TV that has been running since morning, and a provider's duplicate category id crashes the app. The screens in 0007 to 0012 assume a refresh loop that tags channels, orders groups and feeds the guide, and nothing owns it.

## Scope

In:
- Sources and Settings screen on every platform: iPhone Settings tab (0010/AC-2), iPad and Mac sidebar entry (0010/AC-3), tvOS gear (0015/AC-12a).
- Source list in `sortOrder` with per-source status: channel count, guide state (0014 progress), last successful load on this device, credential present on this device, last error.
- Source detail: status block, edit name, URL, guide URL and Xtream login, with verification before save through the same calls as 0006 Connect.
- "Sign in on this Apple TV" from the detail when the Keychain item is missing (0006/AC-21 reachable after onboarding); on the other platforms the same empty login fields.
- Delete with confirmation on every platform and its consequences: `SourceRecord`, Keychain item, `FavoriteRecord`s of that source, guide data (0014/AC-18, AC-18a), catalogue, playback.
- Reorder: drag on iOS, iPadOS and macOS, Move up and Move down on tvOS. `sortOrder` drives 0013's source order.
- `SourceRefresher`, the app-layer loop that loads each source, tags channels (0013/AC-1), passes `groupOrder`, rebuilds the catalogue after each source and calls `GuideStore` in 0014's order. Triggers: launch, store changes (local or sync), credential arrival, manual refresh, schedule. Changes this device wrote through the refresher or the detail model are consumed once: the store observer ignores a deletion already handled by AC-20c and a `url` change whose load is already running. A manual or scheduled refresh for a source in `.loading` is ignored; Save for a source in `.loading` cancels that load first.
- Preferences: open on launch, guide window, refresh interval, and on tvOS whether swipe changes channel. Stored in `SettingsRecord` (see the ADR line).
- About: version.
- Accessibility identifiers with prefix `settings.`.

Out (explicitly):
- Adding a source: 0006 owns the form; this screen only presents it (`settings.addSource` opens 0006's add-source sheet or type step).
- Caching channel lists across launches: the storage ADR 0014 is blocked on. Every launch loads every source over the network.
- Changing a source's kind: delete and add again.
- Stalker portal handshake and form (0004/AC-13 stays: the record is listed and inert).
- Multiple guide URLs per source, manual channel-to-guide mapping: 0014 out of scope, later spec.
- Hiding, renaming, locking or reordering groups and channels: later catalogue spec.
- Paywall, restore purchase, subscription management: ADR-0006 follow-up spec.
- Zap bar auto-hide delay, guide zoom beyond the window hours, hero rotation interval (0008, 0009, 0011 open questions): not preferences in this spec.
- Diagnostics export, logs: later spec.
- Local M3U file import: 0006 out of scope, later spec.

Required of other specs:
- 0013: `SourceRefresher` is the caller 0013 waits for. A 0005 revision defines the `FavoriteRecord` to `FavoriteSnapshot<PersistentIdentifier>` mapping; this spec calls it (AC-20b, AC-24, AC-27e).
- 0014: `refreshIfStale(now:)` reads the interval from `Preferences.refreshInterval` instead of the fixed 12 hours (AC-30a, AC-30b); "Only manually" means no scheduled guide refresh after the first completed load.
- 0008: AC-9 (swipe up and down change channel) applies only while `Preferences.swipeChangesChannel` is true; when false a swipe shows the bar as AC-2 does.
- 0009: the visible window spans `Preferences.guideWindow` instead of a fixed two hours; column width is (grid width minus the channel column) divided by the number of 30-minute columns, 370 pt at two hours.
- 0015: after the launch tune (AC-2a or AC-2b) the shell selects `Preferences.launchSection`; 0010: the tab bar or sidebar opens on it.
- 0010/AC-16, AC-18, AC-20, AC-21, AC-24 and 0015/AC-10, AC-11, AC-15 read their per-source state from `SourceRefresher.states`.

### Interface

Names are binding; signatures show intent.

```swift
// Apps/Shared/Sources/SourceRefresher.swift
@MainActor @Observable final class SourceRefresher {
    var states: [UUID: SourceLoadState]
    var catalogue: Catalogue<PersistentIdentifier>
    func refresh(sourceID: UUID)        // manual, one source, forces the guide too
    func refreshAll()                   // manual, every source
    func refreshIfStale(now: Date)      // schedule
}

enum SourceLoadState: Equatable, Sendable {
    case loading(previousCount: Int?)
    case loaded(channels: Int, groups: Int, at: Date, account: AccountSummary?)
    case failed(SourceLoadError, previousCount: Int?)
    case waitingForCredential
    case awaitingSync                   // SourceRecord.url is nil
    case unsupported                    // Stalker
}

struct AccountSummary: Equatable, Sendable {   // from accountInfo(), never the username
    var expiresAt: Date?
    var maxConnections: Int?
}

// Packages/AntennaCore, XtreamClient
extension XtreamClient {
    /// Category id to name. The first name for a repeated id wins; never traps.
    static func groupNames(_ categories: [XtreamCategory]) -> [String: String]
}

enum SourceLoadError: Equatable, Sendable {
    case offline, unauthorized, accountInactive(String), unreachable(host: String),
         httpStatus(Int), unreadable, noChannels, credentialUnreadable
}

@Model final class SettingsRecord {
    var id: UUID = UUID()
    var launchSectionRaw: String = "live"      // live, guide, movies
    var guideWindowHours: Double = 2           // 2, 3, 4
    var refreshIntervalHours: Double = 12      // 6, 12, 24, 0 (only manually)
    var swipeChangesChannel: Bool = true
    var updatedAt: Date = Date.now
}

@MainActor @Observable final class Preferences {   // reads the newest SettingsRecord
    var launchSection: LaunchSection
    var guideWindow: TimeInterval
    var refreshInterval: TimeInterval?         // nil = only manually
    var swipeChangesChannel: Bool
}
```

`SourceLoader.load(_:)` keeps its name and gains injected `URLSession` and `CredentialStore` (0004 test plan). The error strings are 0006's: `.offline` is 0006/AC-8, `.unauthorized` AC-7, `.accountInactive` AC-26, `.unreachable` AC-23, `.httpStatus` AC-29, `.unreadable` AC-33, `.noChannels` reads "No channels found" (0006/AC-32), `.credentialUnreadable` reads "Could not read the login from the Keychain."

## User flow

iPhone:
1. The Settings tab shows Sources and Settings: the sources with their status, Add a source, Refresh all, then Preferences with their values, then About, with the iCloud footer under Sources.
2. Tapping a source opens its detail: status block, editable fields, Refresh now and Delete source. Save appears in the bar once a field changed. Save verifies, then returns to the list, whose row shows "Refreshing…".
3. Swipe on a row shows Delete; Delete and the detail's Delete source both open the confirmation. Edit in the bar enables drag handles for reordering.
4. Tapping a preference row opens its options; the row shows the new value.

iPad and Mac:
1. Sources and Settings at the bottom of the sidebar shows the list in the middle column and the selected source's detail on the right. The first source is selected on entry.
2. Rows are dragged to reorder. Delete is in the detail, in the row's context menu and on the Delete key (Mac and iPad with a keyboard), always through the confirmation.
3. Preferences and About are rows in the list column; their content fills the detail column.

Apple TV:
1. The gear in the tab bar (0015/AC-12a) opens the panel over the current tab. Focus lands on the first source row; the right pane shows its detail. Moving focus along the rows changes the pane; select moves focus into it.
2. In the detail, fields open the system keyboard. Save verifies and returns focus to the row. Refresh now, Move up, Move down and Delete source are buttons under the fields. A source without a login on this Apple TV shows Sign in on this Apple TV above the fields.
3. Delete source opens the confirmation with Cancel focused. Menu anywhere in the panel steps back: dialog to detail, detail to row (discarding unsaved changes), row to the tab bar (0015/AC-12b).
4. Preferences is a row below the sources; its pane lists the four preferences with their values. Select on one opens its option list.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Entry points
Given at least one source
When the user activates the Settings tab (iOS), Sources & Settings in the sidebar (iPadOS, macOS) or `shell.settings` (tvOS)
Then `settings.root` exists; on iPadOS and macOS `settings.detail` for the first source in `sortOrder` whose `url` is non-nil exists beside it; on tvOS `settings.root` is inside `shell.settingsSheet` and that source's `settings.source.<id>` has focus. When no source has a non-nil `url`, iPadOS and macOS show the Preferences pane and tvOS focuses the first row.

### AC-2 Rows in order
Given sources with `sortOrder` 2, 0, 1
When the list is shown
Then `settings.sources` holds `settings.source.<id>` rows in `sortOrder` 0, 1, 2, each with the source name and a kind badge reading `M3U` or `XTREAM`, and no label, value or identifier of any element under `settings.sources` contains a source URL or its host.

### AC-3 Status line, loaded
Given a source in state `.loaded(channels: 412, groups: 18, at: t, account: nil)`, 0014 progress `.loaded` with `days` 7 for it, and an injected clock at t plus 12 minutes
When its row is rendered
Then `settings.source.<id>.status` reads "412 channels · Guide 7 days · 12 minutes ago"; the count uses the locale's grouping separator and the relative time is `Date.RelativeFormatStyle` in the named style ("yesterday", "2 hours ago").

### AC-4 Status line, guide states
Given a loaded source whose most recent 0014 progress event is in the left column
When its row is rendered
Then the guide fragment reads the right column, and a source for which `GuideURLResolver.resolve` yields no URL (0014/AC-1) reads "No guide".

| Progress | Fragment |
|----------|----------|
| none yet, load pending | "Loading guide…" |
| `.downloading` | "Downloading guide…" |
| `.loaded(days: n)` | "Guide n days" |
| `.failed(e)` with no earlier `.loaded` for the source on this device | "Guide failed" |
| `.failed(e)` after a `.loaded(days: n)` on this device (0014/AC-11a) | "Guide n days" from that event |

### AC-5 Status line, loading
Given a source in `.loading(previousCount: nil)` (test a) or `.loading(previousCount: 412)` (test b)
When its row is rendered
Then test a reads "Loading…", or "Loading… · last loaded <relative time>" when the injected `UserDefaults` suite holds `settings.lastLoad.<sourceId>`, with an indeterminate indicator; test b reads "412 channels · Refreshing…" with the indicator.

### AC-6a Failed with no previous list
Given a source in `.failed(e, previousCount: nil)`
When its row is rendered
Then `settings.source.<id>.status` reads the 0006 sentence for `e` in the error style and `settings.source.<id>.error` does not exist.

### AC-6b Failed with a previous list
Given a source in `.failed(.offline, previousCount: 412)` and guide `.loaded(days: 7)`
When its row is rendered
Then `settings.source.<id>.status` reads "412 channels · Guide 7 days · <relative time of the last success>" and `settings.source.<id>.error` reads "Could not refresh: You're offline. Connect to the internet and try again." in the error style; the row's frame is at least 76 pt on iOS at the default Dynamic Type size.

### AC-7 Credential missing
Given an Xtream source whose Keychain item is absent on this device, or whose `credentialKey` is nil
When the list is shown
Then its state is `.waitingForCredential`, `settings.source.<id>.status` reads "Waiting for login from iCloud" (iOS, iPadOS, macOS) or "Not signed in on this Apple TV" (tvOS) in the muted colour, and no request is issued for that source.

### AC-7a Record without a URL
Given a `SourceRecord` with `url` nil (partial sync)
When the list is shown
Then its state is `.awaitingSync`, `settings.source.<id>.status` reads "Waiting for iCloud…", its detail offers `settings.detail.delete` and no field, and no request is issued.

### AC-8 Stalker record
Given a `SourceRecord` with `kind` stalker
When the list is shown
Then its state is `.unsupported`, the status reads "Stalker portals are coming later" (0006/AC-3 wording), the detail offers Delete source and Name only, and no request is issued.

### AC-9 iCloud footer
Given the injected identity provider reports signed in (test a) or not signed in (test b)
When the list is shown
Then `settings.footer` reads "Sources sync to your other devices through iCloud. Logins sync through iCloud Keychain when it is on, and never to Apple TV." in test a and "Not signed in to iCloud. Sources stay on this device." in test b.

### AC-10 Detail fields
Given a source
When the user selects its row
Then `settings.detail` shows, for M3U, `settings.detail.name`, `settings.detail.url` and `settings.detail.epgURL` prefilled from the record; for Xtream, `settings.detail.name`, `settings.detail.url`, `settings.detail.username` prefilled from the Keychain item and `settings.detail.password` empty with the secure trait and placeholder "••••••••"; no accessibility label, value or identifier anywhere in `settings.detail` contains the stored password; `settings.detail.save` is disabled.

### AC-11 Detail status block
Given an Xtream source in `.loaded(channels: 412, groups: 18, at: t, account: AccountSummary(expiresAt: d, maxConnections: 2))`, guide `.loaded(channelsWithGuide: 388, channelsTotal: 412, days: 7)` and the injected clock at t plus 12 minutes
When the detail is shown
Then `settings.detail.status` reads, as lines, "412 channels in 18 groups", "Guide for 7 days · 388 of 412 channels" (0006/AC-12b), "Refreshed 12 minutes ago" and "Account active until <d in the locale's long style> · 2 connections" (0006/AC-11 rules for nil values); an M3U source omits the account line; `.failed(e, previousCount: n)` shows the lines of the last success plus "Could not refresh: <0006 sentence for e>" as the last line; `.failed(e, previousCount: nil)` shows the 0006 sentence as its only line; a source in `.loading(previousCount: nil)` reads "Not loaded yet" as its only line.

### AC-12 Name edit
Given the detail with `settings.detail.name` changed
When the user activates Save
Then the record's `name` is updated, no request is issued, the row and detail title show the new name, and an emptied name is replaced by the host per 0004/AC-3.

### AC-13a URL edit, M3U
Given an M3U detail with `settings.detail.url` changed to a valid URL
When the user activates Save
Then the new playlist is downloaded and parsed before anything is written; on at least one channel the record's `url` is updated and the parsed playlist is handed to `SourceRefresher`, which tags it, rebuilds `catalogue` and sets `.loaded` without a second download; on failure `settings.detail.error` reads the 0006 sentence (AC-8, AC-23, AC-29, "No channels found") and the record is unchanged. A changed `settings.detail.epgURL` is stored without a request and `GuideStore.refresh(source:)` is called once.

### AC-13b Login edit, Xtream
Given an Xtream detail with `settings.detail.url`, `settings.detail.username` or `settings.detail.password` changed
When the user activates Save
Then `accountInfo()` runs once with the new server and login (the stored password when the field is empty) before anything is written; on success the Keychain item under `credentialKey` (set to `id.uuidString` when nil) holds the new login, the record holds `url` and `credentialKey` only, no `SourceRecord` is inserted, and the source enters `.loading(previousCount:)`; on failure `settings.detail.error` reads the 0006 sentence (AC-7, AC-8, AC-23, AC-26, AC-29, AC-33) and neither record nor Keychain changes; a Keychain write failure reads 0004/AC-5's message. When no Keychain item exists on this device, an empty username or password is rejected before any request with `settings.detail.error` "Enter your username and password." and nothing is written.

### AC-14 Sign in on this Apple TV
Given a tvOS detail for a source in `.waitingForCredential`
When the detail is shown
Then `settings.detail.signIn` reads "Sign in on this Apple TV" above empty `settings.detail.username` and `settings.detail.password` and takes focus when the user selects the row; activating it moves focus to `settings.detail.username`; Save runs AC-13b, after which the state leaves `.waitingForCredential` and 0014's `.credentialMissing` keys are retried (0014/AC-1a). On the other platforms the same empty fields are shown without `settings.detail.signIn`.

### AC-15 Invalid URL
Given the detail with `settings.detail.url` holding text without a scheme
When the user activates Save
Then `settings.detail.error` reads "Enter a valid URL." (0004/AC-1), nothing is written and no request is issued.

### AC-16 Duplicate
Given another `SourceRecord` with the same `kind` and the edited `url`, and for Xtream the same username in that record's Keychain item on this device
When the user activates Save
Then `settings.detail.error` reads "This source is already added." and nothing is written. URLs are compared after trimming whitespace and one trailing slash and lower-casing scheme and host. For Xtream a different username, or an unreadable or absent Keychain item for the other record, is not a duplicate and the save proceeds.

Leaving a detail with unsaved changes discards them without a prompt on every platform (Open questions).

### AC-17a Cancel on iOS
Given the iPhone detail with unsaved changes
When the user activates `settings.detail.cancel` or Back
Then the list is shown, the record and Keychain are unchanged, and the fields show the stored values when the detail is next shown.

### AC-17b Leaving on iPadOS and macOS
Given the iPad or Mac detail with unsaved changes
When the user activates `settings.detail.cancel`, presses Escape, or selects another row or sidebar entry
Then the record and Keychain are unchanged and the fields show the stored values when the detail is next shown.

### AC-17c Menu on tvOS
Given the tvOS detail with unsaved changes
When the user presses Menu
Then focus is on the source's row, the record and Keychain are unchanged, and the fields show the stored values when the detail is next shown.

### AC-18 Save in progress
Given Save was activated and verification is running
When the user activates Save again
Then no second request is issued and `settings.detail.save` is disabled with an indeterminate indicator until the result (0006/AC-30).

### AC-18a Leaving while Save runs
Given Save was activated and verification is running
When the user leaves the detail by any route of AC-17a to AC-17c
Then the verification request is cancelled, nothing is written, and `settings.detail.refresh`, `settings.detail.delete` and the Move buttons were disabled while it ran.

### AC-19a Delete confirmation
Given a source with 412 loaded channels and 3 `FavoriteRecord`s whose `sourceID` is its id
When the user activates `settings.detail.delete`, `settings.source.<id>.delete` from the swipe action (iOS) or the context menu (iPadOS, macOS), or presses the Delete key with the row selected (macOS, iPadOS)
Then `settings.deleteConfirm` shows title "Delete <name>?", body "Removes its 412 channels, 3 favorites and guide from every device signed in to your iCloud account." (the favorites clause is omitted at 0, the channels clause when never loaded, and the ending reads "from this device." when the identity provider reports not signed in), `settings.deleteConfirm.delete` and `settings.deleteConfirm.cancel`, with Cancel focused on tvOS; nothing has been deleted.

### AC-19b Cancel
Given `settings.deleteConfirm`
When the user activates `settings.deleteConfirm.cancel` or presses Menu
Then it is gone and the record, Keychain item and favorites are unchanged.

### AC-20a Delete removes the record and its login
Given the confirmation of AC-19a
When the user activates `settings.deleteConfirm.delete`
Then the `SourceRecord` is gone, the Keychain item under its `credentialKey` is gone (0004/AC-6), and its row is gone.

### AC-20d Selection after delete
Given the confirmation of AC-19a for a source that is not the only one
When the user activates `settings.deleteConfirm.delete`
Then on tvOS focus is on the row now at the deleted row's position, or on the previous row when the deleted one was last; on iPadOS and macOS `settings.detail` shows the source now at the deleted row's position, or the previous one when it was last; on iOS the list is shown. When no source remains AC-22 applies instead.

### AC-20e Keychain delete error
Given the confirmation of AC-19a and a fake Keychain whose delete returns an error other than not-found
When the user activates `settings.deleteConfirm.delete`
Then the injected logger receives one entry holding the `sourceID` and the status code only, and AC-20a, AC-20b and AC-20c hold.

### AC-20b Delete removes its favorites
Given the confirmation of AC-19a
When the user activates `settings.deleteConfirm.delete`
Then every `FavoriteRecord` whose `sourceID` equals the source id is gone and `FavoriteRecord`s of other sources and with `sourceID` nil are untouched.

### AC-20c Delete removes its guide and channels
Given the confirmation of AC-19a
When the user activates `settings.deleteConfirm.delete`
Then `GuideStore.remove(sourceID:)` is called exactly once with the id, `SourceRefresher.catalogue` is rebuilt without the source's channels before the call returns to the UI, and `states[id]` is nil.

### AC-21 Deleting the playing source
Given the playing channel's `sourceID` is the deleted source
When AC-20a completes
Then the fake engine records `stop()` once and no `load(_:)`; on tvOS the injected `UserDefaults` suite no longer holds `shell.lastChannel` and the next time Live is shown 0015/AC-2b runs; on the other platforms 0010/AC-23 applies.

### AC-22 Deleting the last source
Given one source
When AC-20a completes
Then onboarding replaces the root per 0006/AC-1 and `settings.root` and, on tvOS, `shell.settingsSheet` are gone.

### AC-23 Source removed by sync
Given a `SourceRecord` that disappears from the store without a local delete
When the store change is observed
Then `GuideStore.remove(sourceID:)` is called once, the catalogue is rebuilt without it, its row is gone, the Keychain item under its `credentialKey` is deleted on this device (not-found ignored, other errors logged as AC-20e), no `FavoriteRecord` is deleted by this device, and when the playing channel's `sourceID` is that source AC-21 applies.

### AC-24 Load order per source
Given a source S finishing a load
When `SourceRefresher` processes the result
Then every channel has `sourceID == S` (0013/AC-1), `groupOrder[S]` is the `get_live_categories` names in response order for Xtream and absent for M3U, and `catalogue` is reassigned with S's channels.

### AC-24b Guide call order
Given a source S finishing a load, with a fake `GuideStore` recording calls
When `SourceRefresher` processes the result
Then after the reassignment of AC-24 the fake store received, in order, `register(epgURLs:for:)` for an M3U source (none for Xtream; 0014 resolves its guide URL), `update(channels:)` with S's tagged channels only, and `refreshIfStale(now:)`; for a load started by AC-29 the last call is `refresh(source:)` instead.

### AC-24c Xtream request order
Given an Xtream source S with a stub recording requests
When S loads
Then the stub records `accountInfo()` (`player_api.php` with no action), then `get_live_categories`, then `get_live_streams`; an `accountInfo()` failure ends the load with its `SourceLoadError` and the other two are not requested.

### AC-25 Duplicate category ids
Given an Xtream `get_live_categories` response with two categories sharing `category_id` "7" named "Sport" then "Sports HD"
When `XtreamClient.groupNames(_:)` runs and the source loads
Then no trap occurs, `groupNames` maps "7" to "Sport" (first wins), channels of category "7" carry `group` "Sport", and `groupOrder[S]` lists "Sport" once.

### AC-26 Sequential in sortOrder
Given sources A (`sortOrder` 0) and B (1) with stubbed responses where A's is delayed
When a load starts
Then B's request is not issued until A's state leaves `.loading`, `catalogue` is reassigned once after A and once after B, and `states` shows A `.loaded` while B is `.loading`.

Store changes are coalesced by a one-second debounce driven by the injected clock.

### AC-27a Source inserted
Given a loaded catalogue
When a `SourceRecord` with a non-nil `url` is inserted, locally or through sync
Then that source alone enters `.loading` within one second on the injected clock and loads; no other source issues a request.

### AC-27b URL changed
Given a loaded catalogue
When an existing record's `url` changes through sync, or locally outside this device's Save
Then that source alone enters `.loading` within one second on the injected clock and loads; when this device's Save already started that load (AC-13a, AC-13b) no second request is issued.

### AC-27c Guide URL changed
Given a loaded M3U source
When its record's `epgURL` alone changes
Then no channel request is issued and `GuideStore.refresh(source:)` is called once.

### AC-27d Name or order changed
Given a loaded catalogue
When a record's `name` or `sortOrder` alone changes
Then no request is issued and `catalogue` is reassigned once, with the new source order (0013 source order) and the new source name on its channels' source label (0010 and 0012 show it).

### AC-27e Favorite changed
Given a loaded catalogue
When a `FavoriteRecord` is inserted, deleted or changed, locally or through sync
Then `catalogue` is reassigned once with the new snapshots and no request is issued.

### AC-27f Playing channel after a reload
Given a channel playing from source S
When S reloads (AC-27b, AC-29, AC-30a) and the new list no longer holds that channel's id
Then the fake engine records no `stop()` and no `load(_:)`, and the now-playing surfaces (0010, 0015) keep showing the retained `Channel` value until the user tunes elsewhere.

### AC-28 Credential arrival
Given a source in `.waitingForCredential`
When the fake Keychain gains its item and any of these occurs: `scenePhase` becomes `.active`, `settings.root` or the Live section appears, or, on iOS, iPadOS and macOS only, 60 seconds pass on the injected clock while any source is waiting
Then the source is loaded without user action and no request was issued before the item existed.

### AC-29 Manual refresh
Given loaded sources A and B
When the user activates `settings.detail.refresh` for A (test a) or `settings.refreshAll` (test b)
Then test a reloads A once with `refresh(source:)` in place of `refreshIfStale(now:)` (AC-24) and issues nothing for B; test b reloads every source with a `url` in `sortOrder` the same way and re-checks the Keychain for waiting sources; a source already in `.loading` is skipped; during either the previous channels stay in `catalogue` and the row reads AC-5 test b.

### AC-30a Schedule
Given `Preferences.refreshInterval` of 12 hours and sources A and B loaded in this process, whose last successful loads are 13 hours (A) and 2 hours (B) old on the injected clock
When `scenePhase` becomes `.active`, or the interval elapses while the app is active
Then A is reloaded and B is not. At process start every source loads whatever its age (Scope, no channel cache); the schedule applies only to sources already loaded in this process.

### AC-30b Only manually
Given `Preferences.refreshInterval` nil and A and B as in AC-30a
When `scenePhase` becomes `.active` or 24 hours pass on the injected clock
Then neither is reloaded; a source not yet loaded in this process still loads.

### AC-30c Last-success time
Given a source that finishes a load successfully at t
When the result is processed
Then the injected `UserDefaults` suite holds t under `settings.lastLoad.<sourceId>` (read by AC-30a and by AC-5 before the first load of a process) and `SourceRecord.lastRefreshedAt` is unchanged.

### AC-31 Failed refresh keeps the list
Given a loaded source whose refresh fails
When the failure is processed
Then `catalogue` is not reassigned, the state is `.failed(e, previousCount: n)`, the fake engine records no `stop()` or `pause()`, and 0010/AC-21's banner is shown on those platforms.

### AC-32a Large source, core
Given an M3U playlist of 50 000 channels
When `M3UParser.parse`, `Channel.tagged(_:sourceID:)` and `Catalogue.init` run in sequence
Then they complete within 10 seconds in a debug `swift test` run on CI, which fails the test above that ceiling; the target of 3 seconds on the reference machine is recorded in the test output (the catalogue build alone is 0013/AC-14).

### AC-32b Large source, main actor
Given the playlist of AC-32a behind a stub
When `SourceRefresher` loads it
Then an injected hook called from parsing, tagging and the catalogue build records `Thread.isMainThread == false` for each, and `states[S]` and `catalogue` are each assigned once when the load finishes (Xcode integration test).

### AC-32c Request timeout
Given a stub that holds a source's channel request open past 30 seconds on the injected clock
When `SourceRefresher` loads it
Then the request is cancelled, the state is `.failed(.unreachable(host:), previousCount:)` with the URL's host, and the next source in `sortOrder` starts.

### AC-33 Reorder by drag
Given sources with `sortOrder` 0, 1, 2 on iOS (edit mode), iPadOS or macOS
When the user moves the third row to the first position
Then `sortOrder` values are rewritten 0, 1, 2 in the new order, no gaps and no duplicates, `catalogue` is reassigned with the new source order (0013 source order), and no request is issued.

### AC-34 Reorder on tvOS
Given the detail of the second of three sources
When the user activates `settings.detail.moveUp`
Then its `sortOrder` becomes 0 and the previous first becomes 1; `settings.detail.moveUp` is now disabled and focus is on `settings.detail.moveDown`. In general `settings.detail.moveUp` is disabled for the first source and `settings.detail.moveDown` for the last, and focus moves to the other Move button when the pressed one becomes disabled, otherwise it stays on the pressed one.

### AC-35 Equal sortOrder after a sync race
Given two sources with `sortOrder` 1
When the list and the catalogue are built
Then they are ordered by `createdAt` ascending then `id.uuidString`, and the next local reorder rewrites every `sortOrder` contiguously.

### AC-36 Preferences rows and defaults
Given no `SettingsRecord`
When the preferences are shown
Then `settings.pref.launchSection` reads "Live", `settings.pref.guideWindow` "2 hours", `settings.pref.refreshInterval` "Every 12 hours", and on tvOS only `settings.pref.swipe` reads "Changes channel"; no record is inserted by showing them.

### AC-37 Changing a preference
Given the preferences
When the user picks "Guide" for Open on launch
Then exactly one `SettingsRecord` exists with `launchSectionRaw` "guide" and `updatedAt` at the injected clock, `Preferences.launchSection` is `.guide`, and the row reads "Guide".

### AC-38 Duplicate SettingsRecords
Given two `SettingsRecord`s with `updatedAt` t1 < t2 (a sync race, ADR-0002)
When `Preferences` reads
Then it reflects the t2 record, a write goes to that record, and the t1 record is deleted; at equal `updatedAt` the record with the smaller `id.uuidString` is read and the other deleted.

### AC-39 Preference options
Given the preferences
When each option list is shown
Then Open on launch offers Live, Guide and Movies (Movies only under 0011/AC-1b, else the stored value falls back to Live without a write); Guide window offers 2, 3 and 4 hours; Refresh sources offers Every 6 hours, Every 12 hours, Every 24 hours and Only manually; Swipe up or down offers Changes channel and Shows the zap bar.

### AC-41 Open on launch takes effect
Given a `SettingsRecord` with `launchSectionRaw` "guide"
When the app launches with at least one source
Then after the launch tune (0015/AC-2a or AC-2b on tvOS) the Guide section is selected (`shell.tab.guide` on tvOS, the Guide tab on iOS, the Guide sidebar entry on iPadOS and macOS). The effects of the other three preferences are criteria of the specs listed under "Required of other specs".

### AC-40 About
Given the About row
When it is shown
Then `settings.about.version` reads "Version <CFBundleShortVersionString> (<CFBundleVersion>)".

## Edge cases and failure modes

- Offline at launch with no cache: every source is `.failed(.offline, previousCount: nil)`; rows read AC-6a; 0010/AC-20 and 0015/AC-11 show their states; the schedule retries on `.active`.
- Offline manual refresh: AC-31; the row's error line is the offline sentence.
- A source that never answers: AC-32c gives up after 30 seconds and moves on.
- Slow or huge source: AC-32; one source loads at a time (AC-26), so memory peaks for one parse. tvOS budget per 0014's edge case.
- Malformed playlist: `M3UParser` yields zero channels, `.failed(.noChannels, previousCount:)`, previous list kept.
- Malformed Xtream JSON: `XtreamError.decoding` maps to `.unreadable` (0016/AC-12).
- Credential not yet synced: AC-7, AC-14, AC-28. A Keychain read error other than not-found is `.failed(.credentialUnreadable, previousCount:)`.
- tvOS: every row and button is focusable (fixes 0004's unscrollable list); text entry through the system keyboard and the iPhone continuity keyboard; Menu steps back one level (user flow 3). Focus never lands on a disabled Move button.
- First launch with an empty store: 0006/AC-1 shows onboarding; this screen is reached only once a source exists. Deleting the last source returns there (AC-22).
- Editing the URL of an M3U source: favorites with stable ids survive (0005/AC-3); positional ids may dangle (0013 edge case). Nothing here deletes them.
- A `SourceRecord` with `url == nil` (partial sync) is AC-7a and is never selected as the first detail (AC-1).
- Save while that source is `.loading`: the running channel task is cancelled and its result discarded before the record is written; the state becomes `.loading(previousCount:)` of the last `.loaded` count.
- An unknown `kindRaw` falls back to `.m3u` (0004 edge case) and loads as a playlist.
- Credential-bearing M3U URLs (0004 open question) are shown in full only in the editable `settings.detail.url` field; rows and status lines never show a URL; log lines use 0014's `redacted(_:)`.
- Password handling: the detail never reads the stored password into a field; an empty field means "keep". Nothing derived from the password or the stream URL is set on an accessibility attribute (ADR-0003).
- Deleting while a load for that source runs: 0014/AC-18 cancels the guide task; `SourceRefresher` cancels the channel task and discards its result.
- Two devices delete and edit the same source at once: the deletion wins through sync; the editing device sees the row disappear (AC-23) and its open detail is dismissed.
- The settings panel on tvOS does not change engine state (0015/AC-12a) except AC-21.
- Entitlement lapses while the panel is open: the paywall replaces the root (ADR-0006); unsaved edits are lost.
- Dynamic Type at accessibility sizes: rows grow, status lines wrap, Save stays in the bar.
- VoiceOver: a source row reads name, kind, status and error as one element; the kind badge is not read as "M three U".
- Schema: `SettingsRecord` fields are all defaulted, no unique attribute, no relationships (ADR-0002). `SourceRecord` and `FavoriteRecord` are unchanged. The ADR named in the header records the new model and its conflict rule.
- Migration: `SettingsRecord` is an additive model in the ADR-0002 container; existing stores open with zero records and AC-36 defaults apply; no data moves.

## Test plan

`SourceRefresher`, `Preferences` and the detail's save model are `@MainActor` types with injected `URLSession` (stub), `CredentialStore` (fake), `GuideStore` (fake recording calls), `ModelContainer` (in-memory), `UserDefaults` suite, identity provider, logger, clock and `PlaybackEngine` (fake). UI tests launch with `-antenna.uiTest` and arguments naming the fake sources, their states and the fake Keychain contents. Identifiers: `settings.root`, `settings.sources`, `settings.source.<sourceId>`, `settings.source.<sourceId>.status`, `settings.source.<sourceId>.error`, `settings.addSource`, `settings.refreshAll`, `settings.footer`, `settings.detail`, `settings.detail.status`, `settings.detail.name`, `settings.detail.url`, `settings.detail.epgURL`, `settings.detail.username`, `settings.detail.password`, `settings.detail.save`, `settings.detail.cancel`, `settings.detail.error`, `settings.detail.signIn`, `settings.detail.refresh`, `settings.detail.moveUp`, `settings.detail.moveDown`, `settings.detail.delete`, `settings.deleteConfirm`, `settings.deleteConfirm.delete`, `settings.deleteConfirm.cancel`, `settings.source.<sourceId>.delete` (swipe and context-menu action), `settings.prefs` (Preferences row), `settings.about` (About row), `settings.pref.launchSection`, `settings.pref.guideWindow`, `settings.pref.refreshInterval`, `settings.pref.swipe`, `settings.pref.<name>.option.<value>` (option rows, `<value>` the raw stored value: `live`, `2`, `12`, `0`, `true`), `settings.about.version`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (per platform) | TBD |
| AC-2 | ui | TBD |
| AC-3 | ui (injected clock, fake states) | TBD |
| AC-4 | ui (parameterised over progress events) | TBD |
| AC-5 | ui (tests a and b) | TBD |
| AC-6a | ui | TBD |
| AC-6b | ui (frame on iPhone) | TBD |
| AC-7 | integration (fake Keychain) + ui | TBD |
| AC-7a | integration + ui | TBD |
| AC-8 | integration + ui | TBD |
| AC-9 | ui (injected identity provider) | TBD |
| AC-10 | ui (attribute scan for the password) | TBD |
| AC-11 | ui (iPhone and tvOS) | TBD |
| AC-12 | integration | TBD |
| AC-13a | integration (stubbed playlist, each failure) | TBD |
| AC-13b | integration (stubbed `accountInfo`, each failure, fake Keychain) | TBD |
| AC-14 | ui (tvOS) + integration | TBD |
| AC-15 | integration | TBD |
| AC-16 | integration | TBD |
| AC-17a | ui (iOS) | TBD |
| AC-17b | ui (iPadOS, macOS) | TBD |
| AC-17c | ui (tvOS) | TBD |
| AC-18 | integration (delayed stub) + ui | TBD |
| AC-18a | integration (delayed stub, each route) | TBD |
| AC-19a | ui (per entry route, both identity states) | TBD |
| AC-19b | ui | TBD |
| AC-20a | integration (fake Keychain) | TBD |
| AC-20b | integration (in-memory container) | TBD |
| AC-20c | integration (fake GuideStore) | TBD |
| AC-20d | ui (per platform, first, middle and last row) | TBD |
| AC-20e | integration (fake Keychain error, logger) | TBD |
| AC-21 | integration (fake engine) + ui (tvOS) | TBD |
| AC-22 | ui (iOS and tvOS) | TBD |
| AC-23 | integration (record removed from the container, fake Keychain, fake engine) | TBD |
| AC-24 | integration | TBD |
| AC-24b | integration (fake GuideStore call log) | TBD |
| AC-24c | integration (stub request log) | TBD |
| AC-25 | core (`groupNames`) + integration (fixture with duplicate ids) | TBD |
| AC-26 | integration (delayed stub) | TBD |
| AC-27a | integration (injected clock, local and sync insert) | TBD |
| AC-27b | integration (injected clock) | TBD |
| AC-27c | integration (fake GuideStore) | TBD |
| AC-27d | integration | TBD |
| AC-27e | integration | TBD |
| AC-27f | integration (fake engine) | TBD |
| AC-28 | integration (fake Keychain flips, each trigger) | TBD |
| AC-29 | integration (tests a and b) + ui | TBD |
| AC-30a | integration (injected clock) | TBD |
| AC-30b | integration (injected clock) | TBD |
| AC-30c | integration (injected defaults) | TBD |
| AC-31 | integration + ui (banner) | TBD |
| AC-32a | core (CI ceiling) | TBD |
| AC-32b | integration (Xcode, thread hook) | TBD |
| AC-32c | integration (injected clock, held stub) | TBD |
| AC-33 | ui (iPad drag, iPhone edit mode) + integration | TBD |
| AC-34 | ui (tvOS) | TBD |
| AC-35 | integration | TBD |
| AC-36 | ui (per platform) | TBD |
| AC-37 | integration + ui | TBD |
| AC-38 | integration | TBD |
| AC-39 | ui | TBD |
| AC-40 | ui | TBD |
| AC-41 | ui (per platform) | TBD |

Sync between devices (a preference set on iPhone appearing on Apple TV, a deletion arriving) is a manual two-device check, as 0004/AC-12.

## Dropped

- AC-19 is split into AC-19a and AC-19b; it had two Whens (open and cancel).
- AC-32 is split into AC-32a and AC-32b; the main-actor assertions cannot run under `swift test`.
- AC-17 is split into AC-17a, AC-17b and AC-17c, one per platform's way of leaving.
- AC-27 is split into AC-27a to AC-27e, one per store change; AC-27f is new.
- AC-30 is split into AC-30a, AC-30b and AC-30c.
- The navigation and logging parts of AC-20a moved to AC-20d and AC-20e; the guide call order of AC-24 moved to AC-24b.

## Open questions

- Preferences storage: synced `SettingsRecord` (assumed, matches the TiviMate research's top wish and ADR-0002's title) or per-device `UserDefaults`. The ADR decides.
- The three preferences chosen: open on launch, guide window, refresh interval, plus the tvOS swipe toggle as the "channel-switch behaviour". Alternatives considered and left out: zap bar auto-hide delay (0008), digit-entry delay (0008/AC-11), keeping the overlay open after a tune (contradicts 0007).
- Manual refresh forces the guide too (AC-29). Separate "Refresh guide" action instead?
- Delete asks for confirmation on every platform, including the iOS swipe (0004/AC-6 did not). Kept because the deletion syncs and removes favorites.
- `SourceRecord.lastRefreshedAt` is never written (AC-30c). Remove the field in the schema ADR, or write it for a later "last refreshed on any device" line?
- Should an edit that changes the URL of an M3U source warn that positional favorites may be lost?
- Xtream refresh calls `accountInfo()` on every load to feed AC-11's account line and surface expiry (0006/AC-26). One extra request per refresh; acceptable?
- One spec or three: the reviewer proposed splitting the source UI, `SourceRefresher` and Preferences. Kept as one because the UI's status lines and actions are the refresher's states and calls, and the preferences are four rows; split before implementation if the PR is too large to review.
- Synced preferences that are per-device in nature (refresh interval, the tvOS swipe toggle): the storage ADR decides whether some fields stay per device.
- Leaving an edited detail discards without asking (AC-17a to AC-17c). A "Discard changes?" prompt instead?
- `settings.detail.url` shows a credential-bearing M3U URL in full, so VoiceOver reads it aloud when focused. Mask it until edited?
- macOS has only the sidebar entry; a Settings scene on Command-comma is left out.
- AC-38 deletes duplicate `SettingsRecord`s when it reads, which can race a CloudKit import that is about to replace one; the loser holds four preference values, so the race is accepted.
- AC-19a's body names the channel count and says the guide goes from every device. Channels and guide are not synced, but every device drops them when the deleted record syncs away (AC-23), so the sentence describes what the user sees.
- Refresh interval options (6, 12, 24 hours, manual) and the default of 12 hours mirror 0014's fixed value. The provider load of a 6-hour full playlist reload for tens of thousands of channels is untested.
