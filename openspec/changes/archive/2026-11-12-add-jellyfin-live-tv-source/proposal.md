# Proposal

## Why

> As a user of a less common service (a Stalker portal, Jellyfin, Channels DVR) or of a playlist file on disk, I want to use it like any other source.

> As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text.

Jellyfin is a media server people run at home, and many already have a TV tuner or a playlist set up in it with a guide the server keeps fresh. A Jellyfin user who wants those live channels in Antenna today has to copy the same playlist in by hand and loses the server's guide. Jellyfin is the first home server after Xtream on the roadmap, and nothing in Antenna can talk to it.

Not reviewed yet.

## What Changes

- A Jellyfin source: the server address, plus a username and password kept in the Keychain as for Xtream. No new field on the synced source.
- Connect checks that the address points at a Jellyfin server before signing in.
- Each device signs in on its own and keeps its own sign-in key, so revoking one device on the server leaves the others working.
- A turned-down key leads to one new sign-in, then the request is repeated.
- Live TV channels load page by page and show in the catalogue.
- The programme guide is fetched for groups of channels and handed to the guide.
- Stream addresses carry the key. Logo addresses do not.
- Errors say what went wrong and never contain the username, password, key or server address.

Out of scope:
- Recordings and timers.
- Quick Connect (signing in with a code shown on another device).
- Finding servers on the home network automatically.
- Jellyfin's movie, series and music libraries.
- Asking the server to convert streams to another format.
- Trusting self-signed certificates.
- Emby servers.
- Copying Jellyfin's favorites into Antenna.
- The app's own key store, which waits for the decision on where the per-device key lives.
- Any screen.

## Capabilities

### New Capabilities
- `jellyfin-live-tv-source`: signing in to a Jellyfin server and reading its Live TV channels, guide and stream addresses.

### Modified Capabilities
- `guide-data`: takes programmes straight from a source that serves them in batches, instead of downloading an XMLTV file.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS. AntennaCore only, no UI.
- Depends on: `xtream-live-source`, `source-management`, `channel-catalogue`, `guide-data`, `xtream-vod-client`.
- Needs from `add-first-run-onboarding`: the Jellyfin card, wording for a forbidden account and an untrusted certificate, and Jellyfin sources in its Apple TV sign-in step.
- Needs from `add-live-tv-on-iphone-ipad-mac`: a "Sign in again" row.
- Needs from `guide-data`: a revision that takes programmes from the client.
- Follow-up decision owed: where the per-device Jellyfin sign-in key lives. The project rule is that every secret lives in the synchronizable iCloud Keychain, but Jellyfin ties its key to the device that asked for it, so it must not sync. Until that decision exists the app keeps the key in memory and signs in once per launch. The requirements hold either way.
