# 0020. Group management: hide, lock, rename, reorder and user groups

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Blocked on: a new ADR for the three synced records (group settings, group members, passcode check value) that amends ADR-0003 for the check value. The criteria assume the records in Notes for the plan.
- Builds on specs: 0005, 0007, 0008, 0009, 0010, 0012, 0013, 0015, 0023
- Needs from other specs: 0001 (the follow-up that takes the stream link out of M3U channel ids; until it ships, AC-32 cannot save a channel from an M3U playlist into the user's own group, because the saved id would carry the provider login).
- Amends on acceptance: 0007, 0008, 0009, 0010, 0012, 0013, 0015 (group lists, group names, which group is shown after one disappears, the channel restored at launch), 0023 (a Groups row in Sources and Settings)
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-4, US-23

## Summary

For anyone whose provider sends hundreds of channel groups, and for parents who share the TV with children. Once this ships, the user can hide groups they never watch, lock groups behind a four-digit passcode, rename groups, put them in their own order, and build their own groups from the channels of several playlists. Every change syncs to the user's other devices through iCloud. It does not lock single channels, movies or series, set time limits or content ratings, or lock the whole app.

## Design

Boards: `docs/design/boards/TV-Groups.dc.html`, `TV-Groups-Locked.dc.html`, `TV-Groups-Empty.dc.html`, `TV-Groups-Members.dc.html` (tvOS); `iPad-Groups.dc.html`, `iPad-Groups-Locked.dc.html`, `iPad-Groups-Empty.dc.html` (iPadOS, macOS); `iPhone-Groups.dc.html`, `iPhone-Groups-Locked.dc.html`, `iPhone-Groups-Empty.dc.html`, `iPhone-Groups-Detail.dc.html` (iOS); `TV-Onboard-3.dc.html` (the tvOS text field reused for Rename).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-8, DR-11, DR-12, DR-13.
Not drawn: the passcode prompt while the passcode has not synced yet; the lockout countdown; setting and changing the passcode; the passcode prompt over the player; the "passcode was changed on another device" line; the reset-unavailable line; the Passcode section (Change passcode, Lock now, search hidden groups) on iPad and iPhone; a provider group's detail on iPad and iPhone; the macOS channel picker; the Apple TV member actions panel; an empty own group; a locked group focused in the Apple TV overlay; the Groups screen while every playlist waits for its login.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

A provider playlist arrives with hundreds of groups the user never watches, names they would not choose, adult channels next to the kids' ones, and an order the provider picked. Users of TiviMate, the closest competitor, name hiding, locking, renaming and reordering groups among the reasons they stay, and merging several playlists into one guide is the feature they praise most. Antenna shows every provider group as it arrives and remembers no change to that list.

## Scope

"Channel lists" below means every place that lists groups or channels: the overlay over live TV on Apple TV, the sidebar on iPad and Mac, the group buttons on iPhone, the guide, and All channels.

In:
- Hide a group: it leaves the channel lists, and stays out of search unless the user turns that on for this device.
- Lock a group behind a four-digit passcode, set once for the whole iCloud account. While locks are closed on a device, nobody can see or play a locked channel there, and a Lock now action closes them by hand.
- Change the passcode, after entering the current one.
- The Groups screen, the guide opened on a locked group, and locking another group all ask for the passcode first while locks are closed.
- Rename a provider's group or one of the user's own groups. Favorites and other settings follow the group through a rename.
- Reorder groups. Favorites and All channels always stay at the top.
- The user's own groups: create, rename, pick channels from any playlist, reorder them, delete. They behave like any other group, which is how several playlists become one guide.
- A Groups screen on every platform, opened from a Groups row in Sources and Settings (0023).
- A list of settings for groups that no longer exist in any playlist, each with a Remove button.

Out (explicitly):
- Hiding or locking movie and series categories.
- Shortcuts on group rows in the channel lists (long press, swipe, menu).
- Hiding, reordering or renumbering single channels.
- Sorting the user's own group by channel number.
- Locking the whole app, Favorites or All channels.
- Time limits and content ratings.
- A passcode on Settings itself.
- Importing group setups from other players.
- Resetting the passcode on Apple TV without another Apple device.

## User flow

Apple TV:
1. From Settings the user opens Groups. If any group is locked and locks are closed, the passcode prompt comes first.
2. The list shows All channels, every provider group, the user's own groups and New group. Beside the selected row are Rename, Hide, Lock, Move up and Move down.
3. Locking the first group asks for a four-digit passcode, twice.
4. Later, picking a locked group while watching shows the prompt. The right passcode opens it.

iPad and Mac: Sources & Settings, then Groups. The middle column lists groups and the right column edits the selected one. Rows drag to reorder; Add channels opens a channel picker.

iPhone: Settings tab, then Groups. Tapping a row opens its settings; Edit shows drag handles.

## Acceptance criteria

Ids keep their numbers from the earlier draft, so some numbers are missing and some carry a letter.

### AC-2 Hide groups you never watch
Given the user has hidden one of the provider's groups
When they look through the channel lists
Then that group and its channels are gone, the Groups screen still lists it marked hidden, its channels that are favorites stay in Favorites, and no other channel's number changes.

### AC-5 Locked channels stay out of reach
Given a locked group and locks closed on this device
When the user browses, searches, opens the guide, flips channels or types a channel number
Then the group shows a lock, none of its channels is shown, counted, numbered or played, and every other channel keeps its number.

### AC-8 Give a group your own name
Given a provider's group or one of the user's own groups
When the user gives it a new name
Then every screen shows the new name, and favorites, order and the group being watched stay as they were.

### AC-9 Put groups in your order
Given the Groups screen
When the user moves a group (by dragging on iPhone, iPad and Mac, or with Move up and Move down on Apple TV)
Then every screen lists groups in the new order with Favorites and All channels first, and the channels inside a provider's group keep the provider's numbering, then playlist order.

### AC-18 Lock a group with a passcode
Given no passcode has been set on this iCloud account
When the user locks a group and types the same four digits twice
Then the group is locked on every device of the account, it stays open on this device for now, and the digits are not saved, synced or written to any log.

### AC-20b Unlock with the passcode
Given locks closed on this device and a locked group
When the user picks that group in a channel list
Then the passcode prompt appears, and the right passcode opens the locks on this device and shows the group's channels while whatever is playing keeps playing.

### AC-21b Guessing the passcode is slow
Given the passcode prompt
When a wrong passcode is entered several times in a row
Then the prompt refuses input for a while, each further run of wrong entries makes the wait longer, and closing and reopening the app does not cut it short.

### AC-23 Locks close again on their own
Given the user has opened the locks on this device
When they choose Lock now, the app is reopened, or the app or an idle Apple TV has been left alone for a while
Then the locks close and locked channels are out of reach again.

### AC-24 Reset a forgotten passcode
Given the passcode prompt on iPhone, iPad or Mac
When the user chooses Forgot passcode and confirms with the device's passcode or Mac login password, Face ID or Touch ID
Then they set a new passcode, every locked group stays locked, and the locks open on this device; on Apple TV the prompt says to reset it on an iPhone, iPad or Mac and offers no reset.

### AC-25a A channel that gets locked stops playing
Given a channel is playing and locks are closed
When that channel becomes locked, from this device, from another device, or because the locks closed
Then playback pauses and the passcode prompt covers the video; the right passcode resumes it, and closing the prompt switches to the first channel the user may watch, or closes the player when there is none.

### AC-32 Build your own group from any playlist
Given channels from two playlists
When the user creates a group, names it and picks channels from both playlists
Then the channel lists and the guide show it like any other group, with its channels in the order the user chose, leaving out any channel that is not currently loaded.

### AC-40 Changes follow you to every device
Given the user hides one group, renames another, locks a third and creates their own group on one device
When their other device, signed into the same iCloud account, is online
Then it shows all four changes, and its locks stay closed until the passcode is entered there.

## Edge cases

- Offline or signed out of iCloud: changes apply on this device and sync once it is back.
- A request to play a locked channel from outside the channel lists (the channel restored at launch, the lock screen, Control Center) shows the passcode prompt instead.
- An empty name brings back the provider's name for a provider group; the user's own group refuses it.
- Two different entries while setting the passcode lock nothing; the user starts again.
- A playlist still loading, failed, or waiting for its login to sync: its groups are absent, and its group settings are neither applied nor offered for removal.
- The provider renames a category: the old settings appear in the list of groups that no longer exist, and the renamed group starts with none.
- A group was locked on another device and the passcode has not reached this one yet: the prompt says it is waiting for iCloud and shows no digit keys.
- Two offline devices each set a first passcode: the earlier one wins, and the other device says the passcode was changed elsewhere.
- Deleting a playlist removes its group settings and its channels from the user's own groups; the user's groups themselves stay.
- A locked channel that is also a favorite or in the user's own group stays out of reach everywhere.
- The subscription ends (ADR-0006): the paywall replaces these screens and every setting is kept.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-2 | core |
| AC-5 | core |
| AC-8 | integration |
| AC-9 | core |
| AC-18 | integration |
| AC-20b | ui |
| AC-21b | integration |
| AC-23 | integration |
| AC-24 | ui |
| AC-25a | integration |
| AC-32 | core |
| AC-40 | device |

## Open questions

- Should the passcode check value sync through iCloud (chosen here), or should each device keep its own passcode? The ADR this spec waits on settles it; a passcode per device changes AC-18 and AC-40.
- Decided: the reset asks only for the device's own passcode or login (AC-24), so a child who knows the family iPad's passcode can reset the lock. The owner can ask for a stronger check.

## Notes for the plan

- Records (app layer, ADR-0002 rules): a group record (kind, source id, provider name, custom name, hidden, locked, sort order, created at), a member record shaped like the favorite record, and a passcode record holding a salt and a check value (the verifier). Migration is additive. Malformed records are ignored and no record can hide or lock Favorites.
- The passcode is never stored, synced or logged. The verifier is built in `Apps/Shared/Persistence` with CryptoKit because AntennaCore stays on Foundation (ADR-0005). The ADR must say that four digits are only 10 000 values, so the verifier stops casual reading of the store and nothing more.
- The verifier syncs because tvOS Keychain items do not: a parent sets the passcode on the phone and the Apple TV is locked without anyone touching it. The open-locks state lives in memory per device; the search toggle and lockout state live in this device's `UserDefaults`.
- Group keys in identifiers never contain a stream URL (ADR-0003).
- 0013's `Catalogue` gains a group policy and a locks-open flag, both defaulting so that with no rules every query equals today's result. Rules for sources that have not finished loading are neither applied nor orphans.
- Hiding never renumbers; a locked channel's number is hidden while locks are closed. All channels can be hidden but not locked.
- Duplicate rules, user groups and passcode records: the earliest `createdAt` wins; the rest show as orphans (rules) or are deleted (passcode records).
- When the current group is hidden, locked or deleted, it falls back to the first visible unlocked group, else Favorites, never one that needs the prompt.
- Starting values from the earlier draft: lockout after five wrong entries, 30 seconds doubling up to 5 minutes, per device; locks close after 15 minutes in the background or 15 minutes without remote input on Apple TV.
- Performance targets the owner set: the policy build at most 1.5 times the 0013 build at 50 000 channels; picker filtering within 100 ms; the Groups screen's first frame within one second with 400 groups.

## Dropped

- Moved to the implementation plan: AC-1, AC-4, AC-10, AC-11, AC-12b, AC-16, AC-16b, AC-16c, AC-16d, AC-17, AC-19b, AC-20a, AC-20d, AC-22, AC-26, AC-26b, AC-27, AC-31, AC-33b, AC-35, AC-36, AC-37, AC-38, AC-38b, AC-39, AC-42, AC-43, AC-43b, AC-43c, AC-45, AC-46, AC-47, AC-48.
- Merged into AC-2: AC-2b, AC-3, AC-28.
- Moved to Edge cases: AC-18b, AC-44.
- Moved to Scope: AC-19a, AC-41.
- Merged into AC-5: AC-7.
- Merged into AC-8: AC-29, AC-29b.
- Merged into AC-9: AC-14, AC-15, AC-30.
- Merged into AC-18: AC-18c.
- Merged into AC-20b: AC-6, AC-20c.
- Merged into AC-21b: AC-21a, AC-21c.
- Merged into AC-23: AC-23b.
- Merged into AC-25a: AC-25b, AC-25c.
- Merged into AC-32: AC-12, AC-13, AC-33, AC-34.
- Split earlier (kept for history): AC-19 into AC-19a and AC-19b; AC-20 into AC-20a, AC-20b, AC-20c and AC-20d; AC-21 into AC-21a, AC-21b and AC-21c; AC-25 into AC-25a, AC-25b and AC-25c.
- Clauses split off earlier (kept for history): AC-2b from AC-2, AC-12b from AC-12, AC-16b, AC-16c and AC-16d from AC-16, AC-18b and AC-18c from AC-18, AC-26b from AC-26, AC-29b from AC-29, AC-38b from AC-38, AC-43b from AC-43.
- AC-37 test a (no source at all): unreachable, because onboarding shows first.
- AC-4's Favorites clause: no stored record can produce such a rule.
