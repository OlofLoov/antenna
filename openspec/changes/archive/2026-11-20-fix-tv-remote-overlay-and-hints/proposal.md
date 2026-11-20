# Proposal

## Why

> As a living-room viewer on Apple TV, I want the channel list to stay put, one press of the remote to do one thing, a single channel to play again after multi-view, and the remote help to show up in the same spot every time.

The owner found four bugs on a real Apple TV on 2026-11-19:

1. Picking a group in the channel overlay moved the group column and the channel list away from the left edge of the screen. Switching channels kept them at the edge.
2. After leaving multi-view, every channel picked from the list played with a black picture. Entering multi-view again showed the pictures.
3. Some presses did two things. Holding select on the full-screen picture opened the info panel, and the release of that press then opened the channel list too. Holding select on a multi-view tile opened its actions and then the picker, and on a playback error it tried again twice.
4. The remote hints card sat top right on some screens and bottom right on others.

## What Changes

- The overlay's groups and channels always start at the 80-point safe edge, whatever the panel on the right shows.
- Leaving multi-view hands the kept tile's picture to the full-screen view for good; the tile's view no longer pulls it back out while the grid closes. The same fix covers multi-view on iPad and Mac.
- A control that does one thing on a click of select and another on a hold ignores the click that ends the hold: the full-screen picture, a multi-view tile, Try again on an error and the movie player. A check in `scripts/check-rules.sh` keeps a long press off any other button.
- The remote hints card has one place on every screen: top right inside the safe area, under the clock row.

Out of scope:
- The tab bar, Settings and the clock, which `adopt-tvos-tab-view` moves to the system tab view.
- iPhone, iPad and Mac for bugs 1, 3 and 4: the overlay, the remote hints and click-and-hold controls exist only on Apple TV. Their double tap and single tap gestures already wait for each other.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `tv-channel-overlay`: a new requirement, "The columns keep the safe edge".
- `multi-view`: "Leave multi-view" gains a scenario for the channel picked after leaving.
- `tvos-shell`: a new requirement, "One press does one thing".
- `control-hints`: "Hints stay out of the way" puts the legend in one place on every screen.

## Impact

- `ChannelOverlay.Layout`, `PlayerSurfaceView`, a new `HoldButton` component with `HeldPress` in AntennaCore, `ControlHints.Placed`, and the shell, multi-view, error and movie player screens that use them.
- Builds on `add-tv-channel-overlay`, `add-multi-view` and `add-control-hints`, all archived.
- Blocked on nothing.
