# Proposal

## Why

> As an on-the-go viewer on iPhone, iPad or Mac, when I leave Live to browse Movies or Series I don't want the channel still playing behind them, unless I put it in Picture in Picture to keep watching.

Since `fix-tv-live-behind-tabs-and-group-column` (PR #385), Apple TV pauses a channel as soon as Movies, Series or Search opens and stops it after 30 seconds. iPhone, iPad and Mac still play it on: the sound runs under Movies, and the stream holds the provider's connection, which many providers limit to one. That change left the other platforms as an open question. The owner decided on 2026-11-19 that they should behave as Apple TV does, with one exception: a channel in Picture in Picture keeps playing.

## What Changes

- On iPhone, iPad and Mac, opening Movies, Series or Search pauses the channel at once. After 30 seconds there it stops, which frees the provider's connection. Going back to Live or the Guide plays a paused channel on from where it was, or tunes a stopped one again at live. This is the Apple TV rule.
- A channel playing in Picture in Picture, or on an AirPlay device, keeps playing behind those tabs.
- Multi-view on iPad and Mac ends when one of those tabs opens, keeping the selected tile's channel, which then pauses as above.
- Apple TV and the other platforms run the same pause and stop code. On Apple TV nothing changes for the user.

Out of scope:
- The Guide and Settings. The channel plays on behind them, as before and as on Apple TV.
- A Picture in Picture window closed while Movies is open pauses the channel, as it does today. The 30-second stop does not apply to it.
- Movies and episodes: playing one stops the channel, as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: a new requirement, "The channel pauses behind Movies, Series and Search".

## Impact

- `LiveModel` on iPhone, iPad and Mac; the Apple TV `ShellModel` moves its pause and stop into a shared helper both models use.
- Builds on `fix-tv-live-behind-tabs-and-group-column` (archived 2026-11-18) and the Picture in Picture requirements of `player-controls-and-playback-errors`.
- Blocked on nothing.
