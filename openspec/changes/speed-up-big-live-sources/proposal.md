# Big live sources without the waits

## Why

A viewer with a large provider, 50 000 to 100 000 channels and a guide of
several hundred megabytes, wants the app "to come back to the channel I was
watching" and to "flip channels quickly with the remote". A review of Live
TV with sources that size found work in the way of both: the last channel
waits for a file write before it plays, a big guide fails as too large and
shows nothing, the iPhone and iPad Guide redraws every row every five
seconds, the Apple TV overlay walks the whole group every minute, logos
scrolled past keep downloading, and the main thread redoes catalogue-sized
work on each load and each zap. Afterwards the last channel starts as soon
as its source has loaded, a large guide loads with the programmes the
channels can use, and browsing a big group stays smooth on every platform.

## What Changes

- The last channel tunes as soon as the source's channels are tagged. The
  device's memory of seen channels is read and written after that, and the
  New group picks it up when it lands.
- A guide no longer fails for its size alone. While it is read, programmes
  outside a window around now are dropped, and once the kept programmes
  reach a cap, programmes for guide ids no channel uses stop being kept
  first. The byte limits rise to a safety limit for disk and time, lower on
  Apple TV.
- The iPhone and iPad Guide ticks its clock per row and per header, not
  around the whole screen.
- The Apple TV channel overlay ticks its minute per row.
- A logo download stops once no row waits for it.
- A refresh that brings the same channels changes nothing on screen, the
  restored channel is found by id instead of a scan, a zap's watched mark
  does not make the open group's list compare every row again, and the
  guide's name matching runs when the channels or the guide change, not on
  each download progress step.
- An HLS address opens on Apple's player without the extra probe request;
  the probe runs only to explain a failure.

Out of scope:
- Keeping channels and guides on disk across launches. It changes what is
  stored and how logins are stripped, and waits for an owner decision.
- Keychain reads on the main thread, which another change handles.
- XMLTV parsing quirks (encodings, missing stop times).

## Capabilities

### Modified Capabilities

- `guide-data`: Download limits and timeouts gets higher safety limits; a
  new requirement keeps a large guide's useful programmes.
- `session-restore-and-recently-watched`: a new requirement says the last
  channel does not wait for the seen-channel record.
- `live-tv-on-iphone-ipad-mac`: a new requirement for staying responsive
  with a very large source.
- `guide-on-iphone-ipad-and-mac`: a new requirement for the clock tick.
- `tv-channel-overlay`: a new requirement for the minute tick in a large group.
- `playback-engine`: Channel switching is fast gains an HLS scenario.

## Impact

- AntennaCore: `GuideLimits`, `GuideDecoder`, `SourceGuide.Builder`,
  `GuideFetcher`, `GuideEngine` name matching.
- Apps/Shared: `SeenChannelsStore`, `LiveModel`, `ShellModel`, `LogoCache`,
  the Guide screens, `OverlayChannelList`, `AVPlayerEngine+Stream`.
- No data model, sync or dependency change. Depends on nothing open.
