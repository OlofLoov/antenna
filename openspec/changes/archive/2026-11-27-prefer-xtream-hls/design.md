# Design

## Context

See proposal.md for why. What exists on 2026-11-27:

- `XtreamClient.liveLoad()` asks for the live categories, the live streams
  and the account (`player_api.php` with no action) at once, and links each
  stream as `.ts`. `UserInfo` does not decode `allowed_output_formats`.
- `EngineRouter` sends `.m3u8` to Apple's player and `.ts` to the demuxer.
  Only the demuxer records the live rewind buffer
  (`timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off`).
  `RoutedEngine` already moves an address between the two engines when its
  bytes say so (`EngineHandoff`), with no failure shown.
- Live on iPhone, iPad and Mac tunes through `LiveModel.load`, which calls
  `SessionTracker.load` and then `StreamResolver.address(for:)`.
- `LivePicture` shows `AirPlayPicker` (an `AVRoutePickerView`) only while
  `PlayerModel.route` is `.system`, and adds "AirPlay not available for this
  stream" to the audio-and-subtitles footer while it is `.demuxer`.
- `AVPlayerEngine` sets `allowsExternalPlayback` and reports
  `isExternalPlaybackActive` through `airPlayActivity()`; `PlayerModel`
  shows "Playing on AirPlay" from it.

A first version of this change linked every Xtream live channel as HLS. The
owner turned it down on 2026-11-27 because it loses the live rewind buffer;
this design replaces it.

## Boards

No board changes. The AirPlay button is drawn in `iPhone-FullScreen`,
and `iPad-Player`, which the Mac follows; it now shows on every live channel there.
The notice uses the timeshift notice style of `iPhone-Player-Timeshift`
(`Timeshift.Notice`, `timeshift.notice`). The audio-and-subtitles menu on
Live (`iPhone-Player-Tracks`, `iPad-Player-Tracks`) loses its AirPlay line.
Not drawn: the AirPlay button's refused press, which looks like the system
button and shows the notice. Design-system requirements followed:
`design-system/liquid-glass-stays-on-the-navigation-layer` (the button
sits on the existing glass capsule).

## Decisions

### 1. MPEG-TS stays the default; HLS only on AirPlay

Options:

- (a) Link Xtream live as HLS whenever the account allows it, with MPEG-TS
  as a silent fallback. The first version of this change. AirPlay works
  everywhere, but the rewind buffer, DVB and teletext subtitles and extra
  audio tracks go for every Xtream channel. Rejected by the owner.
- (b) Keep MPEG-TS on the demuxer and switch to HLS on Apple's player only
  while the channel goes to AirPlay.
- (c) Keep MPEG-TS and send it to AirPlay from the demuxer. The demuxer
  draws into `AVSampleBufferVideoRenderer`, which has no AirPlay video
  route; only `AVPlayer` sends a picture to AirPlay. Not possible.

Chosen (b). The loss on HLS (decision 7) now applies only while a TV shows
the channel, where rewind matters less than the bigger screen.

### 2. The account answer says whether a source offers HLS

`liveLoad` keeps `.ts` links and returns `offersHLS`, from
`XtreamLiveFormat.offersHLS(allowedOutputFormats:)`: true when the list has
`m3u8` or is missing or empty, false for a list without it. `SourceLoader`
keeps it in `XtreamHLSOffers.shared` by source id, in memory, like the
stream headers in `StreamHeaderBook`. A source not loaded yet in this
launch reads as not offering HLS, so AirPlay says not available until its
list arrives.

No list counts as offering HLS. The field is how a panel restricts an
account, so a missing field more likely means an older panel than a
refusal, and a wrong guess costs one failed HLS start, after which the
source is remembered (decision 5).

### 3. How AirPlay is triggered

The demuxer has no `AVPlayer` for `AVRoutePickerView` to route. Options:

- (a) Hide the system button on the demuxer route, as main does. No AirPlay.
- (b) Switch the channel to HLS on Apple's player when the button is
  pressed, so the list routes a real player. MPEG-TS stops and the rewind
  buffer is lost every time the list opens, even when the user cancels.
- (c) Follow the sound route. On iPhone and iPad `AVRoutePickerView` routes
  the app's audio session, so picking a device shows as an AirPlay output
  in `AVAudioSession.currentRoute` with a `routeChangeNotification`. While
  the demuxer plays, its sound goes to the device; the channel then loads
  its HLS link on Apple's player, which sends the picture because
  `allowsExternalPlayback` is on. Nothing changes while the list is open,
  and a device picked from Control Center works the same way.
- (d) Prepare the HLS link on Apple's player when the list opens, paused,
  silent and not drawn, and point the list at that player. When a device is
  picked, the player's `isExternalPlaybackActive` turns on and the channel
  moves to that player. On a Mac `AVRoutePickerView` routes one player
  (its `player` property) and there is no audio session, so this is the
  only way there.
- (e) `AVRouteDetector`. It says only whether routes exist, not which is
  picked.

Chosen (c) on iPhone and iPad and (d) on a Mac. Both keep MPEG-TS playing
until a device is picked. (d) is not used on iPhone and iPad because the
prepared item opens a second connection to the panel, which an account
limited to one connection answers by cutting the MPEG-TS stream; on a Mac
the risk remains and is listed under Risks.

The decision lives in `AirPlayHandoff` (AntennaCore), a value type that
takes the events (route, list opened or closed, external playback on or
off, a wait ended, HLS failed) and returns steps (play HLS, play MPEG-TS,
prepare or drop the HLS link, wait, say not available).
`PlayerModel+AirPlay` feeds it from `AirPlayRouteWatch` (iPhone and iPad),
the list's `AVRoutePickerViewDelegate` and `airPlayActivity()`, and carries
out the steps by reloading the channel with `StreamResolver.load(toAirPlay:)`.

A route to an AirPlay speaker looks the same as one to a TV in the audio
session. After the switch to HLS, `AirPlayHandoff.waitFor` (8 seconds)
passes; when no picture went to AirPlay by then, the channel goes back to
MPEG-TS, sound still on the speaker, and stays there until the route
changes.

When AirPlay ends (the route leaves AirPlay, or external playback stops
after it ran), the channel loads its MPEG-TS link again. That is a new
load, so the rewind buffer starts over.

### 4. The AirPlay button decides on press

The owner, 2026-11-27: the button shows on every live channel; whether
AirPlay is possible is decided when it is pressed, and the message shows
then, not up front. `PlayerModel.airPlayPossible` is true when the stream
plays on Apple's player or the channel has an HLS link its source may send
(`AirPlayHLS.hlsAddress`: an Xtream live channel, a source that offers HLS,
no failure in the last 7 days). `LivePicture` then shows the system
`AirPlayPicker`; otherwise `AirPlayRefusedButton`, which looks the same and
shows the notice on press. Swapping the two views by state gives the same
result as deciding inside the press: the system button cannot be told not
to open its list, and opening it from our own button needs its private
subviews. At compact width the button stays out of the strip, as before;
it is in full screen.

The notice is `TimeshiftModel.say`, the short notice over the picture that
rewind already uses, shown for 4 seconds.

### 5. When HLS does not start

`PlaybackOptions.fallback` carries the channel's MPEG-TS link, and
`RoutedEngine` opens it when Apple's player fails before the stream first
plays: a `load` that throws (refused, not found, a web page, timed out) or
a failure reported after `load` returned and before `.playing` (no first
frame within `firstFrameTimeout`). The failure is kept back from the
screen, so no error flashes, and `RoutedEngine.fallbacks()` names the
fallback. `PlayerModel` hears it, records the source in `HLSFailureStore`,
and shows the notice. Offline, a missing login and no free decoder are not
moved; the player's own recovery handles them. When the MPEG-TS link fails
too, its failure is the one shown.

`HLSFailureMemory` keeps source id and date for 7 days, as JSON under
`player.hlsFailures` in `UserDefaults.standard`, per device and never
synced. A failure depends on the network and device as much as the panel.
Recording prunes entries older than 7 days, so deleted sources fall out on
their own. UI test launches get the store in an emptied suite.

### 6. No per-source format setting

A "Stream format: Automatic / HLS / MPEG-TS" row was considered. No board
draws one, the source detail screens (`iPhone-Settings-Detail`,
`TV-Settings-Details`) have no playback rows, and with MPEG-TS as the
default and HLS only for AirPlay, there is nothing left for the row to
choose.

### 7. What the channel loses while on AirPlay

Apple's player plays what the panel puts in its HLS:

- No rewind buffer while on AirPlay; pause freezes and play returns to live
  (`timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded`).
  Back on the device the buffer starts over. Start over through the
  provider's catch-up still works.
- Extra audio tracks in the MPEG-TS may not be offered, and DVB and
  teletext subtitles are not shown.
- Apple's player starts at least three target durations from the live edge
  (RFC 8216, section 6.3.3), about 30 seconds behind with 10-second
  segments.
- Start time on the in-test server (`XtreamZapBenchmarkTests`, iPhone 17
  Pro simulator, 10 starts each): HLS median 0.11 s, MPEG-TS at its own bit
  rate median 0.70 s. The local server sends segments at once, so a real
  panel's HLS start is slower.

### 8. Apple TV

tvOS sends no picture to AirPlay, so `AirPlayRouteWatch` yields nothing
there and the Apple TV shell never asks for HLS. Its channels play as on
main.

## Identifiers

- `XtreamAccountInfo.UserInfo.allowedOutputFormats: [String]?`
- `XtreamLiveFormat.offersHLS(allowedOutputFormats:)`,
  `XtreamLiveFormat.hlsAddress(for:)`, `XtreamHLSOffers`
- `XtreamClient.liveLoad() -> (channels:timeZoneName:offersHLS:)`
- `PlaybackOptions.fallback: StreamFallback?`, `StreamFallback(url:source:)`
- `RoutedEngine.fallbacks()`, `RoutedEngine.loadedExtension`
- `AirPlayHLS`, `LiveAddress`, `HLSFailureMemory`, `AirPlayHandoff`
- `HLSFailureStore`, key `player.hlsFailures`
- `StreamResolver.load(_:on:options:toAirPlay:failures:offers:clients:)`
- `PlayerModel.airPlayPossible`, `tunesForAirPlay`, `airPlayRefused()`,
  `airPlayListOpened(preparesPlayer:)`, `airPlayListClosed()`
- `AirPlayPicker(opened:closed:attach:)`, `AirPlayRefusedButton`,
  `AirPlayRouteWatch`, `AVPlayerEngine.prepareForAirPlay(_:)`
- `FixtureServer.alias(_:to:)`
- Debug: `UITESTING_XTREAM_HLS=1` (or `ts-only`) makes Cabin Film
  `xtream#fixture#5` at `5.ts` with or without an HLS offer, a scripted
  engine per route, the probe's `browse.debug.airPlayRoute` switch and
  `browse.debug.airPlayList` count.

## Risks

- Neither trigger was tried with a real AirPlay receiver. The UI tests
  script the route and the external playback; the iPhone path rests on
  `AVRoutePickerView` routing the audio session, which is how it is
  documented, and the Mac path on `AVRoutePickerView.player`.
- On a Mac the prepared HLS link opens a second connection while MPEG-TS
  plays. An account limited to one connection may cut the MPEG-TS stream
  while the list is open.
- A panel that serves HLS and drops it after a minute is not caught: the
  channel played, so Apple's player reconnects on HLS.
