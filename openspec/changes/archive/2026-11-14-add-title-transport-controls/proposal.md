# Proposal

## Why

> I don't quite understand how one, in a loaded movie, actually scrolls in the film? Seems quite impossible as of now.

The owner, watching a movie on Apple TV and iPhone. A movie or episode plays with no time, no progress bar, no skip and no way to move. The engines can already seek; the screen never asks them to.

Afterwards a movie and series watcher can see how far into a title they are and how long is left, jump back 10 seconds to catch a line, skip forward 10, and drag or slide to any point, the way Apple's player and the big streaming apps work: the Siri Remote on Apple TV, touch on iPhone and iPad, and the pointer and keyboard on a Mac. Wherever they stop, Continue watching picks up from there.

## What Changes

- A transport for movies and episodes on every platform: elapsed and remaining time, a progress bar, back and forward 10 seconds, and moving to any point.
- Apple TV: the bar shows on play/pause, a click or a swipe and hides after a few seconds while playing. Clicking left or right skips 10 seconds. While paused, sliding on the touch surface moves a target time shown over the bar; select plays from there, Menu puts it back. Select alone plays and pauses. Holding select still opens the audio and subtitles panel, and Menu still closes the title.
- iPhone and iPad: a tap shows play/pause, back and forward 10, a scrubber with times, Close and the track buttons, which hide after a few seconds while playing. A double tap on the left or right half skips 10 seconds.
- Mac: the same as iPad, plus left and right arrow keys skip and Space plays and pauses.
- Skipping or scrubbing saves the new position at once, so closing right after a skip resumes from where the user moved to.
- Moving back in a title that already ended plays from the new point instead of the start.
- A movie or episode that fails to open, or stops with an error, shows the player's error with Try again and Back instead of a black screen.

Out of scope:
- Holding left or right on Apple TV to scan at speed, chapters, thumbnails over the scrubber and playback speed.
- The Siri Remote hint overlay. Another change adds it; this one leaves room for it (see design.md).
- Live TV, which keeps its own timeshift controls.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `player-controls-and-playback-errors`: adds "Move around in a movie or episode", "The movie controls show and hide" and "A movie or episode that cannot play says why".
- `movies-and-series-browsing`: "Your place is saved as you watch" also saves when the user skips or scrubs.

## Impact

- Platforms: iOS (iPhone and iPad), macOS, tvOS.
- Depends on `playback-engine/films-start-where-you-left-off-skip-and-end` (both engines seek in a film) and `player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode` (the track buttons and panel this keeps).
- AntennaCore gains the time text, skip and scrub math and a save on seek in `PositionSaving`.
- Blocked on nothing.
