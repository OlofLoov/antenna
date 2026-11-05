# 0027. Programme reminders

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Builds on specs: 0007, 0008, 0009, 0010, 0012, 0013, 0014, 0015, 0023, 0025
- Needs from other specs: 0009 shows Remind me on future programmes in the guide panel; 0007 makes the overlay's next programmes selectable rows; 0012 takes reminders into scope with a bell on future guide results; 0023 adds a Reminders row with the upcoming count; 0025 places Remind me after Watch in its guide.
- Blocked on: an ADR that adds reminders to the iCloud sync of ADR-0002, together with the records 0029 adds. The criteria assume reminders sync; the alternative is reminders that stay on the device where they were set.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-16

## Summary

For anyone who finds a programme in the guide that starts later and does not want to miss it. Once this ships, they tap Remind me on that programme in the guide on Apple TV, or in Search on iPhone, iPad and Mac, and a few minutes before it starts their iPhone, iPad or Mac shows a notification that plays the channel when tapped. A reminder set on one device shows up on every device on the same iCloud account; an Apple TV shows it as a banner, but only while Antenna is open. It does not record anything, switch channels by itself, or remind about movies or series.

## Design

Boards: `docs/design/boards/iPhone-Reminders.dc.html`, `docs/design/boards/iPhone-Reminder-Banner.dc.html`, `docs/design/boards/TV-Reminder-Banner.dc.html`, `docs/design/boards/TV-Guide.dc.html`, `docs/design/boards/TV-Guide-Future.dc.html`, `docs/design/boards/iPhone-Search.dc.html`, `docs/design/boards/iPad-Search.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13.
Not drawn: the set state of Remind me; the toggle on `TV-Guide-Future` and on the overlay's next rows; the bell on search result rows; the iPad and Mac banner; the Mac list row; the empty list; the Apple TV Reminders page with its lead-time row and note; the remove confirmation; the Allow notifications row.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

A viewer who spots tonight's match in the guide at lunch has no way to be told when it starts. On an Apple TV nothing can wake them up, because Apple TV apps cannot show notifications. TiviMate users set reminders from its guide and wish they followed them from phone to TV; Antenna already has the guide (0014) and iCloud sync (ADR-0002) to do that.

## Scope

In:
- A Remind me button on programmes that have not started: in the Apple TV guide (0009), on the "next" programmes in the Apple TV channel overlay (0007), and on guide results in Search on iPhone, iPad and Mac (0012). 0025 adds the same button to its guide.
- Reminders sync through iCloud and are listed on every device; each device delivers them in its own way.
- A notification on iPhone, iPad and Mac; tapping it plays the channel.
- A banner inside the app while Antenna is open, on every device. On Apple TV this is the only way a reminder appears.
- Keeping up with guide changes: a programme that moves takes its reminder with it; one that disappears is marked and still reminds.
- A Reminders page in Settings: the list, removing reminders, how many minutes before start to remind, and a notice when notifications are off.
- Clearing out reminders for programmes that have ended or whose source was deleted.

Out (explicitly):
- Recording, or switching to the channel by itself at start time.
- Reminders for movies, series episodes or catch-up.
- Repeating reminders, such as every episode of a show.
- Notifications that break through Focus or Do Not Disturb.
- Notification options beyond the lead time, such as sound or muting a channel.
- Reminders on Apple TV while Antenna is closed; tvOS offers no way to do it.
- Syncing the lead time between devices.
- Widgets, Live Activities and the Apple TV Top Shelf.
- The guide on iPhone, iPad and Mac itself (0025).
- What the app shows while the paid unlock is missing (0024).

## User flow

1. Apple TV: in the guide the user highlights a programme later tonight and selects Remind me; the button now reads "Reminder set". The same works on a next programme in the channel overlay.
2. iPhone, iPad, Mac: in Search a guide result that has not started shows a bell; tapping it sets the reminder. The first time, the system asks whether Antenna may send notifications.
3. The reminder appears under Settings › Reminders on every device on the same iCloud account.
4. Five minutes before start (the default), iPhone, iPad and Mac show a notification; tapping it plays the channel. If Antenna is already open, a banner with Watch and Dismiss shows instead.
5. Apple TV, while Antenna is open: a banner appears top right with Watch highlighted. Select plays the channel; Menu closes the banner.
6. If the guide moves the programme, the reminder moves too and the list says where it moved from. If the programme drops out of the guide, the row says "No longer in the guide" and the reminder still goes off at the original time.
7. In Settings › Reminders the user removes reminders and changes how early they go off.

## Acceptance criteria

### AC-1a Remind me appears only before a programme starts
Given the user is looking at a programme in the Apple TV guide, a next programme in the Apple TV channel overlay, or a guide result in Search on iPhone, iPad or Mac
When the programme has not started yet
Then a Remind me button is offered, reachable with the remote on Apple TV; programmes on now, past programmes and empty slots have none.

### AC-1b Set a reminder in one tap
Given a programme that has not started and has no reminder
When the user chooses Remind me in any of those places
Then the reminder is saved, the button reads "Reminder set", the user stays where they were, and nothing starts playing.

### AC-1c Remove a reminder anywhere
Given a reminder the user has set
When they turn the button off or remove the reminder in Settings › Reminders (confirming on Apple TV and Mac)
Then the reminder disappears from every device and no notification or banner arrives for it.

### AC-5a Choose how early reminders go off
Given the Reminders page in Settings on one device
When the user picks how long before start to be reminded
Then they can pick at start, 5, 10, 15 or 30 minutes, 5 is chosen until they pick, and every upcoming reminder on this device follows the new choice while other devices keep their own.

### AC-6a A notification before the programme starts
Given an iPhone, iPad or Mac where Antenna may send notifications, and a reminder set on this or another device
When the chosen number of minutes before start arrives
Then a notification shows the programme title and "Starts at <time> on <channel>" ("Starts now" when reminding at start); a reminder set closer to start than that goes off at once.

### AC-7a Permission is asked only when it is needed
Given an iPhone, iPad or Mac where the user has never been asked about notifications
When they set their first reminder
Then the reminder is saved first, the system asks once, and the reminder stays saved whatever they answer; Antenna never asks at launch or when Settings opens.

### AC-7e The app says when reminders cannot notify
Given Antenna cannot notify on this device: notifications are off, the user has not been asked yet, or it is an Apple TV
When the user opens Settings › Reminders
Then a notice says reminders show only while Antenna is open, with a way to allow notifications where the device has one; once allowed, the notice goes away and upcoming reminders notify.

### AC-8a Watch plays the channel
Given a reminder has gone off, as a notification on iPhone, iPad or Mac or as a banner on any device
When the user taps the notification or chooses Watch
Then Antenna opens Live and plays the channel, switching to All channels if the group on screen lacks it, leaving it alone if it is already playing, and waiting for its source to load when Antenna was closed; if the channel cannot be found (source or login not synced, or channel gone), Live opens and nothing plays.

### AC-9a A banner while Antenna is open
Given Antenna is open on any screen, or the user returns to it while a programme whose reminder went off unseen is still on (on iPhone, iPad and Mac only when notifications are off)
When the reminder goes off or the user returns
Then a banner with the title, start time, channel, Watch and Dismiss appears once over the screen without pausing what is playing, with Watch highlighted on Apple TV; Dismiss, Menu on Apple TV, or a short timeout close it and leave the screen as it was.

### AC-12a Reminders follow a programme that moves
Given a reminder for a programme that a guide update moves to a new time on the same channel
When the updated guide has loaded
Then the reminder goes off for the new time and its row in Settings › Reminders reads "Moved from <old start>".

### AC-12b Reminders survive a programme leaving the guide
Given a reminder whose channel's guide has loaded, covers the reminder's time, and no longer lists the programme
When the updated guide has loaded
Then the reminder keeps its time and still goes off, its row reads "No longer in the guide", and the note clears if a later guide lists the programme again; a guide that failed to load or does not reach that far changes nothing.

### AC-15a See every upcoming reminder in one list
Given upcoming reminders set on this or other devices on the same iCloud account
When the user opens Settings › Reminders
Then each reminder appears once, soonest first, with title, day, start and end time and channel; ended programmes are gone, the header shows how many there are, and with none the page says how to set one.

## Edge cases

- Two devices on one account both remind about the same programme. That is intended.
- An Apple TV reminds only while Antenna is open; the notice in AC-7e says so.
- Two devices with different versions of the guide may move one reminder to different times. The list can change once before the devices agree.
- A programme that moves more than 6 hours counts as dropped, and the reminder goes off at the old time.
- Not signed in to iCloud: the reminder is saved, listed and goes off on this device with no error.
- Deleting a source removes its reminders on every device.
- Paid unlock lapsed: scheduled notifications still arrive; tapping one shows the paywall, not the channel.
- Time zone or daylight saving change: times show in the current zone and the reminder goes off at the same moment.
- Offline: setting, receiving and removing reminders need no network.
- Several channels sharing one guide listing share the reminder; Watch plays the first in All channels order.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1a | ui |
| AC-1b | integration + ui |
| AC-1c | integration + ui |
| AC-5a | integration + ui |
| AC-6a | integration |
| AC-7a | integration |
| AC-7e | ui |
| AC-8a | ui |
| AC-9a | ui |
| AC-12a | core + integration |
| AC-12b | core + integration |
| AC-15a | ui + device (sync from a second device; CloudKit cannot run in CI) |

## Open questions

- Should reminders sync, or stay on the device where they were set? This is the blocking ADR; staying local would change AC-1c, AC-6a and AC-15a.
- The lead time is set per device. Syncing it would change AC-5a and needs a synced settings record.
- Dropped programmes still remind (AC-12b), because guide gaps are common and the channel probably still shows the programme. Cancelling them instead would change AC-12b.
- The Apple TV banner takes the highlight from whatever the user was doing. A banner that waits for play/pause instead would change AC-9a.
- Should the banner wait while the user is typing a channel number on Apple TV? Can be decided in the plan.
- Should a reminder set closer to start than the lead time warn the user instead of going off at once? That would change AC-6a.

## Notes for the plan

- The amendments under Needs from other specs land as a docs commit ahead of the code. On tvOS the toggle sits right of Watch in the 0009 panel; the 0023 row hides its count at zero.
- The record holds source id, guide id, start, stop, title, channel name, the start it moved from and created-at. Identity is (source id, guide id, start). No channel id, URL or stream data. ADR-0002 rules apply: every property optional or defaulted, no unique attribute, no relationship.
- Duplicates of one identity are shown and delivered once, keeping the earliest created-at, then the lowest id; the toggle and list removal delete every copy.
- No record field, notification text, banner, accessibility attribute or log line carries the stream URL, credentials or channel id (ADR-0003). Reminders make no network requests.
- Guide matching order: a programme at the same start keeps the reminder and updates its title and stop; else the same folded title nearest the start within 6 hours, the earlier on a tie, moves it and keeps the first original start; else, with the guide loaded and covering the start, it is not listed; otherwise nothing changes.
- A reminder hides once its stop passes (start + 3 h with no stop) and is deleted 10 minutes later, so one device with a fast clock does not delete it for every device.
- A reminder whose source has not synced yet is kept, listed with its stored channel name and delivered. Only an observed source deletion removes reminders, as in 0014.
- iOS keeps at most 64 pending notifications: schedule the earliest 64 and top up as they fire or are removed.
- Schedule, matching, text and merge logic live in AntennaCore with no UserNotifications import (ADR-0005); tvOS has no notifier. Watch uses the inline playback path of 0010 and 0012, no second tune path. Lead time and the missed-banner marker live per device in user defaults. The banner closes itself after 20 seconds.
- While the paywall reports locked (0024), a tap or Watch plays nothing and no banner shows; scheduled notifications stay. Board deviations: the iPhone banner's Watch is 36 pt tall with a 44 pt hit area (DR-5); "Open Settings" is accent because it is a link (DR-3).

## Dropped

- Split earlier (kept for history): AC-4 into AC-4a and AC-4b, because the schema check and the merge rule fail for different reasons; AC-19 into AC-19a and AC-19b, because it had two Givens; the denied notice in AC-7b moved to AC-7e.
- Dropped earlier: AC-15d, because the Settings row belongs to 0023; AC-22 and AC-22b, because the paywall screens belong to the paywall spec (replaced by AC-22c).
- Merged into AC-1a: AC-1d, AC-2a, AC-3a.
- Merged into AC-1b: AC-2b, AC-3b.
- Merged into AC-1c: AC-6c, AC-15b.
- Moved to Edge cases: AC-14.
- Merged into AC-5a: AC-5b, AC-5c, AC-5d.
- Merged into AC-6a: AC-6b.
- Merged into AC-7a: AC-7b.
- Merged into AC-7e: AC-7c, AC-7d, AC-7f.
- Merged into AC-8a: AC-8b, AC-8c, AC-9b, AC-10b.
- Merged into AC-9a: AC-9c, AC-9d, AC-9e, AC-10a, AC-10c, AC-11.
- Merged into AC-12b: AC-12c.
- Merged into AC-15a: AC-13, AC-15c, AC-16.
- Moved to the implementation plan: AC-4a, AC-4b, AC-6d, AC-8d, AC-8e, AC-10d, AC-10e, AC-11b, AC-12d, AC-12e, AC-12f, AC-12g, AC-15e, AC-16b, AC-17, AC-18, AC-19a, AC-19b, AC-20, AC-20b, AC-21, AC-22c.
