# Proposal

## Why

> As a sports fan, I want to watch up to four channels at once on Apple TV or Mac, and choose which one I hear.

Sports and news viewers want two to four live channels on one screen, with the sound from the one they are watching. TiviMate users praise its multi-view and keep paying for it, and Channels DVR users push it to nine streams. Antenna plays one channel at a time everywhere.

Not reviewed yet.

## What Changes

- Apple TV: start multi-view from the channel overlay, with two, three or four tiles. The remote moves between tiles and the sound follows the highlighted one. A tile's channel changes through the overlay, and holding select opens the tile's actions (full screen, change channel, try again, remove). One tile can go full screen and back, and Menu leaves.
- Mac: start from a channel's right-click menu or Command-Shift-M. The same layouts fill the main window with the sidebar folded away. A click or Command-1 to 4 picks the audible tile, the channel list fills the chosen tile, and a double-click enlarges it. Each tile has a remove button, the toolbar has an exit button, and the window keeps a minimum width.
- A limit of four tiles, two on Apple TV HD and Intel Macs, lowered for the session when the device cannot decode another stream.
- Each tile shows its own loading and failure state, in plain words for a provider that refuses another connection and for a device that cannot decode another stream.
- While tiles play, the TV's display mode stays as it was and HLS tiles stay at 1080p or below.
- Tiles reconnect only through the playback engine. Multi-view adds no retry of its own.

Out of scope:
- iPhone (tiles too small to read, battery, heat, mobile data) and iPad for now.
- Other layouts, more than four tiles, resizing or dragging tiles.
- Restoring a multi-view set after relaunch.
- Pause, rewind, catch-up or Start over in a tile, and pausing a single tile.
- Per-tile audio and subtitle pickers, AirPlay and Picture in Picture while in multi-view.
- Starting multi-view from the guide or search.
- Measuring bandwidth or lowering quality beyond the 1080p cap.
- A separate purchase. Multi-view is part of the one unlock.

## Capabilities

### New Capabilities
- `multi-view`: up to four live channels side by side on Apple TV and Mac, with sound from the highlighted tile.

### Modified Capabilities
- `tvos-shell`: the shell hosts multi-view, and leaving it keeps the surviving tile's player.

## Impact

- Platforms: tvOS, macOS.
- Depends on: `tvos-shell`, `channel-catalogue`, and the changes `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-live-tv-on-iphone-ipad-mac`, `add-playback-engine`, `add-player-controls-and-playback-errors`.
- Needs from `add-playback-engine`: muted start and moving sound without a reload, a 1080p quality cap, leaving the TV's display mode alone, a "no decoder free" reason, and no retry of a 503 or 509 while another tile on the same account plays.
- Needs from other changes: `add-tv-channel-overlay` gets a third panel button and a pick mode. `add-tv-zap-bar-and-number-entry` turns off the zap bar, swipes and number entry in multi-view, and leaving fires one channel change. `add-live-tv-on-iphone-ipad-mac` gets the right-click item, Command-Shift-M, a list that targets the selected tile, an inert Space, Escape that only undoes enlarge, and a 1024 pt minimum width. `add-player-controls-and-playback-errors` covers the engine's failure reasons, long press for tile actions, and Now Playing that follows the selected Mac tile. `add-timeshift-catch-up-and-start-over` keeps no buffer in tiles. `add-session-restore-and-recently-watched` stores the surviving tile as the last channel.
