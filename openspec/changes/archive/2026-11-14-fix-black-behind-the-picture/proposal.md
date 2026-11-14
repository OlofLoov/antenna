# Proposal

## Why

> When opening a movie or series that is not in full screen the background need to be black.

The owner, on a real Apple TV and iPhone. Two places showed a colored background where the owner expects black:

- A movie whose picture does not fill the screen (an iPhone held upright, a 4:3 episode, a 2.39:1 film) had dark blue-gray bars, the app's ground color, instead of black.
- A title page whose provider gives no backdrop showed the poster on a blue placeholder block. Until PR #367 wired the details call, that was every title page, since the backdrop comes from the details.

A movie and series watcher gets black bars like any other video player, and a poster-only page that reads as a framed poster on black.

## What Changes

- The player surface is black on iPhone, iPad, Mac and Apple TV, under both playback paths, for movies, episodes and live TV.
- On a title page with no backdrop, the poster sits on black instead of the blue placeholder.

Out of scope:
- The Movies and Series banner, which frames a poster-only title over a blurred copy of itself (`smooth-the-movies-banner`).
- Episode stills in the episode list, which keep the placeholder color.
- A title page with no backdrop does not get the banner's blurred poster; the owner asked for black.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `player-controls-and-playback-errors`: new requirement "Black around the picture".
- `title-detail-and-episode-picker`: "What the title is about" says the poster sits on black without a backdrop.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Depends on PR #367 for backdrops to show at all; this change covers the titles that still have none.
- Boards: the title pages and the title player transports.
