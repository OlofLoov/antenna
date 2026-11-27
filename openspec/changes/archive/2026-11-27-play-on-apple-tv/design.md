# Design

## Context

See proposal.md for the why. What exists today and shapes this:

- The Apple TV login drop (`apple-tv-login-from-iphone`) already keeps short-lived records in its own zone, `LoginDrops`, of the user's private CloudKit database, outside SwiftData, with a sweep each time the scene becomes active (`LoginDropSweep`). The pieces here follow it.
- Every app target already has the iCloud and CloudKit entitlements, `aps-environment` and the `remote-notification` background mode, so a silent CloudKit push needs no new entitlement.
- `NSLocalNetworkUsageDescription` is already in the iOS and tvOS Info.plist, for sources on a home server. No target declares `NSBonjourServices`.
- Apple TV has no iCloud Keychain, so no secret can reach it by sync. That is why the design below sends no secret at all.
- Playback on each device goes through `AppEngine` and `PlayerModel` in `Apps/Shared/Player`; multi-view adds tiles through `AppEngine+MultiView`. Every stream a device opens starts there.
- On tvOS, `TopShelfInbox` holds an incoming item until the shell takes it, behind the paywall and setup gates. Reminders, Siri and Top Shelf already start playback from an id on the TV, through the same lock and adult-content checks.
- Ids: a source is a `UUID`, a channel's `Channel.id` is a `String` unique within its source, a programme is its channel id plus its start, a film is a `VODItem` id and an episode is a series id plus an `Episode` id.

## Goals / Non-Goals

**Goals:**

- A request reaches an open Apple TV on the same network in under a second, measured from the tap to the TV starting to tune.
- No server of ours, no secret in CloudKit, no change to the secrets rule.
- One place on each device decides whether a play starts here or goes to a TV, so the one-stream rule cannot be skipped by a screen that forgets.
- The phone's code paths for playing locally stay as they are when it is not connected.

**Non-Goals:**

- Starting Antuna on the TV, waking the TV, or keeping a listener alive while Antuna is in the background on tvOS. tvOS suspends a background app and no API lets another device launch it.
- A general remote: only play, pause, "Play on this iPhone" and Disconnect cross the link.
- Devices on other iCloud accounts.

## Decision: how the request reaches the TV

1. **CloudKit only.** The phone saves a record, the TV gets a silent push and fetches it. Works away from home and with the TV app closed, one code path, no permission prompt. But a save, a push and a fetch take one to several seconds when things go well, silent pushes are throttled and may not arrive at all, and there is no channel back for the TV's state, so the "Playing on" bar and play and pause from the phone cannot be built on it. Rejected as the only path.
2. **Home network only.** Bonjour and a TCP connection from Network.framework. Tens of milliseconds on a home network and a live channel both ways. But it works only while Antuna is open on the TV, only on the same network, and only after the user allows local network access on the phone. A request for a closed TV would fail. Rejected as the only path.
3. **Both (chosen).** The phone uses the network when the TV is advertising and answers, and saves a CloudKit request otherwise. The connected state exists only over the network, because only the network carries the TV's state back.
4. **DeviceDiscoveryUI.** tvOS's framework for finding a nearby iPhone or iPad. The TV starts it: the viewer opens a picker on the TV with the Siri Remote, picks the phone, and approves on the phone the first time. It suits a TV app that wants a phone as a game controller. Here the direction is backwards (the user is holding the phone, not the remote), it shows a system pairing confirmation, and it does not cover the Mac as a sender. Rejected; a later "use the iPhone as a remote, started from the TV" could use it.
5. **Handoff, AirPlay, Multipeer Connectivity.** Handoff has no iPhone to Apple TV direction. AirPlay streams from the phone, so the phone keeps the provider connection and the TV loses frame-rate matching and the FFmpeg path; it stays available as it is today. Multipeer Connectivity runs on Bonjour too, but hides the TLS setup this design needs to authenticate by iCloud account. Rejected.

Fallback order on the phone when the user picks a TV: if the browser has a current endpoint for it, connect and send, and give up after 3 seconds without an acknowledgement; on failure, or with no endpoint, save the CloudKit request. A request is never sent both ways at once, so the TV cannot play it twice. If the network send timed out after the TV took it, the TV ignores the CloudKit copy with the same request id.

## Decision: how a TV is found and named

Each device that runs Antuna, phone or TV, keeps one record about itself in the private database:

- Zone `PlayDevices`, record type `PlayDevice`, record name `device-<deviceID>`.
- Fields: `kind` (`tv`, `phone`, `pad`, `mac`), `name` (String), `publicKey` (Bytes, the P-256 key-agreement public key, X9.63), `keyDate` (Date), `lastSeen` (Date), `version` (Int64, 1).
- `deviceID` is a random UUID made on first launch and kept in UserDefaults under `playOn.deviceID`. It is not a secret and not a stream link, so it fits the per-device state rule.
- A device writes its record each time it starts and when it returns to the foreground with a new key or a `lastSeen` older than a day. The save policy is `.changedKeys`; only the owner of a record writes it, so conflicts do not occur.
- The sweep that already runs on scene activation also deletes `PlayDevice` records with `lastSeen` older than 60 days.

The name is `UIDevice.current.name` on iOS and tvOS and `Host.current().localizedName` on the Mac. Since iOS 16 an app sees the user's device name only with the `com.apple.developer.device-information.user-assigned-device-name` entitlement, which Apple grants on request; without it the iPhone reports "iPhone". The TV's offer then reads "From iPhone", which is still correct. Group 1 checks what tvOS 26 returns for the TV's name on a device; if it is only "Apple TV", the list numbers TVs that share a name ("Apple TV 2") by record creation date, as the spec says, and a rename field in the TV's Settings is a follow-up.

The phone lists a TV when its `PlayDevice` record with kind `tv` exists. Whether it is "Ready now" comes from Bonjour: the TV's instance name is its `deviceID`, so the phone matches what it browses to the records it already trusts. A Bonjour instance that matches no record is ignored, which keeps a guest's TV out of the list without the TV's name ever going on the network.

## Decision: Bonjour, the listener and the permission prompt

- Service type `_antenna-play._tcp` (12 characters, under Bonjour's limit of 15). Code names keep "Antenna"; nobody sees this string.
- `NSBonjourServices = [_antenna-play._tcp]` in the iOS, tvOS and macOS targets in `project.yml`.
- `NSLocalNetworkUsageDescription` becomes "Antuna finds your Apple TV and connects to TV servers on your home network." in `project.yml` and `InfoPlist.xcstrings`, translated for each language in `Config/languages`.
- TV: an `NWListener` with `NWListener.Service(name: deviceID, type: "_antenna-play._tcp")`, TXT `v=1`, started when the scene becomes active past the paywall and signed in to iCloud, cancelled when it goes to the background.
- iPhone, iPad, Mac: an `NWBrowser` for the same type, running only while the scene is active, and only once the user has opened Play on at least once while the account has a TV record (`playOn.browsing` in UserDefaults). iOS shows the local network prompt when the browser first starts, so the prompt appears right after the user's first tap on Play on and never for someone without an Apple TV. If the prompt is refused, the browser reports `.waiting` with a policy-denied error; the phone then lists every TV as "Plays when Antuna opens there" and adds a row that opens the app's Settings.
- The Mac app is sandboxed; it already has the outgoing network entitlement, and the browser and outgoing connection need nothing more. Only the TV listens.
- tvOS: group 1 records on a device whether tvOS 26 shows a local network prompt for a listener. If it does, the prompt appears the first time Antuna opens on the TV after this ships, which is acceptable since the TV app is where the user looks.

## Decision: proving both ends share the iCloud account

Only devices signed in to the account can write records in its private database, so the `PlayDevices` zone is the list of the account's devices. The link uses that, with no pairing:

- Each device makes a P-256 key-agreement key pair at launch and keeps the private key in memory only, as the TV's login key does. Nothing new goes in the Keychain, so the secrets rule does not change. The public key goes in its `PlayDevice` record.
- The connection is TLS with a pre-shared key, set with `sec_protocol_options_add_pre_shared_key`, using the PSK cipher suite and TLS 1.2 maximum as Apple's Network.framework peer-to-peer sample does. The key is HKDF-SHA256 over the ECDH shared secret of the sender's private key and the TV's public key, salt `antenna-play-v1`, info the sender id, the TV id and both `keyDate`s. The PSK identity is the sender's `deviceID`.
- The TV looks up the identity in its copy of `PlayDevices`. An unknown id triggers one fetch of the zone (a few hundred milliseconds, and only for the first send from a device that just started); still unknown, or a handshake that fails, closes the connection with nothing shown on the TV.
- The phone fetches `PlayDevices` when its scene becomes active and when Play on opens, so it has the TV's current key before the user picks it.

Options considered:

1. **No authentication, opaque ids.** A guest would need a source id to play anything, but could still drive the TV and read its state. Rejected.
2. **A pairing code shown on the TV.** Out of scope for v1 of this feature, and the iCloud account already answers the question.
3. **A random token in each TV's record, in `encryptedValues`.** Simpler than ECDH, but it is a bearer secret in CloudKit, which would need a new exception to the secrets rule. Rejected.
4. **ECDH over published public keys (chosen).** Only public data in CloudKit, both ends authenticated, no prompt.

The cost is that a key changes every launch, so a phone holding a TV's old key fails the handshake once after the TV restarts; the phone then refetches the zone and retries once before falling back to iCloud.

## Decision: what goes over the link

Length-prefixed JSON frames over the TLS connection, through an `NWProtocolFramer` (4-byte big-endian length, then a UTF-8 JSON object with a `type` and `v`). Encoding, decoding and the rules below are pure Swift in AntennaCore with fixtures.

- `play`: a `PlayRequest`.
- `answer`: `{ requestID, result }` where `result` is `started`, `needsPasscode`, `noLogin(sourceID)`, `noSource(sourceID)`, `notFound`, `waiting` (paywall or "Who's watching?") or `unsupportedVersion`.
- `status`, TV to phone, on every change and every 5 seconds: `{ state: playing | paused | stopped, item, title, subtitle, position?, duration?, artworkKey? }`. `artworkKey` names the channel or title so the phone draws the art it already has; no image or link crosses.
- `control`, phone to TV: `play`, `pause`, `handOff` (TV stops and answers with its position) and `disconnect` (TV keeps playing and forgets this phone).

`PlayRequest` in AntennaCore, `Codable`, `Sendable`, `Hashable`:

```swift
public struct PlayRequest {
    public var version: Int                // 1
    public var id: UUID
    public var sender: UUID                // deviceID
    public var senderName: String
    public var target: UUID                // the TV's deviceID
    public var source: UUID
    public var item: Item
    public var startPosition: TimeInterval?
    public var displayTitle: String
    public var created: Date

    public enum Item {
        case channel(id: String)
        case programme(channelID: String, start: Date)   // catch-up when it has ended
        case movie(id: String)
        case episode(seriesID: String, episodeID: String)
    }
}
```

`PlayRequest.expires(now:)` is 300 seconds after `created` for `.channel` and for a `.programme` on now, and 21,600 seconds for `.movie`, `.episode` and an ended `.programme`. A version above 1 answers `unsupportedVersion`, and the phone asks the user to update Antuna on the TV.

The type's `description` and `debugDescription` print the item kind and ids only, and a test checks that no field can hold a URL: `startPosition` is a number, titles are names. The spec's "a request holds no link and no login" requirement is tested on the encoded JSON.

## Decision: the iCloud queue

- Zone `PlayRequests`, record type `PlayRequest`, record name `request-<target deviceID>`. One record per TV, so a new request replaces the waiting one with save policy `.allKeys`.
- Fields: `payload` (Bytes, the encoded `PlayRequest`, in `encryptedValues`), `expires` (Date).
- Each TV registers one `CKRecordZoneSubscription` on `PlayRequests` with `shouldSendContentAvailable`, and fetches its own record by name on the push, on launch, on returning to the foreground and every 30 seconds while in the foreground, since silent pushes can be held back. The 30-second fetch is one record by id, not a query, so it needs no index.
- On pickup the TV deletes the record, then shows the offer or plays; a request whose id the TV already handled over the network is deleted without an offer.
- The scene-activation sweep deletes `PlayRequest` records past `expires`, by reading the zone as the login sweep does.

This is a new kind of synced record, so it is decided here. It stays out of SwiftData's mirrored zone and needs no migration. Removing the feature later means deleting two zones.

## Decision: one place decides where a play goes

`PlayDestination`, an `@Observable` on the main actor in `Apps/Shared/PlayOn/`, holds `.here` or `.tv(PlayOnConnection)` and is provided through one `@Entry` value, `playDestination`. Every play action on iPhone, iPad and Mac calls `PlayDestination.play(_:)` with a `PlayRequest.Item`; screens do not call `PlayerModel` to start a stream any more.

- `.here` passes through to `PlayerModel` exactly as today.
- `.tv` sends `play` and shows the answer.
- While `.tv`, `AppEngine` refuses to open a stream: its `start` and multi-view's `addTile` return without opening one and log a fault in Debug builds. That backstop is what the one-stream tests check: with a counting fake engine, connect, then go through Live, the Guide, a title page, an episode, Search, a reminder and multi-view, and the open count stays zero.
- Before the first `play` to a TV, the phone stops every engine it has open (stop, not pause, so the HTTP connection and the FFmpeg demuxer close), closes Picture in Picture, and waits for the engine to report it stopped. Only then does it send, so the provider sees one connection.
- Components do not read the destination. Screens pass a `PlayLabel` value (`play`, `resume`, `playOn(name)`, `resumeOn(name)`) and a closure; the Live screen picks `ConnectedPicture` over `PlayerSurfaceView` as a different view, not a `Bool` on one view.
- Trailer is unchanged: on iPhone, iPad and Mac it already opens the link outside Antuna, so Antuna opens no stream for it. The owner listed trailers among things that show art; the spec keeps the button because no in-app trailer stream exists on these devices. If the owner wants the button hidden while connected, it is one scenario and one condition.

`PlayOnConnection` owns the `NWConnection`, the latest `status`, and a 10-second liveness timer reset by each `status`. It ends on Disconnect, a `stopped` status, the timer, a failed connection, or the scene going to the background; then the destination returns to `.here`. On the scene becoming active it reconnects if the TV's last status said it was playing a request from this device, and the destination stays `.tv` until that reconnect fails, so the phone never starts a stream in the gap.

## Decision: the TV side

- `PlayRequestInbox` on tvOS joins `TopShelfInbox`'s pattern: it holds a request outside every gate until the shell takes it. Unlike Top Shelf, a request that arrives behind the paywall or "Who's watching?" is kept, not dropped, and offered once the gate clears (play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile).
- A network request plays at once and shows the four-second "From Anna's iPhone" banner. A CloudKit request shows the offer (`TV-FromIPhone-Offer`).
- Resolving the item uses the catalogue already loaded for the source, waiting up to 10 seconds for the source's first load; a source that is missing or has no login answers `noSource` or `noLogin`. Playback then starts through the path reminders and Top Shelf use, which already runs the group lock and adult-content checks and asks for the passcode.
- A request in multi-view ends multi-view first, then plays full screen.
- `status` comes from the TV's `PlayerModel` and `NowPlaying`, which already know the item, the programme and the position.

## Boards

New boards, in `openspec/specs/design-system/boards/`:

- `iPhone-Title-PlayOn.dc.html`: a film's title page with two TVs on the account and the Play on menu open. Covers play-on-apple-tv/play-on-from-what-can-be-played and the TV list of play-on-apple-tv/apple-tvs-on-the-same-icloud-account.
- `iPhone-Title-Connected.dc.html`: the same page while connected, Play reading "Play on Living Room", and the "Playing on Living Room" bar above the tab bar.
- `iPhone-Live-Connected.dc.html`: Live while connected, the picture area showing the channel's logo and "Playing on Living Room" with play or pause, and the row the TV plays marked.
- `TV-FromIPhone-Offer.dc.html`: the TV's offer for a request that waited in iCloud.

Design-system requirements followed: controls-use-system-styles (the menu and buttons), focus-is-the-lifted-white-card and focus-moves-where-the-remote-points (the offer), apple-tv-content-stays-in-the-safe-area, liquid-glass-stays-on-the-navigation-layer (the bar is a glass capsule on the navigation layer, like the tab bar), targets-are-large-enough-to-hit (44 pt play and pause), channels-without-a-logo-show-initials (the connected picture), copy-fits-in-every-language (labels name the TV, so the bar truncates the item line, never the TV name), accessibility-identifiers-follow-the-board, and modals-are-system-presentations (the connected sheet is a system sheet).

Drawn for groups 2 and 3 (task 1.2):

- `iPhone-Title-PlayOn-Refused.dc.html`: the Play on menu with local network access refused.
- `iPhone-Live-ChannelMenu-PlayOn.dc.html`: a channel row's context menu with "Play on Living Room"; the episode row's menu follows its note.
- `iPhone-Guide-Detail-WatchOn.dc.html`: the Guide programme details with "Watch on Living Room".
- `iPhone-PlayOn-Messages.dc.html`: the line after a send and the error alert, with every message in its note.
- `TV-FromIPhone-Banner.dc.html`: the TV's "From Anna's iPhone" banner for a network request.

Drawn for group 4: `TV-FromIPhone-Offer-Channel.dc.html`, the offer for a channel with its logo tile and the facts line for each kind; the offline line is in `iPhone-PlayOn-Messages.dc.html`.

Drawn for group 5 (task 5.1): `iPhone-PlayOn-Sheet.dc.html`, the connected sheet; `iPad-PlayOn-Bar.dc.html`, the bar at the bottom of an iPad or Mac window, with "Stopped on Living Room" below it.

## Copy

| Where | English |
|---|---|
| Button, one TV | Play on Living Room |
| Button, several TVs | Play on |
| Menu row second line | Ready now / Plays when Antuna opens there |
| Menu row, access refused | Allow local network access |
| Title page Play, connected | Play on Living Room / Resume on Living Room |
| Guide details, connected or not | Watch on Living Room |
| Bar first line | Playing on Living Room |
| Bar after stop | Stopped on Living Room |
| Sheet buttons | Play on this iPhone (iPad, Mac) / Disconnect |
| Sent through iCloud | Sent. Living Room offers it when Antuna opens there. |
| No login on the TV | Living Room isn't signed in to %@. |
| Source not on the TV | Living Room doesn't have %@ yet. Try again in a minute. |
| Not found | Living Room couldn't find %@. |
| Passcode | Enter the passcode on Living Room. |
| Old TV app | Update Antuna on Living Room to play from here. |
| TV behind its paywall or "Who's watching?" | Sent. Living Room plays it once Antuna is ready there. |
| iCloud refused the request for another reason than being offline | Living Room didn't answer. Open Antuna there and try again. |
| Offline | You're offline. Nothing was sent. |
| TV offer facts line | Live channel / Catch-up / Movie · Resumes at 40 min / Episode |
| TV offer eyebrow | From Anna's iPhone |
| TV offer buttons | Play / Not now |

"Living Room" and "Anna's iPhone" stand for the device names. Every string goes through `scripts/sync-strings.sh` and gets translated.

## Identifiers

- `title.playOn`, `title.playOn.menu`, `title.playOn.menu.device`
- `channel.menu.playOn`, `episode.menu.playOn`, `guide.detail.watchOn`
- `playOn.bar`, `playOn.bar.playPause`, `playOn.live`, `playOn.live.playPause`
- `playOn.sheet`, `playOn.sheet.playHere`, `playOn.sheet.disconnect`
- `playOn.sent`, `playOn.error`
- tvOS: `playOn.offer`, `playOn.offer.play`, `playOn.offer.notNow`, `playOn.banner`
- UserDefaults: `playOn.deviceID`, `playOn.browsing`
- CloudKit: zones `PlayDevices` and `PlayRequests`, record types `PlayDevice` and `PlayRequest`, subscription id `play-requests`
- Bonjour: `_antenna-play._tcp`

## Code layout

- `Packages/AntennaCore/Sources/AntennaCore/PlayOn/`: `PlayRequest`, `PlayDeviceInfo`, `PlayMessage` (the frames), `PlayOnKey` (HKDF inputs and output, over CryptoKit-free byte inputs so Core stays Foundation-only; the ECDH itself is in the app), expiry and naming rules (numbering TVs that share a name).
- `Apps/Shared/PlayOn/`: `PlayDestination`, `PlayOnConnection`, `PlayOnBrowser` (iOS, macOS), `PlayOnListener` (tvOS), `PlayDevices` and `PlayRequests` protocols with `CloudKitPlayDevices`, `CloudKitPlayRequests` and in-memory fakes, `PlayOnKeys` (CryptoKit P-256 and HKDF), `PlayRequestInbox` (tvOS).
- `Apps/Shared/Components/`: `PlayingOnBar`, `ConnectedPicture`, `PlayOnMenu`, `FromDeviceOffer`. Values and closures only.
- Screens in `Apps/Shared/Views/` call `playDestination.play(_:)`.

## Testing

- AntennaCore: encoding round trips for every frame and item, unknown versions, expiry per item kind with a fixed clock, the encoded request has no URL-shaped string, TV name numbering, HKDF test vectors.
- App unit tests: PSK derivation agrees on both ends from fixture keys and differs for a third key; `PlayDestination` routes to the fake connection when connected; the counting fake engine stays at zero opens through every play entry point while connected; the phone stops its engine before sending.
- Integration tests against the in-memory CloudKit fakes: replace-on-send, delete on pickup, the sweep, the same request id over both paths played once, an unknown sender refetching once.
- Loopback test: a listener and a connection in one test process on the same machine, through the real TLS-PSK setup, for `play`, `answer`, `status` and a refused identity.
- UI tests with a scripted fake TV: the menu, the bar, Play on a title while connected, the connected Live picture, and the TV's offer with focus on Play.
- Journeys: steps for `iPhone-Title-PlayOn`, `iPhone-Live-Connected` and `TV-FromIPhone-Offer`, anchored on `title.playOn.menu`, `playOn.live` and `playOn.offer`.
- Device checklist, added to `docs/release/device-checklist.md`: tap-to-tune time on one network, the iOS and tvOS prompts, a closed TV app, the phone on mobile data, a guest account on the same Wi-Fi, a TV restart mid-connection, and a provider limited to one connection.

## Risks / Trade-offs

- [Silent pushes are delayed or dropped on tvOS] → The TV also fetches its one record on launch, on foreground and every 30 seconds while open.
- [The local network prompt confuses people] → It appears only after a tap on Play on with a TV on the account, and the new usage text names the Apple TV.
- [A TV restart changes its key and the first send fails] → One refetch and retry, then iCloud.
- [Home networks with client isolation or mDNS blocked between bands] → The TV shows as "Plays when Antuna opens there" and the request goes through iCloud; the offer still works.
- [A screen starts a stream directly and breaks the one-stream rule] → `AppEngine` refuses while connected, and the counting test covers every entry point the spec lists.
- [The provider counts a connection for a few seconds after the phone closes it] → Out of our hands; the phone closes before sending, which is the best order available. The device checklist records how long one provider takes.
- [Device names are generic without Apple's entitlement] → "From iPhone" still reads correctly; the entitlement request is task 1.3.

## Migration Plan

No data migration. The zones are created on first write. Turning the feature off is removing the entry points; the zones can be left or deleted. An old TV build ignores the Bonjour service and the zones, so the phone lists only TVs that wrote a `PlayDevice` record, and an old phone never sends.

## Owner answers

2026-11-27, task 1.1: build it now, without waiting for v1. Trailer stays on the title page while connected, as the one-place decision above proposes.

## Decided while building

- **Item keys, not provider ids.** A playlist channel's `Channel.id` holds its stream link (`m3u#<url>#<n>` or `<tvg-id>#<url>`), and Xtream ids hold the server's host (`xtream#<host>#…`). Sending them would break play-on-apple-tv/a-request-holds-no-link-and-no-login. A request names a channel, film, series or episode by the first 16 bytes of the SHA-256 of its id, as 32 hex characters (`PlayItemKeys` in the app, CryptoKit). The TV hashes the ids of what it has loaded for that source and compares. `PlayRequestMatch` in AntennaCore takes the hash as a function, so Core stays Foundation-only.
- **A programme carries its end.** `.programme(channelKey:start:end:)`: the expiry rule needs to know whether the programme had ended when it was sent, and the TV needs the end to ask for catch-up.
- **Frames without `NWProtocolFramer`.** The link reads the TLS stream with `PlayFrames.Reader` from AntennaCore, which splits the same four-byte-length frames. The bytes on the wire are as decided above; the parser is tested in Core with frames split at every size.
- **The TV listens behind the paywall too.** The listener runs whenever the TV's scene is active and iCloud is signed in, so a request that arrives behind the paywall or "Who's watching?" is kept and answered `waiting`, as the spec's paywall scenario asks. The phone then says "Sent. Living Room plays it once Antuna is ready there." In slice 1 a kept request plays once the shell shows; slice 2 turns it into the offer.
- **Ended programmes on the TV.** Catch-up of an ended programme starts through `TimeshiftModel.watchCatchup`, the start-over path with the requested programme in place of the one on now.
- **Signing the TV in from the phone.** On `noLogin` the TV opens the sign-in it shows for the source today, and the phone's alert says why. The "way to sign it in from the iPhone" is that sign-in form, which the iPhone's Apple TV keyboard can fill. A flow that sends the login from the phone would put a secret on the link, so it is left for a later change.
- **Until the iCloud queue lands.** In the first slice a TV that does not answer within 3 seconds gives "Living Room didn't answer. Open Antuna there and try again." Slice 2 replaces this with the iCloud fallback; the line stays for an iCloud save that fails for another reason than being offline.
- **A kept request becomes the offer.** From slice 2 a request kept behind the paywall or "Who's watching?" shows as the offer once the shell is up, as the spec's paywall scenario says, rather than playing by itself.
- **The silent push on tvOS.** The TV app gains a `UIApplicationDelegateAdaptor` that registers for remote notifications and passes the `play-requests` zone push on; the shell's 30-second pickup covers a push that never comes.
- **The stream gate lives in `RoutedEngine`.** There is no single `AppEngine` object: Live, the title player and every multi-view tile own a `RoutedEngine` made by `RoutedEngine.app()`. Each gets the shared `StreamGate.app` (AntennaCore), and `load` throws `CancellationError` while the gate is shut, so no screen opens a stream while connected. The counting test runs a `RoutedEngine` through the gate.
- **Where plays turn to the TV.** `LiveModel.pick` and `ShelfPlayback`'s one start function hand the item to `PlayDestination.playOnTV` while connected. Every channel play (Live, the Guide's Watch, Search, a reminder) goes through `pick`, and every film or episode through that start. Live goes on to mark the row as it would, and the gate keeps its load from opening anything.
- **When the phone counts as connected.** After an answer of `started` or `needsPasscode` on the link; any other answer closes it. A start while connected shows no line, since the bar says it.
- **Going to the background.** The connection ends without telling the TV, which keeps playing. The phone remembers the TV and the request, keeps the gate shut, and on returning connects again when the TV's first status still names that request. A TV sends its status to every phone that completes the handshake, so a reconnect needs no request.
- **Frames between the handshake and the connection.** A link the sender hands over holds the frames that arrive before the connection listens, so the TV's first status is not lost.
- **Deleting a picked-up request.** The TV deletes the request it picked up only while that request is still the one waiting, so a newer request sent in between stays.

## Device checks left for the owner

Task 1.3 needs a real Apple TV and Apple's answer, neither of which a simulator gives:

- What `UIDevice.current.name` returns on tvOS 26 without an entitlement. The app lists TVs that share a name as "Apple TV", "Apple TV 2" by record creation date either way.
- Whether tvOS 26 shows a local network prompt for the listener.
- The user-assigned device name entitlement for the iOS target, which only the owner can request from Apple. Without it the TV's banner reads "From iPhone".

## Open Questions

- Whether tvOS 26 returns the user's TV name from `UIDevice.current.name` without an entitlement. Group 1 checks it on a device; the spec's numbering covers the generic case either way.
