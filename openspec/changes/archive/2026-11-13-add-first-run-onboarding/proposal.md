# Proposal

## Why

A new user opens Antenna and sees an empty Channels tab with a sentence pointing at Settings. People coming from TiviMate expect the app to ask for their playlist straight away, show what it found, and drop them into live TV. Adding a provider in Settings gives no feedback beyond the sheet closing, so the user cannot tell whether it worked.

User stories served:
- "As a new user, I want to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing."
- "As a household setter-upper, I want sources I add on one device to appear on my other devices, so I never type a URL or password twice."
- "As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text."

## What Changes

- A welcome screen when the user has paid and has no provider yet, with a short "What is a source?" explanation.
- Three kinds of provider: an M3U playlist (a link to a channel list), an Xtream login (server, username and password), or a Stalker portal (portal address and MAC address, plus a login and password only when the provider gave one).
- The details are checked before anything is saved, with clear messages when the check fails.
- A checklist fills in as channels, movies and the programme guide load, with real numbers.
- The user can start watching before the guide has finished loading.
- On iPhone and iPad, Antenna offers to fill the form from a link the user has copied.
- A second provider can be added from the last step.
- On Apple TV, the user signs in again when providers synced from another device arrive without their passwords, or for a Stalker portal without its MAC address.

Out of scope:
- Buying Antenna. Onboarding assumes the user has paid.
- Importing a playlist file from the device.
- Editing or deleting a provider.
- Turning off the programme guide for an Xtream provider.
- More than one guide per playlist.
- Refreshing providers later. Resuming a guide download after relaunch belongs to `guide-data`.
- How playback itself behaves once the first channel starts.

## Capabilities

### New Capabilities
- `first-run-onboarding`: the welcome, add-provider, loading checklist and summary flow for a user with no provider, and the Apple TV sign-in for providers synced without a password.

### Modified Capabilities
None.

## Impact

- Shared onboarding views on every platform, and tvOS screens under the shell.
- Reuses source validation and saving from `source-management`, the Xtream client from `xtream-vod-client`, channel order from `channel-catalogue` and guide loading from `guide-data`.
- Depends on: `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, `xtream-vod-client`, `stalker-portal-source`, change `add-live-tv-on-iphone-ipad-mac`.
- Blocked on: a decision on where a password typed on an Apple TV is kept. The project rule is that secrets sync through iCloud Keychain, which Apple TV does not offer. Until that is decided, a password typed on an Apple TV stays on that Apple TV. If the decision picks another store, the Apple TV sign-in requirement follows it.
