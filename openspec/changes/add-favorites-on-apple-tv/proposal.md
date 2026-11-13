# Proposal

## Why

> As a living-room viewer, I want the favorites I made on my iPhone on the Apple TV too, and I want to add one there the way I would on the phone, by holding the button on a channel.

The channel overlay on Apple TV already lists Favorites as its first group and has a star in its panel (`add-tv-channel-overlay`), but the favorites spec still says Apple TV shows no favorites, and the only way to add one on a TV is to move right to the panel and press the star. On iPhone, iPad and Mac a touch and hold on any channel row, in Live or in the Guide, offers "Add to Favorites" (`add-favorite-from-channel-rows`). Holding select is the tvOS way to open the same kind of menu, and the TV has no equivalent.

## What Changes

- Holding select on a channel row in the Apple TV channel overlay, including the overlay a multi-view tile opens, opens a menu with "Add to Favorites" or "Remove from Favorites". The star in the panel stays.
- Holding select on the Apple TV Guide grid opens the same menu for the highlighted programme's channel.
- VoiceOver on Apple TV offers the same action on overlay rows and on the Guide grid.
- The empty Favorites group in the overlay says to hold select on a channel.
- The favorites spec says what Apple TV shows: Favorites in the overlay, in the same order, for the current profile, without locked channels, and the Guide following it when the user tunes from Favorites. "Apple TV shows no favorites" is removed here instead of in `add-tv-channel-overlay`.
- "Favorites sync between devices" names Apple TV as a device that receives them.

Out of scope:
- A Favorites tab or a Live channel list on Apple TV. Live on Apple TV is the picture with the overlay, and the overlay already lists Favorites.
- A group picker in the Apple TV Guide. The Guide shows the group last tuned from, which can be Favorites.
- Reordering favorites, on any device.
- Changes on iPhone, iPad or Mac.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `favorites`: Apple TV shows favorites and changes them from a held select in the overlay and the Guide; sync names Apple TV; "Apple TV shows no favorites" is removed.

## Impact

- Platforms: tvOS only.
- Depends on: `add-tv-channel-overlay` (the overlay, its Favorites group and star), `add-tv-guide-grid` (the Guide grid and its current group), `add-favorite-from-channel-rows` (menu wording and the shared toggle), `add-profiles` (favorites per profile) and `add-group-management` (locked groups).
- Touches `add-tv-channel-overlay`: its favorites delta, which only removes "Apple TV shows no favorites", moves into this change, so the two changes can archive in either order.
- No new stored data. Every entry point calls the toggle the overlay star already uses.
