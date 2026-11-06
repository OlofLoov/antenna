# Proposal

## Why

> As a viewer, I want the app to come back to the channel I was watching, and to find recently watched channels quickly.

On iPhone, iPad and Mac the app forgets everything at launch. The user lands with nothing playing, in All channels, and has to find the channel they were watching five minutes ago. On every device the channels a user returns to are buried among thousands, and Favorites only helps once the user has curated it. TiviMate users name its recently watched list among the things they like, and returning to the last channel is what every TV does.

Not reviewed yet.

## What Changes

- A Recents group on every device, with the channels watched for at least ten seconds, newest first, up to 20.
- Recents sits between Favorites and All channels in the group chips on iPhone, in the sidebar on iPad and Mac, and in the Apple TV channel overlay.
- iPhone, iPad and Mac reopen where the user left off: the tab, the group and the playing channel, including after the system closed the app in the background.
- On Apple TV during full-screen playback, swipe left plays the previous channel and swipe right opens the channel overlay on Recents.
- A deleted source's channels leave Recents and what is restored, whether it was deleted on this device or another.
- The last channel that the Apple TV already restores at launch moves into the same on-device store.

Out of scope:
- Syncing recents or the restored session between devices.
- Apple TV launching into the last channel, which `tvos-shell` owns.
- Restoring the current group on Apple TV at launch.
- Clearing or editing recents, or turning recording off.
- Restoring Search, Settings or a movie detail page.
- Resuming a position inside a movie or episode.
- Separate sessions per window on Mac and iPad. One session is kept, for the first window.
- Recent searches, which belong to `add-search` and `add-watch-progress-sync`.
- Top Shelf or Siri suggestions built from recents.
- Reloading channels when a source is added or edited.

## Capabilities

### New Capabilities
- `session-restore-and-recently-watched`: a per-device Recents group, reopening where the user left off, and previous-channel swipes on Apple TV.

### Modified Capabilities
- `channel-catalogue`: the group list gains Recents between Favorites and All channels, and Recents can be replaced without a rebuild.
- `tvos-shell`: the last channel restored at launch comes from the shared on-device store, and M3U channels whose ids still hold the stream link are not restored.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `source-management`, `channel-catalogue`, `tvos-shell`, and the changes `add-first-run-onboarding`, `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-live-tv-on-iphone-ipad-mac`, `add-movies-and-series-browsing`, `add-playback-engine`.
- Needs from other capabilities and changes: `m3u-playlists` takes the stream link out of M3U channel ids. `channel-catalogue` adds a Recents group. `tvos-shell` reads the last channel from this store and notes its M3U restore is suspended until the `m3u-playlists` follow-up. `add-tv-channel-overlay` lists Recents after Favorites and opens on a given group. `add-tv-zap-bar-and-number-entry` gives left and right swipes to this change. `add-live-tv-on-iphone-ipad-mac` lists Recents after Favorites and shows loading with the restored channel playing. `add-movies-and-series-browsing` leaves live before playing a movie or episode.
