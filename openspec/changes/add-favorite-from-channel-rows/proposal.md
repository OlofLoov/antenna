# Proposal

## Why

> As a viewer on iPhone, iPad or Mac, I want to add a channel to Favorites from the channel list, the way I would in any other app, without first playing it and hunting for a small star.

On a real iPhone a user could not find how to favorite a channel. The only control is the star at the end of the now-playing line under the picture, which shows only for the channel that plays and is gone in full screen. Touching and holding a row, or swiping it, does nothing. The favorites spec still says no channel list can make a favorite, which stopped being true when Live gained the star.

## What Changes

- Touching and holding a channel in the Live list, or right-clicking it on a Mac, opens a menu with "Add to Favorites" or "Remove from Favorites". On a Mac the menu keeps its multi-view item.
- On iPhone and iPad, swiping a Live channel row to the right shows the same action, and a full swipe runs it.
- The channel column of the Guide, on iPhone, iPad and Mac, gets the same menu.
- The player controls show a star while the picture is full screen, so a channel can be added in landscape.
- VoiceOver offers the action on each row, named for what it will do.
- The stale requirement "Favorites list is read-only" is removed.

Out of scope:
- Reordering favorites.
- Apple TV. Its channel overlay already has a favorite button (`add-tv-channel-overlay`), and the boards draw no long-press menu there.
- Changing the empty Favorites wording, which `add-live-tv-on-iphone-ipad-mac` owns.
- The programme cards in the Guide, which keep their own actions.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `favorites`: adding and removing a favorite from a channel's menu, a swipe and the full-screen controls; the read-only requirement goes away.

## Impact

- Platforms: iOS, iPadOS, macOS. No change on tvOS.
- Depends on: `channel-catalogue` ("Adding a favorite", "Removal set"), the star in `add-live-tv-on-iphone-ipad-mac` ("Star a channel"), and the profile-scoped favorites of `add-profiles`.
- Touches `add-tv-channel-overlay`: its delta modifies "Favorites list is read-only", which this change removes, so that block is dropped from its delta. Its removal of "Apple TV shows no favorites" stays.
- No new stored data. Favorites are written through the same toggle the star, the Apple TV overlay and the Shortcuts action use.
