# Proposal

## Why

> As someone opening Favorites for the first time on my iPhone, I want the empty list to tell me how to add a channel the way the list works now.

Empty Favorites on iPhone, iPad and Mac says "Tap the star on a channel to add it." Channel rows have no star any more. A channel becomes a favorite from its touch-and-hold menu or a swipe on iPhone and iPad, and from its right-click menu on a Mac. Apple TV already says "Hold select on a channel to add it."

## What Changes

- iPhone and iPad: "No favorites yet. Touch and hold a channel, or swipe it right, to add it."
- Mac: "No favorites yet. Right-click a channel to add it."
- The iPhone board for empty Favorites shows the new text.

Out of scope:
- Apple TV, which keeps its text.
- Other empty states, such as "No channels match." for a filter.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: the Empty Favorites scenario of "Pick a group" gives the text per platform.

## Impact

- Platforms: iOS, iPadOS, macOS.
- Depends on: `favorites/favorite-from-a-channel-s-menu` and `favorites/swipe-a-channel-into-favorites`, the gestures the text names.
