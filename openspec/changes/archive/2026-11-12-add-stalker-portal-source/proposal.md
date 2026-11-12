# Proposal

## Why

> As a user of a less common service (a Stalker portal, Jellyfin, Channels DVR) or of a playlist file on disk, I want to use it like any other source.

> As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text.

Antenna can save a Stalker source today but loads nothing from it, so a user whose provider only offers a portal sees an empty app after paying. A portal is addressed by its URL and a MAC address, not by a playlist link or a username. It also hands out each stream address at the moment the user tunes, with a short-lived key in it, so Antenna cannot build stream addresses ahead of time the way it does for Xtream.

Not reviewed yet.

## What Changes

- Antenna reads the MAC address the user types, in the forms providers write it, and accepts the portal address in the forms providers hand out.
- It signs in to the portal, with an optional login and password when the portal asks for one.
- It loads genres and channels into the catalogue.
- It asks the portal for a stream address each time the user tunes.
- It reads the portal's own programme guide for the guide data.
- It renews the portal's session key (a password the portal hands out for each sign-in) once when the portal stops accepting it.
- Errors say what went wrong and never contain the MAC, login, password or session key.
- The MAC, login and password stay in the Keychain, and the Keychain item gains a login field.
- **BREAKING** for the stored behavior of `source-management`: a Stalker source now loads channels instead of contributing none.

Out of scope:
- Any screen. The form, its wording and the loading checklist belong to `add-first-run-onboarding` and `add-sources-and-settings`.
- Downloading, scheduling and size limits for the guide, which `guide-data` owns.
- Portals that hand out their channel list in pages.
- Movies, series and radio from the portal.
- Catch-up and timeshift, which belong to `add-timeshift-catch-up-and-start-over`.
- Recording, parental lock and messages from the portal.
- Playing the stream, and asking for a new address when one expires mid-stream, which belong to `add-playback-engine`.
- The screens for a source whose credential has not synced yet, which onboarding, live TV and the Apple TV shell already cover.
- A custom serial number or device id per source.
- Spotting an Xtream service behind the same portal.

## Capabilities

### New Capabilities
- `stalker-portal-source`: signing in to a Stalker (Ministra) portal with a MAC address, loading its channels by genre, resolving stream addresses at tune time, and reading its guide.

### Modified Capabilities
- `source-management`: a Stalker source stores an optional login and contributes its channels instead of none.
- `guide-data`: a Stalker source without a guide address uses the portal's own guide.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore and the app's Keychain mapping, no UI).
- Depends on: `xtream-live-source`, `source-management`, `channel-catalogue`, `guide-data`, `xtream-vod-client`.
- Needs from other changes: `add-first-run-onboarding` enables the Stalker card with Portal, MAC, Login and Password fields, wording for each Connect error, and Stalker sources in its Apple TV sign-in step. `add-sources-and-settings` adds the same fields to its edit form. `guide-data` gains a path for a Stalker source without a guide address.
- Supersedes the "Stalker contributes no channels" behavior of `source-management` and the disabled Stalker card in `add-first-run-onboarding`.
- Was blocked on a tune-time step in the playback path and on CryptoKit for the device identity. Both are settled under "Implementation decisions" in design.md: a resolver called before each tune, and MD5 and SHA-256 written out in AntennaCore.
