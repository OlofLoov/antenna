# Proposal

## Why

> As a viewer with an M3U subscription, I want the guide my playlist names to show up, the way it does in other IPTV apps.

Many providers name the guide in the playlist header with `tvg-url="…"`. The app reads only `url-tvg` and `x-tvg-url`, so those playlists load with an empty guide. On a real iPhone a user added an M3U that shows a guide in other apps and got none in Antenna. After this change a `tvg-url` header gives the same guide as the other two spellings.

## What Changes

- The `#EXTM3U` line's `tvg-url` attribute is read as a guide link, after `url-tvg` and `x-tvg-url` on the same line.

Out of scope:
- A guide for an Xtream panel's `get.php` playlist link that names none in its header. A separate change covers Xtream-style M3U links.
- Guide links in `#EXTINF` lines.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: the header guide links include `tvg-url`.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS. AntennaCore only, no app code.
- Depends on: `m3u-playlists`, and `guide-data`, which loads the links the parser returns.
- Data: none. A source added before this change picks up the link on its next refresh.
