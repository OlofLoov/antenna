# 0027. Programme reminders

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- ADR needed: a new ADR adds `ReminderRecord` to the private CloudKit container of ADR-0002 (which stays as written), so a reminder set on one device is listed on every device and each device delivers it in its own way; the alternative is a per-device record with no sync. The criteria assume the synced record.
- Blocked on: that ADR, written and accepted before this spec moves to Accepted. Spec 0029 adds `WatchProgressRecord`, `ListEntryRecord` and `RecentSearchRecord` to the same container; the ADR lists the 0027 and 0029 additions together so the `Schema` changes once. The migration note is in Edge cases.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0014 (`GuideKey`, `GuideIndex`, `GuideStore`, `GuideProgress`, horizon), 0013 (catalogue lookup, All channels order), 0009 (guide panel, future blocks), 0012 (guide result rows), 0007 (overlay next section), 0010 (inline playback, Live section, waiting-for-login), 0015 (`ShellNavigator`, Settings sheet), 0008 (channel-change event, current group), 0023 (Settings screen, in progress on its own branch; owns the Reminders entry row), 0025 (guide on iPhone, iPad and Mac, in progress on its own branch; places the same toggle). 0009 and 0012 list reminders as out of scope and hand them here.
- Required of other specs: 0009/AC-8c changes from "Remind me is absent" to "`reminders.toggle` is present for a future block and absent otherwise" (AC-1a); 0009/AC-17 changes to "right from `guide.watch` moves to `reminders.toggle` when present; left from `reminders.toggle` returns to `guide.watch`; Menu or down from either returns to the block it came from" (AC-1d); 0007/AC-14's panel focus order (`overlay.watch` then `overlay.favorite`) gains the next rows after `overlay.favorite`, and 0007/AC-20's next programmes become focusable rows (AC-3a); 0012's Scope moves "Reminders from a future programme result" from Out to "owned by 0027" and its future guide result rows on iOS, iPadOS and macOS carry `reminders.toggle.<resultId>` (AC-2a); 0023 adds a "Reminders" row that opens `reminders.list` and reads `ReminderStore.upcomingCount` at its trailing edge, hidden when zero (AC-15e supplies the count); 0025 places `reminders.toggle` after its Watch action for a future programme. None of those files is edited here. Until each amendment lands, the criterion that needs it (AC-1a, AC-1d, AC-2a, AC-3a) is effective only once the amended spec is merged; the implementing PR carries the one-line amendments as a separate docs commit ahead of the code.

## Design

Boards: `docs/design/boards/iPhone-Reminders.dc.html` (iOS; iPadOS and macOS show the same list in the Settings detail column at their type scale), `docs/design/boards/iPhone-Reminder-Banner.dc.html` (the in-app banner over the Live screen on iOS), `docs/design/boards/TV-Reminder-Banner.dc.html` (tvOS). The toggle's placement is on existing boards: `TV-Guide.dc.html` draws "Remind me" after Watch and Start over in the 0009 panel, which fixes its size and position only, since that board's panel shows an on-air programme where AC-1a hides the toggle; `iPhone-Search.dc.html` and `iPad-Search.dc.html` draw the guide result row whose trailing edge takes the toggle (0012/AC-7's catch-up glyph position, which future rows do not use).
Design rules that apply: DR-1 (the tvOS banner never pauses or tears down the player), DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13. Deviations: DR-5, the iPhone banner's Watch button is 36 pt tall with a 44 pt hit area, as 0006 does for its show-password control; DR-3, "Open Settings" on the denied notice is accent because it is a link.
States on the boards:
- `iPhone-Reminders`: navigation bar with "Settings" back and the "Reminders" title; the "Remind me" section with `reminders.leadTime` reading "Before start · 5 minutes" (17 pt, 44 pt row); `reminders.permissionDenied` (15 pt secondary text, crossed bell glyph) with `reminders.openSettings` (15 pt accent, 44 pt hit area); the "Upcoming · 4" header (13 pt muted eyebrow and count); `reminders.list` with 64 pt rows on the 0.06 surface, each a filled bell (20 pt), title at 16 pt weight 600, subtitle "<Today | Tomorrow | short weekday> <start> – <stop> · <channel>" at 13 pt muted, and `reminders.row.<id>.status` at 12 pt muted for "Moved from 20:00" and "No longer in the guide" (the latter with the outline bell); the last row swiped to reveal `reminders.remove.<id>` ("Remove", 88 pt wide, `#FF5F57`); the sync footnote at 13 pt muted; tab bar with Settings selected.
- `iPhone-Reminder-Banner`: `reminders.banner` over the Live screen, 12 pt from the sides and 8 pt under the status area, on `#11151C` with a 1 pt 0.08 border and the Focus shadow; bell glyph, eyebrow "Starts in 5 min" (12 pt muted, letter-spaced), `reminders.banner.title` (15 pt weight 600), `reminders.banner.body` "22:00 · 104 Sport One" (13 pt muted), `reminders.banner.watch` (white pill, 15 pt weight 600) and `reminders.banner.dismiss` (44 pt X).
- `TV-Reminder-Banner`: `reminders.banner` 640 pt wide at the top trailing corner (64 pt from the right, 44 pt from the top) on the overlay scrim with the Focus shadow; eyebrow "Reminder · Starts in 5 min" (18 pt muted, letter-spaced, with the bell), `reminders.banner.title` (29 pt weight 600), `reminders.banner.body` "22:00 · 104 Sport One" (22 pt secondary), `reminders.banner.watch` with the Focus token (64 pt tall, 22 pt weight 600) and `reminders.banner.dismiss` on the 0.12 surface.
Not drawn, with their text styles:
- `reminders.toggle` on the future-programme panel of 0009's `TV-Guide-Future.dc.html`, after `guide.watch`: the same 22 pt weight 600 button on the 0.12 surface as the "Remind me" drawn on `TV-Guide`, Focus token when focused.
- `reminders.toggle` in its set state: the label reads "Reminder set" with the filled bell in place of the outline bell, same button.
- The iPad and Mac banner: the iPhone banner's contents at 400 pt wide at the top trailing corner, 16 pt from the edges, same type sizes (iPad and Mac body 15, secondary 13).
- The macOS list row: the iPhone row at 16 pt title and 14 pt subtitle with `reminders.remove.<id>` as a 20 pt trash glyph in the muted colour at the trailing edge, 44 pt hit area.
- `reminders.toggle.<resultId>` on a future guide result row (0012): a 20 pt bell glyph in the muted colour (outline) or the primary text colour (filled, set) at the trailing edge, 44 pt hit area, on iPhone, iPad and Mac. The same glyph at 22 pt at the trailing edge of a next row in `overlay.panel.next` on tvOS; the focused next row takes the Focus token and reads "<time> · <title>" with the glyph in the muted-on-focus colour.
- `reminders.empty`: "No reminders yet. Find a programme in the guide and choose Remind me." at 15 pt muted, centred in the list area (tvOS 26 pt).
- `reminders.tvNote` in the tvOS Settings sheet: "Apple TV shows reminders while Antenna is open." at 24 pt muted under the Reminders list; the tvOS list uses the 0.06 rows at 64 pt with 29 pt titles and 22 pt subtitles.
- `reminders.confirmRemove` on tvOS and macOS: the system confirmation dialog "Remove the reminder for <title>?" with Remove and Cancel.
- `reminders.allowNotifications` in the list on iOS, iPadOS and macOS while authorization is not determined: a 44 pt row on the 0.06 surface reading "Allow notifications" at 17 pt in the accent (a link, as the denied notice's control), in the position of `reminders.permissionDenied`.
- `reminders.leadTime` on tvOS: a 64 pt focusable row in the Settings sheet reading "Before start" at 29 pt with the value at 26 pt muted at the trailing edge.
- Banner eyebrow variants: "Starts now" when the lead time is 0 or the fire date is reached late, "Was listed for <time>" for a reminder in the not-listed state. The tvOS eyebrow prefixes "Reminder · " as drawn; the iOS, iPadOS and macOS eyebrow does not.

## Problem

A viewer who spots tonight's match in the guide at lunch has no way to be told when it starts, and on an Apple TV nothing can wake them up because tvOS has no user notifications. TiviMate users set reminders from the guide and expect the reminder to follow them between devices, which that app cannot do. Antenna has the guide data (0014) and sync (ADR-0002) and uses neither for this.

## Scope

In:
- `reminders.toggle` on a future programme in the tvOS guide panel (0009), on future guide result rows on iOS, iPadOS and macOS (0012), and on the next rows of the tvOS overlay panel (0007). 0025 places the same toggle with AC-1b and AC-1c semantics; that placement is its criterion, listed under Required of other specs.
- `ReminderRecord` in the synced container: `id`, `sourceID`, `epgID`, `start`, `stop`, `title`, `channelName`, `movedFrom`, `createdAt`. Identity for deduplication is (`sourceID`, `epgID`, `start`). No `channelID`, no URL, no stream data.
- AntennaCore: `Reminder` value type, `ReminderKey` (`GuideKey` plus `start`), `ReminderSchedule.fireDate(start:leadMinutes:now:)`, `ReminderReconciler.reconcile(_:against:now:)`, `ReminderText` for notification, banner and row strings, `Reminder.merged(_:)` for deduplication, `ReminderAuthorization` (`.notDetermined`, `.denied`, `.authorized`, `.provisional`; the app maps `UNAuthorizationStatus` to it), and the `ReminderNotifier` protocol: `authorizationStatus() -> ReminderAuthorization`, `requestAuthorization() -> ReminderAuthorization`, `schedule(id:fireDate:title:body:)`, `cancel(ids:)`, `pending() -> [String]`. Nothing in AntennaCore imports UserNotifications (ADR-0005).
- `reconcile` tests a reminder (title T, start S, key K) against the index in this order: (1) a programme on K starting at S gives `.unchanged(stop:)` and the record's `stop` and `title` are updated when they differ; (2) else the programme on K whose folded title (0012/AC-2's folding) equals T, nearest to S within 6 hours, the earlier on a tie, gives `.moved(start:stop:)`; (3) else, when K's `loadingState` is `.loaded` or `.noData` and the source's horizon covers S, `.notListed`; (4) otherwise `.unknown`. A reminder with `stop ≤ now` gives `.expired` before any of these. An empty T skips step 2.
- The notifier, the banner, the list and the count operate over `Reminder.merged` values; the notification id is the merged reminder's `id.uuidString`. When the kept copy of a duplicate pair is deleted and another remains, AC-6c cancels the old id and AC-6a schedules the survivor within one second.
- App layer: `ReminderStore` (`@MainActor`) observes the records, the guide (`GuideStore.progressStream()`), `scenePhase` and the lead-time setting, drives the notifier and the banner, and exposes `upcomingCount`. Production notifier wraps `UNUserNotificationCenter` on iOS, iPadOS and macOS; tvOS has no notifier, only the banner.
- `RootNavigator`, an environment value on the iOS, iPadOS and macOS root (`RootView`) with `showLive(channel:)`: selects Live, makes All channels the group when the channel is not in the current one, and plays it inline through the same path as 0010/AC-6 and 0012/AC-6c, adding no second tune path. Owned here until 0025 takes it; it is the counterpart of 0015's `ShellNavigator`, which is tvOS only.
- Missed-reminder marker per device: an array of `id.uuidString` in `UserDefaults` under `reminders.shownMissed`; an id is removed when its record expires.
- Lead time, per device, in `UserDefaults` under `reminders.leadMinutes`: 0, 5, 10, 15 or 30, default 5.
- Local notification per reminder on iOS, iPadOS and macOS; tapping it tunes the channel.
- In-app banner on every platform while the app is in the foreground. On tvOS the banner is the only delivery.
- Reconciliation against the guide after each load: moved programmes follow, removed programmes are marked and still fire.
- Reminders list in Settings with removal, lead time, the denied notice and the empty state.
- Permission request on the first reminder, the denied state, and the tvOS note.
- Cleanup of expired reminders and of reminders for a deleted source.
- Accessibility identifiers with prefix `reminders.`.

Out (explicitly):
- Recording or auto-tune at start time (a recording or auto-tune spec; AC-9 only tunes when the user acts).
- Reminders for movies, series or catch-up items (0011 follow-up).
- Series or recurring reminders ("every episode"); a later reminders revision.
- Time-sensitive or critical interruption levels and the entitlement they need (later revision, see Open questions).
- Notification settings beyond the lead time (sound, per-channel mute).
- Reminders delivered while the Apple TV app is not running (tvOS has no mechanism; recorded as a known gap, see Edge cases).
- Syncing the lead-time setting (needs a settings record under ADR-0002).
- Widgets, Live Activities and the Top Shelf (0015 lists Top Shelf as out).
- Guide on iPhone, iPad and Mac itself (0025); this spec only places the toggle there.
- Paywall and entitlement checks (ADR-0006 follow-up spec); AC-22c only states what reminders do while the gate reports locked.

## User flow

1. tvOS: in the guide (0009) the user focuses a programme later tonight. The panel shows Watch and Remind me. Select on Remind me sets the reminder; the button reads "Reminder set". The same from a next row in the overlay panel (0007) with one select.
2. iPhone, iPad, Mac: until 0025 ships a guide on these platforms, Search is the only place to set a reminder. In Search (0012) a future guide result shows a bell at its trailing edge; tapping it sets the reminder. The first time, the system asks for notification permission after the reminder is saved.
3. The reminder appears under Settings › Reminders on every device signed into the same iCloud account.
4. Five minutes before start (the lead time), iPhone, iPad and Mac show a notification; tapping it opens Antenna and plays the channel inline. If Antenna is already in front, an in-app banner shows instead, with Watch and Dismiss.
5. Apple TV, while Antenna is open: the banner appears top right with focus on Watch. Select tunes and returns to full screen; Menu dismisses; it hides on its own after 20 seconds.
6. If a guide refresh moves the programme, the reminder moves with it and the list says where it moved from. If the programme disappears from the guide, the row says "No longer in the guide" and the reminder still fires at the original time.
7. In Settings › Reminders the user removes a reminder (swipe on iPhone and iPad, Remove button on Mac, select then confirm on Apple TV) and changes the lead time.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1a Toggle presence in the guide panel
Given the tvOS guide (0009) with focus on a block
When the panel is rendered
Then `reminders.toggle` is present after `guide.watch`, reading "Remind me" with the outline bell, exactly when the block is a programme whose `start > now` on the injected clock; it is absent for on-air, past, gap and placeholder blocks.

### AC-1b Setting from the guide panel
Given focus on `reminders.toggle` for a future programme P on channel C with no matching record
When the user presses select
Then one `ReminderRecord` is inserted with `sourceID == C.sourceID`, `epgID == C.epgID`, `start == P.start`, `stop == P.stop`, `title == P.title`, `channelName == C.name`, `movedFrom == nil`, `createdAt` equal to the injected clock's `now`; the button reads "Reminder set" with the filled bell, keeps focus, and no `load(_:)` call is made.

### AC-1c Removing from the guide panel
Given focus on `reminders.toggle` reading "Reminder set"
When the user presses select
Then every record whose (`sourceID`, `epgID`, `start`) equals P's key is deleted, including both copies of a duplicate pair (AC-4b), the button reads "Remind me" with the outline bell and keeps focus.

### AC-1d Reaching the toggle with the remote
Given focus on `guide.watch` for a future programme
When the user moves right
Then `reminders.toggle` has focus; left from it returns to `guide.watch`; Menu or down from it returns focus to the grid block it came from as 0009/AC-17; for an on-air, past, gap or placeholder block, right from `guide.watch` does nothing.

### AC-2a Toggle on search result rows
Given guide results in Search on iOS, iPadOS or macOS
When a row is rendered
Then a row whose programme has `start > now` carries `reminders.toggle.<resultId>` at its trailing edge with a frame at least 44 by 44 pt and accessibility label "Remind me" (or "Reminder set" when a record exists); on macOS it activates with a click and, with keyboard focus on it, with Space; an on-air row carries no toggle; on tvOS no result row carries one and 0012/AC-8 leads to the guide panel of AC-1a.

### AC-2b Toggling from a search result
Given `reminders.toggle.<resultId>` on a future programme
When the user activates it
Then AC-1b's insert or AC-1c's delete applies, the glyph switches between outline and filled, the query and results stay as they were, and the channel does not play.

### AC-3a Next rows in the overlay panel
Given the tvOS overlay with focus in the panel and `overlay.panel.next` listing programmes (0007/AC-20)
When the user moves down from `overlay.favorite`
Then focus moves to the first next row, then through the others; each row has accessibility identifier `reminders.toggle.<sourceID>.<epgIDHex>.<startUnixSeconds>` (`epgIDHex` is the lowercase hex of the `epgID`'s UTF-8 bytes) and carries the selected trait exactly when a reminder is set; moving down from the last row does nothing; up from the first returns to `overlay.favorite`; Menu follows 0007/AC-10.

### AC-3b Toggling from a next row
Given focus on a next row
When the user presses select
Then AC-1b's insert or AC-1c's delete applies for that programme, the row's glyph and selected trait update, the overlay stays open, and no `load(_:)` call is made.

### AC-4a Record rules
Given the `ReminderRecord` model
When the schema is inspected
Then every stored property is optional or defaulted, no property has `@Attribute(.unique)`, there is no relationship, and the model has no property whose type is `URL` and no property named `channelID` or `streamURL`.

### AC-4b Merge rule
Given two `Reminder` values with equal (`sourceID`, `epgID`, `start`) and different `id`
When `Reminder.merged(_:)` runs
Then one value is returned carrying the lowest `createdAt`, then the lowest `id.uuidString`; values with different keys are all returned.

### AC-5a Lead time setting
Given `reminders.leadTime` in Settings › Reminders
When the user picks a value
Then the choices are 0, 5, 10, 15 and 30 minutes labelled "At start", "5 minutes", "10 minutes", "15 minutes", "30 minutes", and with no stored value the selected choice is 5. On iOS, iPadOS and macOS the control is a picker.

### AC-5c Lead time storage
Given a lead time picked by AC-5a or AC-5d
When the injected `UserDefaults` suite and the container are read
Then the suite holds the integer under `reminders.leadMinutes` and no `ReminderRecord` has changed.

### AC-5d Lead time on tvOS
Given tvOS with focus on `reminders.leadTime`, a focusable row in the Settings sheet
When the user presses select five times from 0
Then the value reads 5, 10, 15, 30 and 0 in turn.

### AC-5b Lead time change reschedules
Given three scheduled reminders on iOS, iPadOS or macOS and lead time 5
When the user picks 15
Then within one second the notifier has received `cancel(ids:)` for the three ids and `schedule` for each with `fireDate == start − 15 min`, and `pending()` lists exactly the three ids.

### AC-6a Scheduling on insert or arrival
Given authorization `.authorized` or `.provisional` on iOS, iPadOS or macOS and lead time L
When a `ReminderRecord` with `start > now + L` is inserted locally or appears from sync
Then, subject to AC-6d's cap, within one second the fake notifier records `schedule(id: <merged reminder id>.uuidString, fireDate: start − L, title: record.title, body: "Starts at <start, locale short time> on <channelName>")`; with L 0 the body is "Starts now on <channelName>"; no string in the request contains "http", "://" or the channel's `streamURL`.

### AC-6b Lead time already passed
Given authorization `.authorized` or `.provisional` on iOS, iPadOS or macOS
When a record with `start − L ≤ now < start` is inserted
Then `schedule` is called with `fireDate` equal to `now` on the injected clock (the notification is delivered at once); a record with `start ≤ now` is not scheduled and is kept until AC-13 expires it.

### AC-6c Removal cancels
Given a scheduled reminder on iOS, iPadOS or macOS
When its record is deleted locally or disappears from the synced store
Then within one second `cancel(ids:)` is called with its id and `pending()` no longer lists it.

### AC-6d Pending cap
Given 70 upcoming reminders and authorization `.authorized` on iOS, iPadOS or macOS
When scheduling runs
Then `pending()` holds the 64 with the earliest `fireDate`, ties broken by the lower `id.uuidString`; when one is removed while the app is `.active`, or on the next `scenePhase` `.active` after one has fired, the next by `fireDate` is scheduled within one second of that trigger.

### AC-7a Permission request on first reminder
Given authorization `.notDetermined` on iOS, iPadOS or macOS
When the user sets the first reminder by AC-1b, AC-2b or AC-3b
Then the record is inserted before `requestAuthorization()` is called, the call is made once, and on `.authorized` AC-6a schedules it; the app never calls `requestAuthorization()` at launch or on showing Settings.

### AC-7b Set while denied
Given authorization `.denied`
When a reminder is set
Then the record is inserted, `schedule` is not called, and the toggle reads "Reminder set".

### AC-7e Denied notice
Given authorization `.denied` on iOS, iPadOS or macOS
When the Reminders list is shown
Then `reminders.permissionDenied` reads "Notifications are off for Antenna. Reminders show only while the app is open." with `reminders.openSettings`, whose activation hands the injected URL opener `UIApplication.openNotificationSettingsURLString` on iOS and iPadOS and `x-apple.systempreferences:com.apple.preference.notifications?id=<bundle id>` on macOS; the notice is absent for `.authorized`, `.provisional` and `.notDetermined`, and does not exist on tvOS. `.provisional` is treated as `.authorized` in every criterion of this spec.

### AC-7f Not determined with synced reminders
Given authorization `.notDetermined` on iOS, iPadOS or macOS and at least one upcoming reminder (set here or arrived by sync)
When the Reminders list is shown
Then `reminders.allowNotifications` is present in place of the denied notice; activating it calls `requestAuthorization()` once, after which AC-6a or AC-7e applies; it is absent with no upcoming reminder and for every other status.

### AC-7c Granted after denied
Given `reminders.permissionDenied` shown and two upcoming reminders
When `scenePhase` becomes `.active` with the status now `.authorized`
Then within one second both are scheduled per AC-6a and the notice is gone.

### AC-7d tvOS has no notifier
Given tvOS
When the app launches, a reminder is set, or Settings › Reminders is shown
Then no `UNUserNotificationCenter` call is made (the notifier dependency is absent on tvOS), no permission is requested, and `reminders.tvNote` reads "Apple TV shows reminders while Antenna is open." under the list.

### AC-8a Notification tap tunes (iOS, iPadOS, macOS)
Given a delivered notification for reminder R on channel key K
When the user taps it or its "Watch" action, with the app in the background or not running
Then `RootNavigator.showLive(channel:)` is called with the first channel in All channels order (0013/AC-6b) whose `GuideKey == K`, the Live section is shown, and `load(_:)` is called once with its `streamURL` (fake engine log; nothing derived from the URL reaches an accessibility attribute). The key comes from the notification's `userInfo`, so a record deleted on another device after delivery still tunes.

### AC-8c Group switch on tune
Given AC-8a's tap and a current group that does not contain the resolved channel
When the tune happens
Then All channels is the selected group (0012/AC-6c's rule); with the channel in the current group, the group is unchanged.

### AC-8d Cold launch
Given AC-8a's tap with the app not running
When the resolved channel's source finishes loading
Then `load(_:)` is called within one second of that event on the injected clock.

### AC-8e Lookup on a huge source
Given 0013's large fixture (tens of thousands of channels) and 500 reminders
When the channel for a key is resolved, and the set state of 200 visible rows is computed
Then each lookup completes in under 5 ms in a debug run on 0013/AC-14's reference machine, and set state is read from a dictionary keyed by `ReminderKey` that is rebuilt only when a record changes; benchmark, not CI-gated.

### AC-8b Channel not yet loaded
Given AC-8a's tap and no loaded channel with key K after 60 seconds on the injected clock (source missing, credential not synced per 0010/AC-18, or channel gone)
When the deadline passes
Then no `load(_:)` call is made, the Live section stays shown, and 0010's existing states (waiting for login, banner) describe what is on screen; nothing from this spec is added.

### AC-9a Banner in the foreground (iOS, iPadOS, macOS)
Given the app `.active` with authorization `.authorized` and a reminder whose fire date arrives
When the notification is presented to the delegate
Then the system banner is suppressed (presentation options empty), `reminders.banner` appears with `reminders.banner.title == title`, `reminders.banner.body == "<start> · <number> <channelName>"` (the number from the catalogue when a loaded channel has the key, else "<start> · <channelName>"), the eyebrow "Starts in <L> min" ("Starts now" when L is 0), `reminders.banner.watch` and `reminders.banner.dismiss`.

### AC-9e Banner removal (iOS, iPadOS, macOS)
Given `reminders.banner` shown
When 20 seconds pass on the injected clock, the user activates `reminders.banner.dismiss`, swipes up (iOS and iPadOS) or presses Escape (macOS, and iPadOS with a hardware keyboard)
Then the banner is removed and the screen beneath is unchanged. With a keyboard, Tab reaches `reminders.banner.watch` and Space or Return activates it.

### AC-9d One banner per firing
Given a reminder on iOS, iPadOS or macOS
When its fire date arrives while the app is `.active`
Then at most one `reminders.banner` is shown for its (`id`, `fireDate`): the store's own timer is armed only when authorization is `.denied` or `.notDetermined`, and with `.authorized` only the delegate path of AC-9a shows it. No banner is shown for a reminder inserted on this device less than 5 seconds before its fire date (AC-6b's immediate case), on any platform.

### AC-9b Banner Watch (iOS, iPadOS, macOS)
Given `reminders.banner` shown
When the user activates `reminders.banner.watch`
Then AC-8a's tune applies, the banner is removed, and the user's place in Movies, Search or Settings is not kept (Live is selected). When no loaded channel has the key, the banner is removed, Live is shown and no `load(_:)` call is made; there is no 60-second wait as in AC-8b.

### AC-9c Banner without authorization (iOS, iPadOS, macOS)
Given the app `.active`, authorization `.denied` or `.notDetermined`, and a reminder whose fire date arrives on the injected clock
When the clock reaches `start − L`
Then `reminders.banner` is shown as AC-9a with no notifier call, driven by the store's own timer.

### AC-10a Banner on tvOS
Given tvOS, the app in the foreground on any screen (full-screen Live, overlay, zap bar, guide, Movies, Series, Search, Settings sheet) and a reminder whose fire date arrives on the injected clock
When the banner is shown
Then `reminders.banner` exists at the top trailing corner above every other view, `reminders.banner.watch` has focus, `reminders.banner.title` and `reminders.banner.body` read as AC-9a, the eyebrow reads "Reminder · " followed by AC-9a's eyebrow text (the board's wording is authoritative on tvOS), the engine state is unchanged and no `pause()` call is made (DR-1), and the element that had focus is recorded for AC-10c.

### AC-10b tvOS Watch
Given `reminders.banner.watch` focused
When the user presses select
Then the channel is resolved as AC-8a's lookup; with a different channel than the playing one, or the engine `.failed` or `.idle`, `load(_:)` is called once with its `streamURL`; with the same channel and `.paused` (0015/AC-5a), `play()` is called once and no `load(_:)` (0007/AC-9a); with the same channel and `.playing` or `.loading`, neither; in every resolved case `showLive()` is called (0015/AC-14c) and the banner is removed; a channel-change event (0008/AC-1) is emitted only when `load(_:)` was called; when no loaded channel has the key, the banner is removed and no engine or navigator call is made.

### AC-10c tvOS dismiss
Given `reminders.banner` shown
When the user presses Menu, selects `reminders.banner.dismiss`, or 20 seconds pass on the injected clock
Then the banner is removed, focus returns to the recorded element (or to the screen's initial focus when it no longer exists), the screen beneath is unchanged, and Menu is consumed (0015/AC-3, 0007/AC-10 and 0008/AC-3 do not fire for that press).

### AC-10d Two reminders at once
Given two reminders with the same fire date
When they arrive
Then one banner shows the earlier `start`, then the other after it is removed; the queue holds any number of reminders in `start` order, ties broken by `id.uuidString`; on iOS, iPadOS and macOS both notifications are scheduled and the banner queue applies only in the foreground.

### AC-10e tvOS banner waits for alerts and the keyboard
Given tvOS with a system alert (such as `reminders.confirmRemove`) or the on-screen keyboard presented
When a reminder's fire date arrives
Then no banner is shown and focus stays where it is; when the alert or keyboard is dismissed the banner is shown as AC-10a, and its 20-second timer starts then.

### AC-11 Missed reminders on activation
Given tvOS, or another platform with authorization `.denied` or `.notDetermined`, and a reminder whose fire date passed while the app was not `.active` with `stop > now`
When `scenePhase` becomes `.active`
Then the banner of AC-9a or AC-10a is shown once for that reminder with the eyebrow "Starts now" (or "Was listed for <time>" for the not-listed state), its `id` is written to the injected `UserDefaults` suite under `reminders.shownMissed`, and it is not shown again on later activations while the marker is present; on a platform with `.authorized` nothing is shown, because the system delivered it.

### AC-11b Missed marker holds several ids
Given two missed reminders shown by AC-11
When the app becomes `.active` again
Then `reminders.shownMissed` holds both `id.uuidString` values and neither banner is shown.

### AC-12a Moved programme
Given a reminder for programme P (`title` T, `start` S) on key K and a guide load for K's source whose index has no programme on K starting at S but has programmes with folded title equal to T starting at S + 2 h and S − 3 h, and another at S + 7 h
When `.loaded` is emitted for that source (0014/AC-10)
Then `ReminderReconciler` returns `.moved(start: S + 2 h, stop:)` (the S + 7 h programme is beyond 6 hours and ignored), the record's `start` and `stop` are updated, `movedFrom` is set to S, the notification is cancelled and rescheduled for the new start − L, and with an injected `en_GB` locale `reminders.row.<id>.status` reads "Moved from <S, short time>" (prefixed with the day as in the subtitle when the day changed).

### AC-12f Tie on a move
Given AC-12a's reminder and an index with title matches at S + 2 h and S − 2 h only
When `reconcile` runs
Then it returns `.moved(start: S − 2 h, stop:)`.

### AC-12g Second move
Given a reminder with `movedFrom == S` now at S + 2 h, and a load whose title match is at S + 3 h
When `.loaded` is emitted
Then `start` becomes S + 3 h and `movedFrom` stays S.

### AC-12e Same start, new details
Given a reminder (T, S) on K and a load whose index has a programme on K starting at S with a different title or stop
When `.loaded` is emitted
Then the reconciler returns `.unchanged(stop:)`, the record's `title` and `stop` take the programme's values, `movedFrom` and the status are unchanged, and the notification is rescheduled only when `stop` or `title` changed. A record is saved only when a field value differs, at most once per record per `.loaded` event; a load that changes nothing saves nothing.

### AC-12b Removed programme
Given a reminder for P on key K and a load after which K's `loadingState` is `.loaded` or `.noData`, the horizon covers S, and no programme on K matches step 1 or step 2 of the Scope's reconcile order
When `.loaded` is emitted
Then the reconciler returns `.notListed`, the record's times are unchanged, the notification is cancelled and rescheduled for S − L with the body "Was listed for <S> on <channelName>. No longer in the guide.", the row's status reads "No longer in the guide" with the outline bell, and a later load that lists P again returns `.unchanged(stop:)` and clears the status.

### AC-12c Guide does not cover the reminder
Given a reminder on key K whose `loadingState` is `.loading`, `.unavailable` or `.failed`, or whose source's horizon does not cover S, or whose `sourceID` matches no `SourceRecord` yet
When any load completes
Then the reconciler returns `.unknown`, nothing is written and nothing is rescheduled.

### AC-12d Reconciliation performance
Given 500 reminders spread over 0014/AC-16's 2 000 keys with seven days of programmes
When `reconcile` runs over all of them
Then it completes in under 50 ms in a debug `swift test` run on the reference machine named in the test (same baseline as 0013/AC-14); benchmark, not CI-gated.

### AC-13 Expiry
Given reminders whose end E has passed, where E is `stop`, or `start + 3 h` when `stop` is nil
When `scenePhase` becomes `.active`, a `.loaded` event arrives for any source, or the Reminders list is shown
Then the pass runs over every record: `reminders.list`, the banner and `upcomingCount` exclude a record once `E ≤ now`, and the record is deleted and its notification cancelled only once `E + 10 min ≤ now`, so a device whose clock runs a few minutes fast does not delete a reminder for every device.

### AC-14 Source removed
Given reminders for source S
When a deletion of S's `SourceRecord` is observed (a local delete, or a synced deletion event; the same trigger as 0014/AC-18a, and the absence of a record is not a deletion)
Then every `ReminderRecord` with `sourceID == S` is deleted on that device and its notifications cancelled; a `ReminderRecord` whose `sourceID` matches no `SourceRecord` yet is kept, listed with its stored `channelName`, scheduled per AC-6a and not reconciled until the source arrives.

### AC-15a Reminders list
Given records with `start` in the order 3, 1, 2
When `reminders.list` is shown
Then `reminders.row.<id>` appear in start order 1, 2, 3, each 64 pt tall with the filled bell (outline for not-listed), the title, and the subtitle "<day> <start> – <stop> · <channelName>" where <day> is "Today", "Tomorrow", the short weekday for the next five days, and "<short weekday> <d MMM>" from six days out (0012/AC-7's rule), using the injected calendar and time zone; the header count equals the row count; duplicates per AC-4b appear once.

### AC-15b Removal from the list
Given `reminders.row.<id>`
When the user removes it (trailing swipe `reminders.remove.<id>` on iOS and iPadOS; the row's `reminders.remove.<id>` button then Remove in `reminders.confirmRemove` on macOS; select on the row then Remove in `reminders.confirmRemove` on tvOS)
Then every record with the row's (`sourceID`, `epgID`, `start`) is deleted and AC-6c applies; Cancel in the dialog leaves everything unchanged with focus back on the row.

### AC-15c Empty list
Given no upcoming reminders
When `reminders.list` is shown
Then `reminders.empty` reads "No reminders yet. Find a programme in the guide and choose Remind me.", the header count is absent, and `reminders.leadTime` is still shown.

### AC-15e Upcoming count
Given seven records: A, B, C and D with `stop > now`, B' a duplicate of B per AC-4b, one with `stop ≤ now`, and one with `start == nil`
When `ReminderStore.upcomingCount` is read
Then it is 4.

### AC-16 Sync between devices
Given a reminder set on device A
When device B, signed into the same iCloud account, is online
Then the reminder is listed on B and, on iOS, iPadOS or macOS with authorization `.authorized`, scheduled per AC-6a; on an Apple TV it is delivered by AC-10a while the app is open.

### AC-16b No iCloud account
Given a device signed out of iCloud, or with CloudKit unavailable
When a reminder is set
Then the record is saved in the local store, `reminders.list` lists it with no error text, and AC-6a schedules it; syncing when an account appears follows ADR-0002 and is checked on device.

### AC-17 No secrets anywhere
Given a channel whose `streamURL` and `Channel.id` embed credentials (an M3U fallback id, 0013 edge case)
When a reminder is set, scheduled, reconciled, shown as a banner, listed and logged with an injected logger
Then no `ReminderRecord` field, notification request string, banner text, accessibility attribute or log line contains the URL, the credential values or `Channel.id`; the test asserts every recorded string against them (ADR-0003). 0013's hold on inserting `channelID` does not apply because no reminder stores one.

### AC-18 Offline
Given a stubbed `URLSession` that records and fails every request
When a reminder is set, its fire date arrives, it is removed and the list is shown
Then the stub has recorded zero requests.

### AC-19a Reduce Motion
Given Reduce Motion on
When the banner appears and is removed
Then `reminders.banner` is hittable in the first frame after the fire event and is gone in the first frame after removal, with no offset or opacity change in between.

### AC-19b VoiceOver
Given VoiceOver on
When the banner and a list row are inspected
Then the banner is one element with label "Reminder, <title>, <body>" and custom actions "Watch" and "Dismiss"; a list row is one element with label title, subtitle and status joined by commas.

### AC-20 Time zone and DST
Given a reminder with `start` 2027-03-28 02:30 UTC and a device in Europe/Stockholm
When the subtitle and fire date are computed
Then the subtitle shows 04:30 (the local time after the shift) and the fire date is the absolute instant `start − L` regardless of the wall clock, computed in the injected time zone.

### AC-20b Time zone change
Given two scheduled reminders on iOS, iPadOS or macOS
When the system time zone changes or a significant time change is posted
Then within one second both are cancelled and scheduled again, and each body's start time is in the new time zone.

### AC-21 First launch and empty store
Given a fresh install with no records
When the app launches
Then no notifier call is made, `pending()` is empty, and Settings › Reminders shows AC-15c.

### AC-22c Entitlement locked
Given an injected `EntitlementGate` (assumed name; ADR-0006's follow-up spec owns the type) that reports locked
When the user taps a notification, a reminder's fire date arrives, or the app becomes `.active` with a missed reminder
Then no `load(_:)` call is made, the gate records one denied request per tap, `reminders.banner` is not shown, no `reminders.shownMissed` marker is written, and the pending notifications stay scheduled. What the locked app shows instead belongs to the paywall spec.

## Dropped

- AC-4 (record rules and merge in one criterion): split into AC-4a and AC-4b; schema reflection and a value function fail for different reasons.
- AC-7b's second half (denied notice and the open-settings URL): moved to AC-7e, since the notice and the URL differ per platform and were separate assertions.
- AC-15d (Settings entry count): the row belongs to 0023; AC-15e proves the count this spec owns.
- AC-19 (Reduce Motion and VoiceOver): two Givens with different Thens; split into AC-19a and AC-19b.
- AC-22 (notification tap without entitlement) and AC-22b (no banner over the paywall): both specified paywall screens, which the ADR-0006 follow-up spec owns; replaced by AC-22c, which states only what reminders do while locked.

## Edge cases and failure modes

- Migration note (ADR-0002, conventions): `ReminderRecord` is an additive model with every property optional or defaulted. CloudKit creates its record type on first save. A device on an older build ignores the type and keeps syncing the other models. No lightweight migration is needed beyond adding the model to the `Schema`, which lands in one change with 0029's models.
- Two Apple TVs or two iPhones on one account both deliver the same reminder. That is intended; the record is one, delivery is per device.
- Reconciliation runs on each device against that device's guide. Two devices with different guide versions may move the same record to different starts; the later write wins under CloudKit, and the next load on the other device reconciles again. Convergence is not guaranteed and the list may flip once; accepted.
- A programme that moves more than 6 hours is treated as removed (AC-12b). The reminder still fires at the old time; the user removes it from the list. A programme that keeps its start and changes title follows the new title (AC-12e).
- tvOS while Antenna is not running or is suspended: nothing fires. The brief's "a reminder set on iPhone fires on the Apple TV too" holds only while Antenna is open on the Apple TV; `reminders.tvNote` says so. AC-11 shows the banner on return when the programme is still on.
- tvOS banner over the guide covers `guide.clock` for up to 20 seconds; over the overlay it sits above `overlay.clock`. Accepted; the time is in the banner body.
- A banner arriving while `zapBar.entryPill` is visible: the banner takes focus, the pill's timer keeps running and tunes on its own (0008/AC-11); select on the banner tunes the reminder's channel instead. Open question records the alternative.
- A reminder set from Search while the field has focus: the keyboard stays, no result is selected.
- Channels sharing a `GuideKey` (0014): the toggle reflects the key; the banner tunes the first in All channels order. Rows for the other channels show the same set state.
- Channel with `epgID` nil has no programmes (0014), so no toggle can appear for it.
- Guide refresh that shortens `stop` to before `now` (AC-12a) expires the reminder on the next AC-13 trigger.
- A duplicate record pair (AC-4b) where one copy is deleted on another device: the survivor is listed and scheduled per the Scope's merge rule, whichever copy was kept before.
- A record with `sourceID`, `epgID` or `start` nil (a partial CloudKit sync) is neither listed, scheduled nor reconciled until the fields arrive; it expires per AC-13 once `start` or `stop` is known. A record with an empty `title` lists and fires as "Untitled" (0009/AC-8a's word) and reconciles by start only, since an empty folded title matches nothing.
- Identifiers that embed a `GuideKey` (AC-3a) use `<sourceID uuid>.<epgIDHex>`, because an `epgID` can contain dots, spaces or colons and the identifier must split unambiguously.
- `UNUserNotificationCenter` refuses a request (storage full, system error): the notifier reports the error to the injected logger with the reminder id and error code only; the record stays and the next AC-5b, AC-7c or AC-6d pass retries.
- macOS: the notification appears in Notification Center; clicking it brings the window forward before AC-8a tunes. The app does not add a Dock badge.
- Notifications carry no attachments and no artwork (`Programme.iconURL` is not fetched).
- The notification's `threadIdentifier` is the channel key so several reminders on one channel group together; `categoryIdentifier` "reminder" with one action "Watch".
- Lead time 30 with a programme 10 minutes away: AC-6b fires at once. The toggle's label does not warn; open question.
- Large stores: 10 000 reminders are not expected; the list is a plain `List` and AC-12d bounds the reconcile.
- Dynamic Type at accessibility sizes: rows grow; the banner wraps the title to two lines and keeps the 44 pt targets.

## Test plan

`ReminderSchedule`, `ReminderReconciler`, `ReminderText`, `Reminder.merged(_:)` and the AC-12d benchmark are swift-testing tests in AntennaCore over `GuideIndex` fixtures with an injected calendar, time zone and clock. The app layer is tested with an in-memory `ModelContainer`, a fake `ReminderNotifier` that records calls and returns a scripted authorization status, a fake `GuideStore`, a fake engine recording `load(_:)`, an injected `UserDefaults` suite, an injected URL opener and an injected clock. UI tests launch with `-antenna.uiTest` and arguments for the notifier status, the fixture reminders and a scripted fire event. Identifiers: `reminders.toggle`, `reminders.toggle.<resultId>`, `reminders.toggle.<sourceID>.<epgIDHex>.<startUnixSeconds>`, `reminders.banner`, `reminders.banner.title`, `reminders.banner.body`, `reminders.banner.watch`, `reminders.banner.dismiss`, `reminders.list`, `reminders.row.<id>`, `reminders.row.<id>.status`, `reminders.remove.<id>`, `reminders.confirmRemove`, `reminders.empty`, `reminders.leadTime`, `reminders.permissionDenied`, `reminders.openSettings`, `reminders.allowNotifications`, `reminders.tvNote`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1a | ui (tvOS, injected clock) | TBD |
| AC-1b | integration (in-memory container) + ui (tvOS) | TBD |
| AC-1c | integration + ui (tvOS) | TBD |
| AC-1d | ui (tvOS, both block kinds) | TBD |
| AC-2a | ui (iPhone and macOS) | TBD |
| AC-2b | integration + ui (iPhone) | TBD |
| AC-3a | ui (tvOS) | TBD |
| AC-3b | integration + ui (tvOS) | TBD |
| AC-4a | integration (schema reflection) | TBD |
| AC-4b | core (`merged`) | TBD |
| AC-5a | ui (iPhone, macOS) | TBD |
| AC-5b | integration (fake notifier) | TBD |
| AC-5c | integration (defaults suite, container) | TBD |
| AC-5d | ui (tvOS) | TBD |
| AC-6a | integration (fake notifier, sync simulated by a second context) | TBD |
| AC-6b | integration (injected clock) | TBD |
| AC-6c | integration | TBD |
| AC-6d | integration | TBD |
| AC-7a | integration (scripted status) | TBD |
| AC-7b | integration (scripted status) | TBD |
| AC-7c | integration (scene phase driven) | TBD |
| AC-7d | integration (tvOS target, dependency absent) + ui (tvOS) | TBD |
| AC-7e | ui (iPhone and macOS, URL opener) | TBD |
| AC-7f | ui (iPhone) + integration (fake notifier call count) | TBD |
| AC-8a | ui (iPhone, fake engine log, launch argument for the response) | TBD |
| AC-8b | integration (injected clock, fake sources) | TBD |
| AC-8c | integration (fake navigator, fixture catalogue) | TBD |
| AC-8d | integration (injected clock, fake source load) | TBD |
| AC-8e | core benchmark, `ReminderLookupBenchmark` (named, not gated) | TBD |
| AC-9a | ui (iPhone, scripted fire event, injected clock) | TBD |
| AC-9b | ui (iPhone, fake engine log) | TBD |
| AC-9c | integration (scripted status, injected clock) + ui (iPhone) | TBD |
| AC-9d | integration (scripted status, fake delegate, injected clock) | TBD |
| AC-9e | ui (iPhone, iPad with keyboard, macOS) | TBD |
| AC-10a | ui (tvOS, per screen, fake engine state) | TBD |
| AC-10b | ui (tvOS, fake engine log) | TBD |
| AC-10c | ui (tvOS, three routes) | TBD |
| AC-10d | integration (banner queue) | TBD |
| AC-10e | ui (tvOS, alert and keyboard presented) | TBD |
| AC-11 | integration (scene phase, scripted status) | TBD |
| AC-11b | integration (defaults suite) | TBD |
| AC-12a | core (reconciler) + integration (record and notifier) | TBD |
| AC-12b | core + integration | TBD |
| AC-12c | core | TBD |
| AC-12d | core benchmark, `ReminderReconcilerBenchmark` (named, not gated) | TBD |
| AC-12e | core + integration (save count) | TBD |
| AC-12f | core | TBD |
| AC-12g | core + integration | TBD |
| AC-13 | integration (three triggers, injected clock at E and E + 10 min) | TBD |
| AC-14 | integration (deletion event and absent record) | TBD |
| AC-15a | ui (iPhone, macOS, tvOS) + core (`ReminderText` subtitle) | TBD |
| AC-15b | ui (iPhone, macOS, tvOS) | TBD |
| AC-15c | ui (iPhone, macOS, tvOS) | TBD |
| AC-15e | integration (`ReminderStore`) | TBD |
| AC-16 | device; CI proxy is AC-6a's second-context simulation | CloudKit cannot run in CI; manual iPhone to Apple TV check |
| AC-16b | integration (local store, no CloudKit) + device | TBD |
| AC-17 | integration (injected logger, recorded strings) | TBD |
| AC-18 | integration (recording `URLSession` stub) | TBD |
| AC-19a | ui (iPhone and tvOS) | TBD |
| AC-19b | ui (iPhone and tvOS, accessibility audit) | TBD |
| AC-20 | core (injected time zone) | TBD |
| AC-20b | integration (posted time-zone notification, fake notifier) | TBD |
| AC-21 | integration | TBD |
| AC-22c | integration (fake `EntitlementGate`) | TBD |

## Open questions

- Synced record versus per-device reminders (the ADR). This spec picks synced because sync is the top TiviMate wish and the phone-at-lunch, TV-at-night case is the point of the feature; the cost is a third CloudKit model and the convergence caveat in Edge cases.
- Lead time per device in `UserDefaults` rather than on the record or synced. A living-room Apple TV and a pocket iPhone plausibly want different lead times; storing it per record would freeze the value at set time. Overturn if one synced value is preferred; that needs the settings record ADR.
- Removed programmes still fire (AC-12b). The alternative is to cancel silently. Guide data is unreliable enough (research: EPG gaps are the top support topic) that the stream probably still shows the programme, so the spec keeps the user's intent. Overturn if the noise is worse than the miss.
- The tvOS banner takes focus on appearance. The alternative is a passive banner tuned by play/pause while visible, which does not steal focus from the guide. Chosen for testability and one-press Watch.
- Should the banner over full-screen Live wait while `zapBar.entryPill` is visible?
- Time-sensitive interruption level for the notification so it breaks through Focus modes. Needs the entitlement and a Settings toggle; left for a revision.
- Should AC-6b warn when the lead time has already passed ("Starts in 3 minutes") instead of firing at once?
- Should the toggle also appear on the tvOS zap bar's Next line (0008/AC-5)? Not drawn; left out.
- `.provisional` is treated as `.authorized`. The app never asks for provisional authorization, so this only matters if the user picks it in system settings, where notifications arrive quietly in Notification Center.
- Expiry waits 10 minutes past the end before deleting (AC-13) to tolerate clock skew on one device. A longer grace keeps stale rows in the store; a shorter one risks deleting a running programme's reminder for everyone.
- The tvOS banner queues behind system alerts and the keyboard (AC-10e) instead of taking focus from typing. A reminder can then show late; the eyebrow still reads from the fire date.
