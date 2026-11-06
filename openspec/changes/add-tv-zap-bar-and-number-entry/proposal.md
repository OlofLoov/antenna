# Proposal

## Why

Flipping channels on a TV needs a glance of information without leaving the picture: which channel this is, what is on, how far in, what is next. Antenna's Apple TV player shows nothing. TiviMate shows an info bar on every channel change and lets remotes with number keys jump straight to a channel.

User stories served:
- "As a living-room viewer, I want to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable."
- "As a viewer, I want to see what is on now and next without leaving the picture, so I can decide whether to stay."

## What Changes

- An info bar (the "zap bar") on every channel change and on request, which hides by itself.
- The bar shows logo, number, name, group and position in it, the current programme with its times and progress, the next programme, time left, and picture and sound quality.
- Swiping up and down changes channel within the current group. The current group is the one the user last tuned from in the overlay, or the channel's own group after a fresh launch.
- Play/pause in full-screen live TV shows the bar instead of pausing. A later playback change may alter this.
- Typing a channel number on a hardware keyboard, with correcting and cancelling.

Out of scope:
- The channel overlay, the guide grid and the Apple TV home screen.
- Player controls, rewinding, catch-up and start over.
- Choosing audio and subtitle tracks.
- Messages for streams that fail.
- Channel numbers from TV remotes or game controllers.
- Changing group by swiping left or right. Groups change in the channel overlay.

## Capabilities

### New Capabilities
- `tv-zap-bar-and-number-entry`: the Apple TV info bar shown on channel changes, channel up and down within a group, and typing a channel number on a keyboard.

### Modified Capabilities
None.

## Impact

- tvOS player screen gains the bar and the number box; the remaining-time and quality formatting goes in the core package and is shared with the channel overlay.
- Depends on: `channel-catalogue`, `guide-data`, `tvos-shell`, change `add-tv-channel-overlay` (current group), change `add-playback-engine` (playing state and picture and sound details).
