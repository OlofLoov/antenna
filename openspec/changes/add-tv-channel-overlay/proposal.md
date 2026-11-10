# Proposal

## Why

On a TV, live viewing comes down to one question asked with one remote: what else is on right now? TiviMate answers it with a three-column list laid over the running picture. Antenna on Apple TV opens a plain list and a separate player, so the picture stops whenever the user goes looking for another channel.

User stories served:
- "As a living-room viewer, I want to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable."
- "As a viewer, I want to see what is on now and next without leaving the picture, so I can decide whether to stay."
- "As a viewer, I want my favorite channels together in one list, across all my subscriptions and devices."

## What Changes

- Pressing select during live playback on Apple TV opens a list over the playing video, with groups, channels and a now-and-next panel.
- The group column lists the channel groups with how many channels each has, plus a way into Search.
- The channel column shows the chosen group's channels in channel-list order.
- The panel shows what is on now and next for the highlighted channel, from the guide.
- The user can tune, close without tuning, and the overlay remembers which group they last tuned from.
- The user can add and remove a favorite from the panel.
- A clock.

Out of scope:
- The info bar and typing a channel number (change `add-tv-zap-bar-and-number-entry`).
- The guide grid and the Apple TV home screen.
- How search works. The overlay only opens it.
- Start over and catch-up. The Start over button stays hidden until change `add-timeshift-catch-up-and-start-over` is accepted.
- Player controls, error messages and choice of player.
- Managing groups.
- iPhone, iPad and Mac browsing.

## Capabilities

### New Capabilities
- `tv-channel-overlay`: the three-column channel list over live video on Apple TV, with now and next, tuning and favorites.

### Modified Capabilities
- `tvos-shell`: the list over the picture becomes the channel overlay and opens on the playing channel instead of the first row.
- `favorites`: Apple TV lists favorites and changes them from the overlay; the read-only rule stays for iPhone, iPad and Mac.

## Impact

- tvOS player screen gains the overlay.
- Depends on: `channel-catalogue`, `guide-data`, `favorites`, `tvos-shell`, change `add-tv-zap-bar-and-number-entry` (info bar and remaining-time text), change `add-search` (the Search tab).
