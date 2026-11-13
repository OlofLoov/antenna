# Proposal

## Why

> As a viewer, I want a reminder when a programme I care about is about to start.

A viewer who spots tonight's match in the guide at lunch has no way to be told when it starts. On an Apple TV nothing can wake them up, because Apple TV apps cannot show notifications. TiviMate users set reminders from its guide and wish they followed them from phone to TV. Antenna already has the guide data and iCloud sync to do that.

Not reviewed yet.

## What Changes

- A Remind me button on programmes that have not started: in the Apple TV guide, on the next programmes in the Apple TV channel overlay, and on guide results in Search on iPhone, iPad and Mac. The guide on iPhone, iPad and Mac adds the same button.
- Reminders sync through iCloud and are listed on every device. Each device delivers them in its own way.
- A notification on iPhone, iPad and Mac. Tapping it plays the channel.
- A banner inside the app while Antenna is open, on every device. On Apple TV this is the only way a reminder appears.
- Reminders keep up with guide changes. A programme that moves takes its reminder with it, and one that disappears is marked and still reminds.
- A Reminders page in Settings with the list, removal, how many minutes before start to remind, and a notice when notifications are off.
- Reminders for programmes that have ended or whose source was deleted are cleared out.

Out of scope:
- Recording, or switching to the channel by itself at start time.
- Reminders for movies, series episodes or catch-up.
- Repeating reminders, such as every episode of a show.
- Notifications that break through Focus or Do Not Disturb.
- Notification options beyond the lead time, such as sound or muting a channel.
- Reminders on Apple TV while Antenna is closed. tvOS offers no way to do it.
- Syncing the lead time between devices.
- Widgets, Live Activities and the Apple TV Top Shelf.
- The guide on iPhone, iPad and Mac itself, which belongs to `add-guide-on-iphone-ipad-and-mac`.
- What the app shows while the paid unlock is missing, which belongs to `add-paywall-and-entitlement`.

## Capabilities

### New Capabilities
- `programme-reminders`: reminders for programmes that have not started, synced across devices, delivered as notifications or in-app banners.

### Modified Capabilities

None.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `channel-catalogue`, `guide-data`, `tvos-shell`, and the changes `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-tv-guide-grid`, `add-live-tv-on-iphone-ipad-mac`, `add-search`, `add-sources-and-settings`, `add-guide-on-iphone-ipad-and-mac`.
- Needs from other changes: `add-tv-guide-grid` shows Remind me on future programmes in the guide panel. `add-tv-channel-overlay` makes the overlay's next programmes selectable rows. `add-search` takes reminders into scope with a bell on future guide results. `add-sources-and-settings` adds a Reminders row with the upcoming count. `add-guide-on-iphone-ipad-and-mac` places Remind me after Watch in its guide.
- Blocked on: a decision that adds reminders to the records synced through iCloud, together with the records `add-watch-progress-sync` adds. The requirements assume reminders sync. The alternative is reminders that stay on the device where they were set.
