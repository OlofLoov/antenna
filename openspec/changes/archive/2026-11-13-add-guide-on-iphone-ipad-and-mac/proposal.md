# Proposal

## Why

> As a viewer, I want a guide grid of what is on across channels over the coming days, so I can plan what to watch.

The Apple TV guide grid exists only for Apple TV. The live TV change puts a Guide tab and a Guide sidebar entry on iPhone, iPad and Mac, and today they lead to a placeholder. TiviMate users name the guide as the reason they stay, and the lack of a phone and desktop app as the reason Apple users leave.

Not reviewed yet.

## What Changes

- iPad and Mac: a time grid for the current group under a toolbar with a filter field, day chips, a Now button, zoom buttons and what is playing. Pinch to zoom on iPad; buttons and keys on Mac.
- iPhone, and iPad in a narrow Split View: a channel list where each row scrolls sideways through that channel's programmes from the one on now. No grid, because at phone width a 30-minute column would leave four or five letters of each title.
- Programme details in a popover (iPad, Mac) or a sheet (iPhone), with a Watch button.
- Watch, or tapping a channel, plays it in Live.
- The guide shows no picture. Whatever was playing keeps going, sound included, and is there again in Live.
- The current group is the same one Live uses. Changing it in one changes it in the other.
- Moving through the days the guide covers, and opening at a programme another screen asks for.
- Row text while a guide loads or when it is missing or failed, banners for failed guides and logins still to sync, an empty group, sources loading, and every source failed.
- Keyboard use on Mac and on iPad with a keyboard, wide layout only.
- With no source at all, onboarding shows instead.

Out of scope:
- Reminders.
- Recording, catch-up, Start over and rewinding live TV.
- Downloading, storing and refreshing the guide.
- Searching programmes. The filter here matches channels only.
- A picture-in-picture box inside the guide, and whether the system's PiP window keeps playing.
- The Apple TV guide.
- Hiding, renaming or reordering groups.
- A zoom level that syncs between devices, or a zoom setting.
- Programme artwork in the details.
- Long-press or right-click menus on the guide.

## Capabilities

### New Capabilities
- `guide-on-iphone-ipad-and-mac`: a TV guide on iPhone, iPad and Mac, as a time grid or per-channel rows, from which the user reads about programmes and starts watching.

### Modified Capabilities

None.

## Impact

- Platforms: iOS, iPadOS, macOS.
- Depends on: `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, and the changes `add-first-run-onboarding`, `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-tv-guide-grid`, `add-live-tv-on-iphone-ipad-mac`, `add-search` and `add-playback-engine`. Tests use a stand-in for the player's observable state until `add-playback-engine` ships.
- Needs from other changes: `add-live-tv-on-iphone-ipad-mac` keeps the channel playing while the Guide is open, shares its current group with the Guide, and lets other screens open the Guide on iPhone, iPad and Mac. `add-search` opens this guide when a later programme is picked on iPhone, iPad and Mac. `add-tv-guide-grid` lets its layout take this guide's sizes. `channel-catalogue` gives each channel row an identifier that never contains its stream link. `tvos-shell` makes its screen navigator work on every platform and change the current group.
