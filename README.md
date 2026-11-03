# Antenna

A native IPTV player for iPhone, iPad, Mac and Apple TV. Working title.

Antenna plays sources **you** already have (M3U playlists, Xtream Codes logins,
Stalker portals, and later Jellyfin / Channels DVR / Tvheadend). It ships no
content and no provider links.

## Why another one

The Apple TV category is a dozen solo-developer apps with partial iCloud sync
and software-rendered video. Antenna is built around two things they lack:

1. **A hardware playback path for MPEG-TS.** FFmpeg demux → VideoToolbox decode →
   `AVSampleBufferVideoRenderer`, so HDR10 / Dolby Vision / Atmos stay on the
   system route and the Apple TV switches display mode correctly. HLS goes
   straight through `AVPlayer`.
2. **Whole-ecosystem sync for free.** Sources, favorites, ordering and settings
   live in SwiftData backed by the user's private CloudKit database. Credentials
   live in the Keychain and travel with iCloud Keychain. No servers.

## Layout

```
project.yml                 XcodeGen spec → Antenna.xcodeproj (not committed)
Config/                     xcconfigs + entitlements (Local.xcconfig is git-ignored)
Packages/AntennaCore/       Pure Swift, no UI: models, M3U + XMLTV parsers,
                            Xtream client, PlaybackEngine protocol. Tested with swift-testing.
Apps/Shared/                SwiftUI shared by every platform
Apps/Mobile/                iPhone / iPad / Mac target extras
Apps/TV/                    tvOS target extras
```

Targets:

| Target      | Destinations        | Bundle id                   |
|-------------|---------------------|-----------------------------|
| `Antenna`   | iPhone, iPad, Mac   | `se.codecrave.antenna`      |
| `AntennaTV` | Apple TV            | `se.codecrave.antenna.tv`   |

Deployment target is 26.0 everywhere (tvOS 27 dropped the Apple TV HD, so this
costs nothing in practice).

## Getting started

```sh
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # add your DEVELOPMENT_TEAM
xcodegen generate
open Antenna.xcodeproj
```

Core package tests run without Xcode:

```sh
cd Packages/AntennaCore && swift test
```

Before the first device build, create the iCloud container
`iCloud.se.codecrave.antenna` in your developer account (Xcode does it from
Signing & Capabilities).

## Roadmap

- [x] M3U / XMLTV parsing, Xtream client, CloudKit-synced sources and favorites
- [ ] Guide grid (XMLTV), catch-up playback
- [ ] Demuxer engine for MPEG-TS with HDR / frame-rate matching
- [ ] Stalker portal handshake
- [ ] tvOS profiles via `TVUserManager` + runs-as-current-user
- [ ] iPhone as setup device (QR / Handoff), Top Shelf, App Intents
- [ ] Multi-view, DVR via Channels DVR / Jellyfin back ends

## App Review notes

Guideline 5.2.3 is the risk in this category. Keep it defensible: no bundled
playlists, no provider marketplace, no cloud recording, and position the app as
a player for the user's own sources alongside Jellyfin, Plex, Channels and
HDHomeRun.
