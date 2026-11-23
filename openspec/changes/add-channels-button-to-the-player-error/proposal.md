## Why

When a live channel's stream fails, the error screen offers "Try again" and,
on Apple TV, a swipe up or down to the next channel in the same list. When
the provider has trouble with a whole group, as with a sports package that
is off the air, neither gets the living-room viewer or the on-the-go viewer
to another group. On Apple TV they have to press Menu, go to the Guide or
back to the picture, and find their way to the overlay. On iPhone in full
screen they have to leave full screen first and find the group button.

Afterwards the error has a "Channels" button next to "Try again". It opens
the channel list Live already uses, on the group the viewer was watching,
so they can move straight to another group and pick a channel there.

## What Changes

- The player error on Live gets a "Channels" button after "Try again", on
  iPhone, iPad, Mac and Apple TV.
- On Apple TV it opens the channel overlay with the highlight on the
  current group in the group column. "Try again" keeps the focus when the
  error appears. Menu closes the overlay and the focus goes back to "Try
  again". When "Sign in" shows, it takes the second place and "Channels"
  does not show, since the shared error layout has at most two buttons.
- On iPhone and in a narrow iPad window it leaves full screen if needed and
  opens the Groups sheet with the open group checked.
- On iPad and Mac it leaves full screen if needed and opens the folded
  sidebar on its groups. When the sidebar and the list are already on
  screen next to the error, the button does not show.
- Back and Menu on the error keep their current behavior.

Out of scope:
- The error in the Guide's small picture on Apple TV, which has no buttons.
- The error of a movie or episode, and multi-view tiles.
- A new channel list or picker. The button reuses the ones Live has.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `player-controls-and-playback-errors`: "A failed stream says what went
  wrong" names the new button, and a new requirement "Go to another group
  from the error" says what it opens on each platform.

## Impact

- Apps: `LivePicture`, `LiveCompactView`, `LiveRegularView`,
  `LiveGroupButton`, `GuideCompactScreen` on iPhone, iPad and Mac;
  `PlayerTVFailure`, `ShellScreen` and `ShellFocus` on Apple TV.
  `PlayerStatusText.channels` in AntennaCore. The scripted playback in
  `UITestingPlayback` learns to fail only the streams a test names.
- Boards: `TV-Player-Error`, `iPhone-Player-Error`, `iPad-Player-Error`.
- Builds on the player error, the channel overlay and the Groups sheet as
  they are. Blocked on nothing.
- "Channels" is already translated in every language in `Config/languages`.
- No new container or dependency, so the C4 diagrams stay as they are.
