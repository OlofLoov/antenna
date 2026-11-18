# Proposal

## Why

> As a living-room viewer on Apple TV, I want the remote legend every time I start watching after opening the app and every time I switch between Live, Movies and Series, so I learn what the remote does in each part of the app without hunting for it.

> As someone binging a series, I want the Next episode button a full minute before the end, so I can skip the credits sooner.

Today the legend shows when the highlight reaches a new screen, at most three times per screen per launch. After a few switches between Movies and Series it stops coming back, and the owner wants it there each time the viewer changes section. The Next episode button shows 30 seconds before the end, often after the credits have started.

## What Changes

- The legend always shows, past the three-per-launch limit, the first time a channel plays and the first time a movie or episode plays after a launch, and each time the viewer moves between Live, Movies and Series. It shows that section's own list. The guide counts as Live; the tab bar, title pages, the players and Settings belong to no section.
- Every other screen keeps the current schedule. The "Show remote hints" switch, the six-second fade, Reduce Motion and never taking focus are unchanged.
- The Next episode button shows from 60 seconds before the end instead of 30. The Up next card still replaces it 15 seconds before the end.

Out of scope:
- A separate "how to use" summary for the section switch. Each section shows its own list.
- Changing the card's countdown, the 5-minute minimum or "Still watching?".

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `control-hints`: "Hints fade and come back on a new screen" gains the first-playback and section-switch exceptions.
- `up-next`: "Next episode near the end", "Up next counts down", "Progress follows the next episode" and "Up next on the Siri Remote" move the button from 30 to 60 seconds before the end.

## Impact

- Platforms: the remote legend exists only on Apple TV. The up-next timing applies on iPhone, iPad, Mac and Apple TV, from the shared timer in AntennaCore.
- Depends on `control-hints` and `up-next` as archived.
