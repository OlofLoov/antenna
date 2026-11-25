## Why

The owner, watching a movie on Apple TV on 2026-11-25: "Still no button
option on tvOS to change subtitles?" The audio and subtitles panel exists,
but the only way in is holding select, and nothing on screen says so. The
remote hints name the hold for six seconds and then fade. Live has the same
gap: its info panel also opens only on a hold.

Afterwards a living-room viewer watching a movie or episode swipes down,
sees an Audio and Subtitles button on the bar, highlighted, and clicks it
to land on Subtitles, the way Apple's own player works. On Live, the info
bar that shows after every channel change says "Hold for info, audio and
subtitles".

## What Changes

- The Apple TV movie and episode bar gets an Audio and Subtitles button
  with the captions bubble, at the end of the title row. It is grayed out
  when the title has one sound and no subtitles.
- A swipe or click down on the playing title shows the bar and moves focus
  to that button. Select on it opens the panel on Subtitles. Up or Back
  puts focus back on the picture. The bar stays while the button has focus.
- While the Next episode button shows, down reaches it first, as today; a
  second down reaches the Audio and Subtitles button.
- Holding select still opens the panel on Audio.
- The remote hints on the playing title name swipe down for audio and
  subtitles in place of the hold, and the button gets its own hints:
  Click, Audio and subtitles; Back, Keep watching.
- Live's info bar gets a second footer line with the captions bubble:
  "Hold for info, audio and subtitles". Swipes on Live keep changing
  channel; nothing else about Live's remote changes.

Out of scope:

- iPhone, iPad and Mac. Their players already show the audio-and-subtitles
  button with the controls.
- A focusable button on Live. Every direction on the Live picture already
  does something (channel up and down, last channel, Recents) and select
  opens the channel list, so there is no free press to reach one.
  design.md, decision 4.
- Changing which tab the hold opens on, in either player.
- An Info tab in the movie player; the title page has the details.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `player-controls-and-playback-errors`: new requirement "Audio and
  subtitles from the bar on Apple TV"; "Choose audio and subtitles in a
  movie or episode" names the bar's button in its Apple TV scenarios.
- `up-next`: "Up next on the Siri Remote" adds the scenario "Past the
  button to audio and subtitles".
- `control-hints`: "Each screen lists its own actions" adds the scenario
  "Audio and subtitles in the movie player".
- `tv-zap-bar-and-number-entry`: new requirement "The info bar names the
  hold"; "Catch-up hint" keeps its wording for the first footer line.

## Impact

- Boards: `TV-Title-Player-Transport`, the new `TV-Title-Player-TracksButton`,
  `TV-Title-Player-Tracks`, `TV-Title-Player-NextButton`, `TV-ZapBar` and
  its state boards, `TV-Hints-Live`.
- Apps: `Transport.Bar` takes an accessory, a new `Transport.TracksButton`,
  the Apple TV `TitleRemoteLayer` in `ShelfPlayerView`, `ZapBar.Status` and
  `ZapBarView`. AntennaCore: `ControlHintScreen` and `ZapBarText`, with one
  new string in the Core catalog in every language in `Config/languages`.
- Tests: AntennaCore unit tests, a tvOS unit test for where down goes, and
  tvOS UI tests in `AntennaTVUITests`.
- Depends on `up-next` (the Next episode button and its down) and
  `control-hints`, both in the specs. Blocked on nothing.
- No new container, dependency or stored data, so the C4 diagrams stay as
  they are.
