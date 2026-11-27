# Proposal

## Why

> As a living-room viewer, I want to pick a film on my iPhone and have it play on the Apple TV, so I don't have to hunt for it with the Siri Remote.

> As a sports fan, I want to look through the guide on my iPhone while the game runs on the TV, and change channel from the phone without the phone taking my provider's only connection.

Browsing a long channel list or a film library is quicker with a thumb than with a remote. Today the only way to get something from the iPhone onto the TV is AirPlay, which streams through the phone: the phone holds the provider connection, the TV loses frame-rate matching and Dolby Vision, and the picture stops when the phone leaves the room. After this change the user taps "Play on Living Room" on a title, a channel, a guide programme or an episode, and Antuna on the Apple TV opens the stream itself. While the TV plays, the phone keeps browsing, sends whatever the user taps next to the TV, and never opens a stream of its own, because many IPTV providers allow one connection at a time.

This uses only Apple's services: the home network between the two devices, and the user's private iCloud database when the TV is not reachable. There is no server of ours.

This is post-v1 unless the owner moves it in. None of the v1 scope decisions of 2026-11-12 to 2026-11-21 cover it, and it does not reopen anything they declined.

## What Changes

- Each Apple TV running Antuna puts a small record in the user's private iCloud database with its name and a public key, and, while Antuna is open on it, listens on the home network.
- iPhone, iPad and Mac show "Play on <TV>" on a title page, a channel, a guide programme's details and an episode, when the iCloud account has at least one Apple TV running Antuna. With more than one TV, the button opens a list of them.
- When the TV is on the same network with Antuna open, the phone sends the request straight to it and the TV starts the stream at once. The two devices prove they share an iCloud account with the keys in those records, with no pairing step.
- Otherwise the request waits in the user's private iCloud database, and the TV offers it the next time Antuna opens there: "From Anna's iPhone: Salt Road. Play?". Requests for a live channel expire after 5 minutes, films, episodes and catch-up after 6 hours, and the TV deletes a request when it plays or dismisses it.
- A request carries only identifiers (which source, which channel, title, episode or programme) and a start position. Never a stream link and never a login.
- After a request goes over the home network, the phone is connected to that TV. A "Playing on Living Room" bar shows what is on, with play and pause. Tapping it opens a sheet with "Play on this iPhone" and "Disconnect".
- While connected, tapping play anywhere on the phone sends to the TV, and the phone opens no stream: the Live tab's picture, the Guide's playing bar and multi-view show artwork in place of video, and multi-view cannot start.
- The TV keeps its own rules: a locked group or hidden adult content asks for the passcode on the TV, the TV plays in its own profile, and a source whose login has not reached the TV says so on both devices.
- Antuna cannot open itself on an Apple TV. An iPhone app has no way to launch an app on another device, so the TV app must already be open for the fast path, and the iCloud request waits for it otherwise. The "Play on" list says which TVs are reachable now.

Out of scope, kept for later:

- A full remote on the phone: scrubbing, timeshift, start over, audio and subtitle choice.
- A Live Activity or Lock Screen remote.
- Moving playback from one screen to another mid-stream beyond "Play on this iPhone". Continue watching already carries a film's place between devices.
- Sending to another iPhone, iPad or Mac, or from an Apple TV to a phone.
- Sending to an Apple TV on a different iCloud account, and any pairing flow for one.
- Turning the TV on or opening Antuna on it.

## Capabilities

### New Capabilities

- `play-on-apple-tv`: finding the user's Apple TVs, sending a title, channel, programme or episode to one over the home network or through iCloud, the TV's offer for a waiting request, and the phone's connected state with its one-stream rule.

### Modified Capabilities

None. The screens that gain a button or stop their video while connected keep their requirements as they are when the phone is not connected; the new capability says what changes while it is.

## Impact

- Apps: `Apps/Shared` gains a play-request model, a local-network listener for tvOS and a browser for iOS and macOS on Network.framework, a CloudKit store for the TV registry and the request queue, the "Play on" control, the connected bar and sheet, and the TV's offer. Live, Guide, Title, episode rows and multi-view read one "connected" environment value.
- AntennaCore: the request and device-record formats, their encoding, expiry rules and the key derivation inputs, as pure Swift with tests.
- Info.plist and `project.yml`: `NSBonjourServices` on all three app targets and new `NSLocalNetworkUsageDescription` text that names the Apple TV. No new entitlement: iCloud, CloudKit and push are already there.
- CloudKit: two new zones in the private database outside SwiftData, `PlayDevices` and `PlayRequests`. SwiftData's schema does not change.
- `docs/architecture/c4-container.drawio.svg`: the iCloud edge also carries play requests and device records, and a new edge from the app to another device's app over the local network. No new container or external system.
- Depends on `apple-tv-login-from-iphone` for the pattern of a short-lived record in its own CloudKit zone, and on the existing playback, catch-up and watch-progress capabilities on tvOS. Nothing blocks it.
- Needs two real devices on one iCloud account to check the network path and the local network prompt on tvOS; the simulator cannot show the prompt.
