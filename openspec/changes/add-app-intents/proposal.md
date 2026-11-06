# Proposal

## Why

> As a user, I want to start watching from Siri, Shortcuts or the Apple TV home screen, without opening the app and navigating.

A user who knows what they want has to open Antenna and browse for it. Asking Siri for a channel from the lock screen, an automation that puts the news on at 7, or a Back Tap that favorites the playing channel are all impossible, because Antenna offers nothing to Siri or Shortcuts. The channel catalogue, search and title detail now define what such a request can be matched against.

Not reviewed yet.

## What Changes

- Four actions for Siri and Shortcuts: tune a channel, play a movie or series, open Search (optionally with a query), and add, remove or toggle a favorite.
- Five Siri phrases on iPhone and iPad, among them "Add this channel to favorites in Antenna" and "Remove this channel from favorites in Antenna".
- Picking a channel by name or number, and a movie or series by name, with Siri asking which when two match.
- Suggested channels and titles in Shortcuts: favorites, then other channels; titles in progress, then My list.
- Changing a favorite without opening the app, with a spoken reply.
- Plain replies for every failure: not unlocked, no sources, offline, still loading, login not on this device, phone not yet unlocked after a restart, locked group, and a channel, title or source that is gone.
- No action, reply or stored reference exposes a stream link or password.
- Shortcuts that users saved keep working across app updates.
- On the Mac the actions are in the Shortcuts app only. Apple TV ships none.

Out of scope:
- Spotlight results for channels and titles.
- Widgets, Control Center controls, Live Activities, Focus filters and custom reply views.
- Episodes by name, such as "play season 2 episode 3".
- Guide programmes and reminders.
- Pause, resume, mute and volume.
- Handoff and setting up from the iPhone.
- The Apple TV Top Shelf.
- Siri Suggestions learned from use.
- Any action or Siri phrase on Apple TV.
- Storing anything new, such as a copy of the channel list for offline use.

## Capabilities

### New Capabilities
- `app-intents`: Siri and Shortcuts actions to tune a channel, play a title, open Search and change a favorite, on iPhone, iPad and Mac.

### Modified Capabilities
- `m3u-playlists`: channel ids no longer contain the stream link, because Shortcuts stores them and syncs them through iCloud.

## Impact

- Platforms: iOS, iPadOS, macOS. tvOS ships none.
- Depends on: `source-management`, `favorites`, `channel-catalogue`, `xtream-vod-client`, and the changes `add-first-run-onboarding`, `add-live-tv-on-iphone-ipad-mac`, `add-movies-and-series-browsing`, `add-search`, `add-group-management`, `add-session-restore-and-recently-watched`, `add-watch-progress-sync`.
- Needs from other changes: `add-live-tv-on-iphone-ipad-mac` accepts requests to tune a channel and open Search on iOS, iPadOS and macOS. `add-search` runs a preset query without the typing delay. `add-movies-and-series-browsing` plays a title by reference. `add-group-management` supplies lock and hide checks.
- Blocked on: the decision `add-watch-progress-sync` is blocked on, which adds watch progress, My list entries and recent searches to iCloud sync, for the progress and My list suggestions.
- Follow-up decision: freezing the text formats of the channel and title references stored in users' Shortcuts libraries, since they cannot change once shipped. Until then the formats in design.md hold.
