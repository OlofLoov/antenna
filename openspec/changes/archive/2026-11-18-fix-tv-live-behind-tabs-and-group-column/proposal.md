# Proposal

## Why

> As a living-room viewer on Apple TV, when I leave Live to browse Movies or Series I don't want the channel still playing behind them, and when I move between a group's channels and the group list I want the group list to stay where it was.

Two bugs from testing on an Apple TV, 2026-11-18:

- Live TV kept playing under Movies, Series and Search. The shell hid the picture but only paused it after 30 seconds, so the sound went on for half a minute every time, and the paused stream still held the provider's connection, which many providers limit to one.
- In the channel overlay, scrolling down a group's channels and moving left made the group column scroll and settle again before the user could move through the groups.

## What Changes

- Opening Movies, Series or Search from Live or Guide pauses the channel at once. After 30 seconds there the shell stops the stream. Going back to Live or Guide resumes a paused channel from where it was, or tunes a stopped one again at live.
- A channel that finishes loading after the user has left for Movies, Series or Search stays paused.
- The group column in the channel overlay scrolls only when the user moves through the groups, or to show the shown group when the overlay opens. Moving left from the channels lands on the shown group without the column moving.

Out of scope:
- iPhone, iPad and Mac. There a channel goes on playing on another tab, which `live-tv-on-iphone-ipad-mac` describes, and the report on this bug was about Apple TV. Whether to pause there too is left as an open question in design.md.
- The Guide's small picture, which keeps playing as before.
- The tab bar's layout and Picture in Picture in the Guide (another change).

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `tvos-shell`: "The video pauses behind Movies, Series and Search" now pauses at once and stops after 30 seconds.
- `tv-channel-overlay`: a new requirement, "The group column keeps its place".

## Impact

- Apple TV only: `ShellModel`, `ChannelOverlayView` and the group column component.
- Builds on `fix-live-group-switching` (archived 2026-11-14), which added the overlay's focus targets and the large-catalogue UI tests.
