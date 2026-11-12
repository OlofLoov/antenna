# Proposal

## Why

> As a household setter-upper, I want sources I add on one device to appear on my other devices, so I never type a URL or password twice.

> As a household setter-upper, I want to type long details on my iPhone instead of with the TV remote, so setting up an Apple TV is not a chore.

Logins live only in the Keychain, and Apple TV has no iCloud Keychain. A source that syncs to an Apple TV arrives without its login, so today the user types the Xtream username and password, the Stalker MAC address, or the Jellyfin login with the Siri Remote, once per source and once per Apple TV. The iPhone in their hand already has that login. After this change the user scans a code on the TV's "Sign in on this Apple TV" step, taps Send on the iPhone, and the TV signs in by itself.

Reviewed by the owner on 2026-11-12, who approved the rule change below.

## What Changes

- The Apple TV's sign-in, in onboarding and in a source's details in Settings, shows a QR code next to the fields when the TV is signed in to iCloud. The code holds a one-time public key the TV makes for that code, a random code, and which sources need a login. No secret.
- Scanning it, or accepting the Handoff offer, opens a "Sign in your Apple TV" sheet on iPhone, iPad or Mac that lists the sources the TV asked for and whether this device has each login. A login the device lacks can be typed there; it is checked with the server first.
- On Send, the device encrypts the logins so that only the TV holding the matching private key can open them, and puts the sealed box in the user's private iCloud database. The TV picks it up, deletes it, checks each login with the server the way its sign-in does, and keeps the ones that work in its own Keychain.
- The code works once and for ten minutes. The TV keeps its private key in memory only, and a sealed box nobody picked up is deleted after ten minutes.
- The QR card from `add-iphone-as-setup-device` carries the same key, so a login source set up from the iPhone brings its login with it, and the TV's "Waiting for the login…" state, drawn for this change, becomes real.
- Copy for every failure on both sides, VoiceOver and Reduce Motion behavior, and a split between what simulators can test and what needs two devices.

**Rule change, approved 2026-11-12.** The project rule says secrets live only in the synchronizable iCloud Keychain and never anywhere else, and `add-iphone-as-setup-device` says no password travels in iCloud records. This change puts a login in an iCloud record: sealed to a key that exists only in one Apple TV's memory, for at most ten minutes, then deleted. The narrow exception that replaces it is in design.md. Nothing travels over the local network, so that rule stays as it is.

Out of scope:
- Keeping logins on Apple TV in iCloud for good, so a second Apple TV or a reinstall signs in without the iPhone. That is the broader decision first-run onboarding names.
- Sending logins from the Apple TV to the iPhone, or between two iPhones.
- Devices on different iCloud accounts. The sealed box lands in the sender's own iCloud, which a TV on another account cannot read.
- A QR code on the playback error's sign-in, which opens the source's details where the code shows.
- Scanning a provider's own QR code.
- Sending a Jellyfin access token. The TV signs in with the username and password and gets its own.
- M3U playlists, which have no login.

## Capabilities

### New Capabilities
- `apple-tv-login-from-iphone`: sending a source's login from an iPhone, iPad or Mac to an Apple TV by QR code or Handoff, sealed to a one-time key the TV shows.

### Modified Capabilities
- `iphone-as-setup-device`: the setup link carries the TV's one-time public key as well as the random code, and a login source set up from the iPhone sends its login to the TV.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `add-iphone-as-setup-device` for the setup link, the pairing code, the link and Handoff handling, the QR card and the fallback page. This change extends its link to version 2 and reuses the rest. Also `add-first-run-onboarding` (the Apple TV sign-in step), `add-sources-and-settings` (Sign in on this Apple TV in a source's details), `add-channels-dvr-source` (its optional proxy login), `source-management` and `jellyfin-live-tv-source`.
- New: a CloudKit record zone in the user's private database, outside SwiftData, holding sealed boxes for up to ten minutes. No SwiftData schema change.
- Blocked on: the hosting decision `add-iphone-as-setup-device` is blocked on, since the code is the same link.
