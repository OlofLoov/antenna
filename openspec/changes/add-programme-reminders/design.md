# Design

## Context

Boards: `openspec/specs/design-system/boards/iPhone-Reminders.dc.html`, `iPhone-Reminder-Banner.dc.html`, `TV-Reminder-Banner.dc.html`, `TV-Guide.dc.html`, `TV-Guide-Future.dc.html`, `iPhone-Search.dc.html`, `iPad-Search.dc.html`.

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums".

Not drawn yet: the set state of Remind me, the toggle on `TV-Guide-Future` and on the overlay's next rows, the bell on search result rows, the iPad and Mac banner, the Mac list row, the empty list, the Apple TV Reminders page with its lead-time row and note, the remove confirmation, and the Allow notifications row.

## Goals / Non-Goals

**Goals:**
- Schedule, matching, text and merge logic in AntennaCore, testable without UserNotifications.
- One synced record per reminder that carries no stream data.

**Non-Goals:**
- A notifier on tvOS. Apple TV shows reminders only as in-app banners.
- A second tune path. Watch reuses the inline playback path of live TV and search.
- Network requests of any kind for reminders.

## Decisions

- The amendments to other changes land as a docs commit ahead of the code. On tvOS the toggle sits right of Watch in the guide panel. The Settings row hides its count at zero.
- The record holds source id, guide id, start, stop, title, channel name, the start it moved from, and created-at. Identity is (source id, guide id, start). No channel id, URL or stream data. As CloudKit sync requires, every property is optional or defaulted, with no unique attribute and no relationship.
- Duplicates of one identity are shown and delivered once, keeping the earliest created-at, then the lowest id. The toggle and list removal delete every copy.
- No record field, notification text, banner, accessibility attribute or log line carries the stream URL, credentials or channel id.
- Guide matching order: a programme at the same start keeps the reminder and updates its title and stop. Otherwise the same folded title nearest the start within 6 hours, the earlier on a tie, moves it and keeps the first original start. Otherwise, with the guide loaded and covering the start, it is marked not listed. Otherwise nothing changes.
- A reminder hides once its stop passes (start plus 3 h with no stop) and is deleted 10 minutes later, so one device with a fast clock does not delete it for every device.
- A reminder whose source has not synced yet is kept, listed with its stored channel name and delivered. Only an observed source deletion removes reminders, as `guide-data` does for programmes.
- iOS keeps at most 64 pending notifications. Schedule the earliest 64 and top up as they fire or are removed.
- Lead time and the missed-banner marker live per device in user defaults, outside sync. The banner closes itself after 20 seconds.
- While the paywall reports locked, a tap or Watch plays nothing and no banner shows. Scheduled notifications stay.
- Board deviations: the iPhone banner's Watch is 36 pt tall with a 44 pt hit area; "Open Settings" is accent because it is a link.
- Whether the banner waits while the user is typing a channel number on Apple TV is settled in the implementation.

## Risks / Trade-offs

- Open question: should reminders sync, or stay on the device where they were set? This is the blocking decision. Staying local would change the remove, notification and list requirements.
- Open question: syncing the lead time would change the lead-time requirement and needs a synced settings record.
- Open question: dropped programmes still remind, because guide gaps are common and the channel probably still shows the programme. Canceling them instead would change the requirement for programmes leaving the guide.
- Open question: the Apple TV banner takes the highlight from whatever the user was doing. A banner that waits for play/pause would change the banner requirement.
- Open question: should a reminder set closer to start than the lead time warn the user instead of going off at once? That would change the notification requirement.
- [CloudKit sync cannot run in CI] → the cross-device list check runs on a device with a second device setting the reminder.

## Implementation decisions

Calls made while building, recorded here instead of asked.

- Reminders sync. They are a fourth kind of synced record, `ReminderRecord`, in the same CloudKit-backed store as sources and favorites. The other option, reminders kept on the device where they were set, would have changed the remove, notification and list requirements, which all assume sync. A device not signed in to iCloud keeps them locally, as it does sources.
- The record adds one field to the list above, `notListed`, defaulted to false, for "No longer in the guide". It is synced so every device shows the same note.
- The guide on iPhone, iPad and Mac shows Remind me after Watch in a programme's details, as the proposal says. The first requirement now names that place too.
- On Apple TV the overlay's next programmes become buttons. Select on one turns its reminder on or off; the row shows "Remind me" or "Reminder set" at its end while focused, and a bell while set.
- "The guide covers the start" means the channel's own schedule, from its first programme's start to its last programme's stop, contains the reminder's start. A channel with no programmes at all changes nothing.
- Per device, user defaults hold `reminders.leadTime` (minutes) and `reminders.delivery`: the reminders this device has already reminded about and the notifications it last scheduled. A reminder counts as reminded once its notification was due while scheduled, or once its banner showed. Entries go when the reminder is deleted.
- One rule covers the banner while open and on return: a reminder that is due (its lead time reached, its programme not ended) and that this device has not reminded about shows a banner, one at a time, soonest first.
- On iPhone, iPad and Mac with notifications allowed, a reminder that goes off while Antenna is in front shows as the system's own banner, and the in-app banner stays away. The iPhone banner board describes the in-app banner replacing the notification; the requirement, which shows the in-app banner only when notifications are off, wins.
- The notification center sits behind a `ReminderNotifying` protocol. UI tests cannot answer the system permission prompt reliably, so a Debug build launched with `-ui-testing-notifications <notDetermined|allowed|denied>` uses a scripted center that answers the prompt as told and records what it scheduled. The system center is never touched under that argument.
- The Apple TV banner does not wait while the user types a channel number. It shows at once and takes focus to Watch; Menu closes it and the number entry carries on.

