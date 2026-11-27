## Why

The owner, on 2026-11-27: AirPlay says "AirPlay not available for this
stream" on every Xtream live channel. Antuna asks Xtream panels for each
live channel as MPEG-TS (`/live/<user>/<password>/<id>.ts`). MPEG-TS plays
on Antuna's own player, which keeps the live rewind buffer but cannot send
video to AirPlay. Most panels also serve the same channel as HLS (`.m3u8`),
which Apple's player plays and can send to AirPlay.

The owner wants both: pause and rewind of live TV as today, and AirPlay
when asked for. Afterwards an on-the-go viewer with an Xtream subscription
watches a channel on iPhone, iPad or Mac with rewind as before, taps AirPlay,
picks the living-room TV, and the channel plays there. When AirPlay ends it
plays on the device again. When the panel cannot send HLS, the AirPlay
button says so when pressed.

## What Changes

- Xtream live channels keep their MPEG-TS links and play on Antuna's
  player, as on main, so pause and rewind of live TV work as before.
- The account's allowed output formats are read on every load. A source
  offers HLS when they list `m3u8` or say nothing; a list without `m3u8`
  rules it out.
- The live player's AirPlay button shows on every live channel, wherever
  the controls have room for it. What it does is decided on press:
  - a stream on Apple's player opens the system AirPlay list, as today;
  - an Xtream channel whose source offers HLS opens the list too, and
    MPEG-TS keeps playing on the device until a device is picked;
  - any other stream says "AirPlay not available for this stream" in a
    short notice over the picture.
- When an AirPlay device is picked, the channel switches to its `.m3u8`
  link on Apple's player, which sends it to AirPlay. When AirPlay ends, the
  channel plays as MPEG-TS on the device again, and its rewind buffer starts
  over from that moment.
- When the HLS link does not start, the channel plays on as MPEG-TS with no
  error, the notice says "AirPlay not available for this stream", and the
  device keeps that source as unable to AirPlay for 7 days, so the button
  says so on press during that time. Only the source id and a date are
  kept, in this device's settings.
- The audio-and-subtitles menu on Live drops its "AirPlay not available"
  line; its stream line names the format that plays.

Out of scope:

- A per-source "Stream format" setting. design.md, decision 6.
- Movies and episodes. They keep the file type the panel lists, and their
  menu keeps its AirPlay line.
- Catch-up, Start over and the panel's timeshift links, which stay MPEG-TS.
- AirPlay for M3U, Stalker, Jellyfin and Channels DVR channels on Antuna's
  player.
- Apple TV, which sends no picture to AirPlay. Its channels play as today.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `xtream-live-source`: new requirement "The account says whether HLS is
  offered".
- `playback-engine`: new requirements "A channel goes to AirPlay as HLS"
  and "A source whose HLS failed cannot AirPlay".
- `player-controls-and-playback-errors`: "Extra buttons on iPhone, iPad and
  Mac" shows the AirPlay button on every live channel and decides on press.

## Impact

- AntennaCore: `XtreamAccountInfo.UserInfo` decodes
  `allowed_output_formats`; `XtreamLiveFormat` and `XtreamHLSOffers`;
  `XtreamClient.liveLoad` returns `offersHLS`; `PlaybackOptions.fallback`
  and `StreamFallback`; `RoutedEngine` opens the fallback and names it in
  `fallbacks()`; `AirPlayHLS`, `HLSFailureMemory` and `AirPlayHandoff`.
  `FixtureServer.alias` serves a panel's live paths.
- Apps: `StreamResolver.load(toAirPlay:)`, `HLSFailureStore` under
  `player.hlsFailures`, `PlayerModel+AirPlay`, `AirPlayPicker` with the
  list's delegate and `AirPlayRefusedButton`, `AirPlayRouteWatch`, and
  `AVPlayerEngine.prepareForAirPlay` for the Mac. Debug:
  `UITESTING_XTREAM_HLS` in `UITestingLive`.
- Depends on `playback-engine`, `xtream-live-source` and
  `timeshift-catch-up-and-start-over` as they are in the specs. Blocked on
  nothing.
- No new container, external system or dependency, so the C4 diagrams stay
  as they are. No SwiftData or CloudKit change.
