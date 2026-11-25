# Proposal

## Why

> The owner, on device: sometimes when opening the app, while loading, a screen shows for a moment saying no playlist was found or similar. It goes away once loading finishes.

Two launches end in an empty state for a moment although the channels have loaded:

- iPhone, iPad and Mac. A source that finished loading counts as done at once, but its channels reach the list only after the catalogue is built away from the main actor, which takes a moment for a large playlist. In between Live reads "No channels match." and the Guide "No channels in All channels".
- Apple TV. When the profile last watched a movie or an episode, the launch waits up to 10 seconds for that title's page and plays nothing meanwhile. Once the channels have loaded, Live shows "No channels yet" with Open Settings and Try again until the page opens. The Guide, opened while the sources load, reads "No channels in All channels".

After this change a viewer who opens Antuna sees the loading rows until the channels are listed, and an empty state only when the sources have finished and none brought any channels.

Out of scope:
- Onboarding. It shows only when the store holds no source, and the store is read before the first frame.
- Movies and Series. Their sections already wait for the index that holds a source's titles before they count it as loaded.
- Search. It opens only on the user's tap.

## What Changes

- Live and the Guide on iPhone, iPad and Mac keep the loading rows while the channels that loaded are not in the list yet.
- Apple TV's Live shows the loading screen, not "No channels yet", while a source has channels and none plays yet.
- Apple TV's Guide reads "Loading channels" in place of an empty group while channels may still arrive.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: adds "No empty state before the channels are listed".
- `tvos-shell`: "An empty screen with Retry" shows only when no source has channels, and adds "No empty state before the channels are listed".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Code: the Live model's status and the Apple TV shell's Live screen and Guide. No stored data changes.
- Depends on `reopen-on-what-you-watched-last`, which added the wait for the title's page on Apple TV. Blocked on nothing.
