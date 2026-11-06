# Proposal

## Why

Live TV in Antenna cannot be paused, rewound or restarted. TiviMate holds about two minutes of pause and cannot skip inside it, and its users rank a real rewind buffer second on their wish list. Many providers offer catch-up (replaying recent programmes from their servers), and Antenna already reads which channels have it, but nothing plays it.

User stories served:
- "As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text."
- "As a sports fan, I want to pause and rewind live TV, and start a programme over or watch one I missed when my provider allows it."

Not reviewed yet.

## What Changes

- The playing live channel is recorded to a local buffer from the moment it is tuned, up to 60 minutes or a storage cap, whichever comes first.
- Pause, resume where paused, skip back 15 seconds and forward 30, scan by holding (Apple TV) or dragging (touch and mouse), and return to live.
- Playlists' catch-up details (`catchup`, `catchup-source`, `catchup-correction`) and Xtream's archive flag and server time zone are read.
- Catch-up addresses are built for the common playlist styles (`default`, `append`, `shift`, `flussonic`, `xc`) and for Xtream accounts.
- Start over for the programme on air now, by catch-up first and the local buffer second.
- Skipping within a catch-up programme, and returning to live when it ends.
- Defined behavior when the buffer fills, storage is short, catch-up fails, the app goes to the background, or the stream cannot be recorded.
- A rewind row in the Apple TV zap bar and a two-row control strip on iPhone, iPad and Mac.

Out of scope:
- Playing earlier programmes from the guide, the overlay's upcoming list or search, and the guide's own Start over.
- Keeping recordings.
- The `vod` catch-up style and XMLTV catch-up ids.
- Catch-up for Stalker, Jellyfin and Channels DVR.
- Player controls other than moving in time.
- Picture in Picture and background audio themselves.
- Skip lengths as a setting.
- Fast playback with sound (2x, 4x).

## Capabilities

### New Capabilities
- `timeshift-catch-up-and-start-over`: pausing, rewinding and scanning live TV from a local buffer, building catch-up addresses, and Start over for the programme on now.

### Modified Capabilities
- `m3u-playlists`: reads the catch-up style, source template and hour correction from each entry.
- `xtream-live-source`: marks archive channels as Xtream catch-up and reads the server's time zone.

## Impact

- Refines the player controls (its transport strip and keyboard seek keys go; its buffering and error screens show during catch-up loads), the channel overlay (Start over visible, focus order, Watch respects a user pause), the zap bar (play/pause reaches the engine, the live hint, the LIVE behind state, left and right skip), the guide grid and tvOS shell (no resume over a user pause), Live on iPhone, iPad and Mac (two-row strip, LIVE as a button while behind), the catalogue (favorite snapshots copy no catch-up fields), and the playback engine (timeshift, seek by date, buffer attach). The design system gains the buffered-fill token and the LIVE behind state.
- Depends on: `m3u-playlists`, `xtream-live-source`, `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, change `add-tv-channel-overlay`, change `add-tv-zap-bar-and-number-entry`, change `add-tv-guide-grid`, change `add-live-tv-on-iphone-ipad-mac`, change `add-playback-engine`, change `add-player-controls-and-playback-errors`.
- Blocked on: a decision in this change's design.md on where the timeshift buffer lives and how big it is. Assumed meanwhile: files in the app cache, 60 minutes, 4 GB on Apple TV and Mac, 2 GB on iPhone and iPad.
