# Proposal

## Why

> As a user of a less common service (a Stalker portal, Jellyfin, Channels DVR) or of a playlist file on disk, I want to use it like any other source.

> As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text.

Channels DVR is a TV server people run at home, with a tidy channel lineup, the user's own channel numbers and a matching guide. Channels DVR users on Apple TV have no player that keeps those numbers and ids. Players renumber by playlist order and show broadcaster call signs such as "KGWDT" instead of "NBC". Adding the server as a plain playlist today means typing two long links with settings in them on a TV remote, and every favorite breaks when the server's home network address changes. Treating the server as its own kind of source fixes all three in one place, and gives recordings a home later if the owner decides to ship them.

Not reviewed yet.

## What Changes

- A Channels DVR source kind. The user types one address, and Antenna works out the playlist, guide and status addresses from it.
- A status check that tells a Channels DVR server apart from a wrong address, a server still starting up, and a device that is offline.
- Channel names, numbers (including over-the-air numbers like 6.1) and ids taken from the server's lineup.
- An optional username and password for a reverse proxy (a web server in front of Channels DVR that asks for a password), kept in the Keychain. The form keeps these fields hidden until playback can send the password with streams.
- The source loads alongside others without one failing server holding up the rest.
- Streams are requested in the format Apple's player plays today.

Out of scope:
- Recordings, schedules and the recordings library, until the owner decides on recording.
- The sign-in key that Channels DVR's own remote-access addresses need.
- Finding servers on the home network automatically.
- The add-source form and the loading checklist rows.
- Showing the server version and reachability in Settings.
- Choosing stream format, bitrate or codec per source.
- Channels DVR collections, favorites, hidden channels and filtered exports.
- Channels DVR's own app interface, TV Everywhere logins and channel management.
- Keeping the playlist between launches.
- Sending the proxy password with stream requests.

## Capabilities

### New Capabilities
- `channels-dvr-source`: adding a Channels DVR server by one address and reading its lineup, numbers and guide.

### Modified Capabilities
- `m3u-playlists`: a title-first name option and a minor channel number.
- `channel-catalogue`: channel numbers with a part after the dot, ordered and shown as major and minor.
- `guide-data`: a guide address worked out from the source, sent with the proxy password.
- `source-management`: a source can load as waiting for its credential.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS. AntennaCore only, no UI.
- Depends on: `m3u-playlists`, `xmltv-guide-parsing`, `source-management`, `channel-catalogue`, `guide-data`, `xtream-vod-client`.
- Needs from `m3u-playlists`: a title-first name option and a minor channel number. The requirements on channel names and the guide wait on it.
- Needs from `source-management`: a loader that can report a source waiting for its credential. The credential requirement waits on it.
- Needs from `add-first-run-onboarding`: the Channels DVR card, a Server field, error wording, the local-network hint, and Channels DVR sources in its Apple TV sign-in step.
- Needs from `add-live-tv-on-iphone-ipad-mac`: an unreachable server shown as a failed source.
- Needs from `add-tv-zap-bar-and-number-entry`: a way to type a number like 6.1 with the remote.
- `project.yml` gains a local network usage description.
