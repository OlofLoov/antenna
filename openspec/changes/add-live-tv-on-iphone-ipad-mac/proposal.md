# Proposal

## Why

On a phone or at a desk people browse with a finger or a pointer while something plays. Today Antenna opens every channel in a separate full-screen player, so the picture stops each time the user goes back to the list. TiviMate's channel list, with the picture running beside it, is what IPTV users expect, and it fits an iPad or Mac window and an iPhone screen.

User stories served:
- "As a viewer, I want to see what is on now and next without leaving the picture, so I can decide whether to stay."
- "As a viewer, I want to browse live channels by group on iPhone, iPad and Mac, so the phone and computer are as useful as the TV."
- "As a viewer, I want my favorite channels together in one list, across all my subscriptions and devices."

## What Changes

- iPad and Mac get a sidebar with the app's sections and the channel groups, the channel list with a filter field, and the player with details about what is on now and next. Columns fold away in narrow windows and in Split View.
- iPhone, and iPad in a narrow Split View, get the player pinned at the top, a now-playing line, group chips, the channel list, and a tab bar with Live, Guide, Movies, Search and Settings. Series sits inside Movies.
- Picking a channel plays it in place.
- Groups, including Favorites and All channels.
- Typing filters the current group by name or number, on iPad and Mac only. iPhone uses Search.
- A star adds and removes favorites.
- Player controls, a Picture in Picture button on iPhone and iPad, and full screen.
- The screen shows loading, partial and total source failure, offline, no channels, and nothing picked yet.
- Keyboard shortcuts on Mac and on iPad with a keyboard.
- With no source at all, onboarding shows instead.
- **BREAKING** On iOS, iPadOS and macOS this replaces the separate full-screen player and the Channels tab, and the Favorites tab becomes a group inside Live. How favorites are stored and synced stays the same.

Out of scope:
- The Guide, Movies, Series and Search screens.
- What the Sources and Settings screens contain.
- How the player picks its playback path, and its buffering and error messages.
- How Picture in Picture behaves, including starting it when the user leaves the app. This change only places the button.
- Sound continuing in the background.
- Rewinding live TV and catch-up. The progress bar shows how far the current programme has run.
- Reloading channels when a source changes.
- Reopening the last channel on launch.
- Reordering favorites or groups.
- Swipe actions or a context menu on iPhone rows.
- A separate player window on Mac.

## Capabilities

### New Capabilities
- `live-tv-on-iphone-ipad-mac`: the Live screen on iPhone, iPad and Mac, with groups, a channel list, an in-place player, favorites by star, and the loading and failure states.

### Modified Capabilities
- `favorites`: the Favorites tab gives way to the Favorites group in Live, so the tab's empty state and list order requirements are removed and sync is described against the group.

## Impact

- Replaces the iOS and macOS Channels and Favorites tabs and the full-screen player with the Live screen.
- Depends on: `channel-catalogue`, `guide-data`, `favorites`, `source-management`, change `add-first-run-onboarding` (no sources), change `add-search` (matching rules), change `add-playback-engine` (the in-place player and Picture in Picture). Tests use a stand-in engine until the playback engine ships.
