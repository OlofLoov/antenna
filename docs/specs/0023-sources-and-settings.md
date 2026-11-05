# 0023. Sources and Settings: edit, delete, refresh and app preferences

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Follow-up ADR: the ADR-0003 amendment for Apple TV that 0006 names. This spec assumes a login typed on an Apple TV stays there; the other outcome changes only the wording of AC-14 and the iCloud footer.
- Follow-up ADR: where app preferences are stored. This spec assumes one synced preferences record; if the ADR picks per-device storage, AC-37 changes where the values live and nothing else.
- Builds on specs: 0004, 0005, 0006, 0010, 0013, 0014, 0015, 0016
- Supersedes: 0004 AC-6 (delete), 0004 AC-7 (what a source row shows), the "first time" part of 0004 AC-9 (when sources load), 0004 AC-10 and 0004 AC-11 (where a source's load result is kept). Also fixes two of 0004's known gaps: no delete on Apple TV or Mac, and channels loaded once per launch.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-5, US-2, US-7

## Summary

For anyone who has added an IPTV source and later needs to look after it. Once this ships, the user can see whether each source loaded and when, fix its link or its Xtream login (a provider's server address, username and password), sign in on an Apple TV that lacks the login, reorder sources, refresh them by hand, and delete one along with its favorites and guide. Sources also refresh on their own, on a schedule and whenever another device changes them, and the user can set a few preferences such as which screen opens at launch. It does not add sources (onboarding does that), change a source's type, keep channel lists between launches, or manage the purchase.

## Design

Boards: `docs/design/boards/TV-Settings.dc.html`, `TV-Settings-Delete.dc.html`, `TV-Settings-Preferences.dc.html` (tvOS); `iPad-Settings.dc.html`, `iPad-Settings-Delete.dc.html` (iPadOS, macOS); `iPhone-Settings.dc.html`, `iPhone-Settings-Detail.dc.html`, `iPhone-Settings-Delete.dc.html` (iOS); `TV-Onboard-SignIn.dc.html` (reused for Sign in on this Apple TV).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15.
Not drawn: the details while Save runs; the error line under the form; a source row while loading; the Stalker row and the waiting-for-iCloud row; the signed-out iCloud footer; the "not loaded yet" status block and its failed variant; the M3U details form; the Preferences and About panes on iPad and Mac; the iPhone preference option screen; the Apple TV preference option list; the Sign in on this Apple TV form; iPhone edit mode with drag handles.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Once a source is added there is no way to fix a typo in its link, enter a password the provider changed, see whether it loaded, or remove it on Apple TV or Mac. Channels load once per launch, so a source added on iPhone shows nothing on an Apple TV that has been running since morning. The live TV screens assume something keeps every source loaded and the guide fed, and nothing does that yet.

## Scope

In:
- A Sources and Settings screen on every platform: the Settings tab on iPhone, the sidebar on iPad and Mac, the gear on Apple TV.
- A list of sources in the user's order, each with its channel count, guide days, when it last loaded on this device, and any problem.
- A source's details: what it holds, and editable name, link, guide link and Xtream login, checked against the server before saving.
- Sign in on this Apple TV, for an Xtream source whose login has not reached the device.
- Delete with confirmation on every platform, removing the source, its login, its favorites, its guide and its channels.
- Reorder sources by dragging, or with Move up and Move down on Apple TV.
- Loading every source: at launch, when another device changes one, when a login arrives, by hand, and on a schedule.
- Preferences: which screen opens at launch, how many hours the guide shows, how often sources refresh, and on Apple TV whether swiping changes channel.
- An About row with the app version.

Out (explicitly):
- Adding a source (onboarding, 0006, owns the form; this screen opens it).
- Group management (0020), guide sources per playlist (0021) and importing a playlist file (0037); each adds its own row to this screen when accepted.
- Keeping channel lists between launches; every launch loads every source again.
- Changing a source's type.
- Stalker portals, beyond listing and deleting them.
- The crash on a repeated Xtream category id, which is a bug fix in the Xtream client (0003, 0016).
- The paywall, restoring the purchase and managing it.
- Zap bar timing, guide zoom and other screens' fine-tuning.
- Diagnostics and logs export.

## User flow

iPhone:
1. The Settings tab lists the sources with their status, Add a source and Refresh all, then Preferences with their current values, then About.
2. Tapping a source opens its details with Refresh now and Delete source. Save appears once a field changes; it checks the change, then returns to the list, where the row shows it refreshing.
3. Swiping a row offers Delete, which asks first. Edit shows drag handles for reordering.

iPad and Mac: Sources and Settings in the sidebar shows the list in the middle and the selected source's details on the right. Rows drag to reorder; Delete is in the details, the row's menu and on the Delete key, and always asks first.

Apple TV:
1. The gear opens the panel over the current screen, and the live picture keeps playing. Moving along the sources shows each one's details beside it.
2. In the details, fields open the system keyboard, and the buttons are Refresh now, Move up, Move down and Delete source. A source without a login on this Apple TV shows Sign in on this Apple TV first.
3. Menu steps back one level at a time and discards unsaved changes.

## Acceptance criteria

Ids keep their numbers from the earlier draft, so some numbers are missing and some carry a letter.

### AC-3 See how each source is doing
Given sources that are loaded, loading, failed, waiting for their login, waiting for iCloud, or a Stalker portal
When the user opens Sources and Settings
Then each source is listed in the user's order with its name, its type, and one plain status line: the channel count, guide days and when it last loaded, or what it is waiting for, or why it failed, and no row shows a source's link.

### AC-10 Your password stays hidden
Given an Xtream source with a saved login
When the user opens its details
Then the username is filled in and the password field is empty, leaving it empty keeps the saved password, and the saved password appears in no field, label or log.

### AC-13a Fix a source's link or login
Given a source's details with a changed link or login
When the user saves
Then the change is checked against the server and, only if it works, saved and the source reloads; otherwise the reason is shown and nothing changes.

### AC-14 Sign in on this Apple TV
Given an Xtream source whose login has not reached this Apple TV
When the user opens its details, chooses Sign in on this Apple TV and enters a login that works
Then the source loads, its guide follows, and its row stops saying it is waiting.

### AC-20a Delete a source and everything that came with it
Given a source with channels, favorites and a guide
When the user chooses Delete, reads the confirmation that says what will go, and confirms
Then the source, its login, its favorites, its guide and its channels are gone from this device and, through iCloud, from the user's other devices, and if one of its channels was playing, playback stops.

### AC-27a Changes from other devices show up by themselves
Given the app is open with its sources loaded
When another device adds, edits, renames, reorders or deletes a source
Then this device shows the change without the user doing anything, and sources that did not change keep their channels without reloading.

### AC-29 Refresh by hand
Given loaded sources
When the user chooses Refresh now on one source or Refresh all
Then that source, or every source in order, loads again together with its guide, and the channels stay available while it loads.

### AC-30a Sources refresh on a schedule
Given a refresh interval of 12 hours and two sources last loaded 13 and 2 hours ago
When the user comes back to the app
Then the 13-hour-old source reloads and the other does not; with "Only manually" chosen, neither reloads.

### AC-31 A failed refresh keeps your channels
Given a loaded source whose refresh fails, for example because the device is offline
When the failure comes in
Then the channels already loaded stay, whatever is playing keeps playing, and the source's row shows the channel count with a line saying the refresh failed and why.

### AC-33 Put sources in your order
Given three sources
When the user moves the last one to the top (by dragging, or with Move up on Apple TV)
Then the list and the channels from those sources follow the new order on every device, and nothing reloads.

### AC-37 Choose how the app behaves
Given the preferences, which start at Live, 2 hours, every 12 hours and swipe changes channel
When the user changes one
Then the row shows the new value, the change takes effect on this device, and it reaches the user's other devices through iCloud.

## Edge cases

- A changed name saves at once without a check. A link that is not a web address, or a source already added, is refused with a message.
- Cancel on the delete confirmation changes nothing.
- A login arrives through iCloud for a source waiting for it: the source loads by itself.
- Only Xtream sources offer Sign in on this Apple TV; other sources whose login cannot reach the Apple TV say so.
- Offline at launch: every source shows the offline reason and is tried again when the app comes back to the front.
- A source that never answers: the app gives up after a while and moves on to the next one.
- A huge playlist: one source loads at a time, and the screens stay responsive while it does.
- A broken playlist or provider response: the source shows why, and any channels it had stay.
- Signed out of iCloud: the list footer says sources stay on this device, and deleting removes the source from this device only.
- Deleting the last source returns the user to onboarding.
- One device deletes a source while another is editing it: the deletion wins, and the editing device's details close.
- A changed link on an M3U source: favorites with a stable channel id survive; those that depended on the channel's position in the playlist may not.
- The subscription ends while Settings is open: the paywall replaces it and unsaved changes are lost (ADR-0006).

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-3 | ui |
| AC-10 | ui |
| AC-13a | integration |
| AC-14 | ui |
| AC-20a | integration |
| AC-27a | integration |
| AC-29 | integration |
| AC-30a | integration |
| AC-31 | integration |
| AC-33 | integration |
| AC-37 | integration |

## Open questions

- Synced preferences (assumed) or kept per device? The follow-up ADR decides; the refresh interval and the Apple TV swipe setting are per device in nature. Changes where AC-37 stores values, not what the user sees on this device.
- Refresh now also refreshes the guide. Should there be a separate Refresh guide action? Can be decided in the plan.
- Leaving edited details discards changes without asking. Should it ask "Discard changes?" first? Can be decided in the plan.
- The link field shows an M3U link in full, including any password in it, so VoiceOver reads it aloud. Should it be masked until edited? Can be decided in the plan.
- The reviewer proposed three specs: the source screens, the loading loop and the preferences. Kept as one because the status lines and actions are the loop's states and calls. Split before implementation if the PR is too large.

## Notes for the plan

- The previous revision of this spec (git history) holds the agreed texts: status lines, error sentences (0006's), the delete confirmation wording, the iCloud footer, and the preference option lists. Use them.
- Source loading lives in an app-layer `SourceRefresher` that loads one source at a time in the user's order, tags each channel with its source, rebuilds the catalogue after each source, and calls the guide store in 0014's order. 0013 and 0014 wait on it, and several screens read its per-source states.
- Xtream loads call account info, then categories, then streams; an account failure stops the load.
- Load results are never written to the source record (this supersedes 0004); the last successful load time per source lives in this device's `UserDefaults`. At launch every source loads whatever its age; the schedule applies only to sources already loaded in this process.
- Changes this device made are handled once: the store observer ignores a deletion it already handled and a link change whose load is already running. A save on a loading source cancels that load first.
- Deleting a source deletes its Keychain item and its favorite records and calls the guide store's remove once. A source removed by sync deletes the Keychain item on this device but never the favorites, which the deleting device already removed. Keychain errors log only the source id and the status code.
- Preferences record (pending ADR, ADR-0002 rules): every field defaulted, no uniqueness; on duplicates the newest is read and the rest deleted. Showing preferences inserts nothing. Other specs read these preferences: 0008 (swipe), 0009 (guide window), 0014 (refresh interval), 0010 and 0015 (screen opened at launch).
- Large-source targets from the earlier draft: a 50 000-channel M3U parses, tags and builds within 10 seconds in debug CI, off the main thread; a request is cancelled after 30 seconds.
- A channel that disappears from a reloaded source keeps playing until the user tunes elsewhere.
- No source link or host appears in a row, label or identifier; log lines use 0014's `redacted(_:)` (ADR-0003).

## Dropped

- Moved to the implementation plan: AC-9, AC-11, AC-17a, AC-17b, AC-17c, AC-18, AC-18a, AC-20d, AC-20e, AC-22, AC-24, AC-24b, AC-24c, AC-26, AC-27f, AC-30c, AC-32a, AC-32b, AC-32c, AC-35, AC-38, AC-39, AC-40, AC-41.
- Moved to a bug fix in the Xtream client (0003, 0016): AC-25 (a repeated category id no longer crashes the app).
- Merged into AC-3: AC-1, AC-2, AC-4, AC-5, AC-6a, AC-7, AC-7a, AC-8.
- Moved to Edge cases: AC-12, AC-15, AC-16, AC-19b, AC-28.
- Merged into AC-13a: AC-13b.
- Merged into AC-20a: AC-19a, AC-20b, AC-20c, AC-21.
- Merged into AC-27a: AC-23, AC-27b, AC-27c, AC-27d, AC-27e.
- Merged into AC-30a: AC-30b.
- Merged into AC-31: AC-6b.
- Merged into AC-33: AC-34.
- Merged into AC-37: AC-36.
- Split earlier (kept for history): AC-17 into AC-17a, AC-17b and AC-17c; AC-19 into AC-19a and AC-19b; AC-27 into AC-27a, AC-27b, AC-27c, AC-27d and AC-27e; AC-30 into AC-30a, AC-30b and AC-30c; AC-32 into AC-32a and AC-32b, because the main-actor checks cannot run under `swift test`.
- Clauses split off earlier (kept for history): AC-20d and AC-20e from AC-20a, AC-24b from AC-24.
