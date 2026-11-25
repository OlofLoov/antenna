# Design

## Context

See proposal.md for why. What exists on 2026-11-25:

- The Apple TV movie and episode player (`TitleRemoteLayer` in
  `ShelfPlayerView`) gives focus to a full-screen `HoldButton` over the
  picture. Select pauses, holding select opens `TitleTVPanel` on Audio.
  `TitleRemote` watches clicks left and right and slides on the window.
  Down moves focus to the Next episode button while it shows and does
  nothing otherwise. Up does nothing.
- `Transport.Bar` is drawn with `allowsHitTesting(false)` and holds nothing
  focusable.
- The remote hints for the playing title name "Hold, Audio and subtitles".
  They show for six seconds, at most three times per launch.
- Live (`ShellScreen.pictureHolder`) gives focus to the same kind of
  `HoldButton`. Select opens the channel overlay, holding select opens
  `PlayerTVPanel` on Info. Up and down change channel (or show the info
  bar, by the swipe preference), left plays the last channel, right opens
  Recents. The info bar (`ZapBarView`) never takes focus.

## Boards

Updated in this change, before any code:

- `TV-Title-Player-Transport`: the Audio and Subtitles button at the end of
  the title row, unfocused, and the remote notes for down.
- `TV-Title-Player-TracksButton` (new): the same bar with the button
  focused and the button's remote hints.
- `TV-Title-Player-Tracks`: which tab each way in opens on.
- `TV-Title-Player-NextButton`: down from the Next episode button reaches
  the bar's button.
- `TV-ZapBar` and its state boards (`-AllChannels`, `-Buffering`,
  `-EndsNow`, `-Favorites`, `-GuideLoading`, `-GuideUnavailable`,
  `-LiveOnly`, `-NoCatchup`, `-NoNext`, `-NoProgramme`, `-RTL`,
  `-Timeshift`) and `TV-Hints-Live`: the footer's second line.

Design-system requirements followed:
`design-system/liquid-glass-stays-on-the-navigation-layer` (the button is a
plain surface on the bar's scrim, no glass),
`design-system/apple-tv-content-stays-in-the-safe-area`,
`design-system/playback-glyphs-keep-their-meaning` (the bubble is not
mirrored in Arabic). Not drawn: the button grayed out, which follows the
iPhone and iPad boards' 0.4 rule.

## Decisions

### 1. Down focuses the button; select on it opens the panel

Options:

- (a) Down opens the panel at once. One gesture, but the bar's button
  could then never get focus: the picture's focus holder fills the screen,
  so the focus engine finds nothing below it, and down is the only free
  direction. The button would be a picture of a button.
- (b) Down shows the bar and moves focus to the button; select opens the
  panel. This is how Apple's player has worked since tvOS 15: the bar's
  subtitle and audio buttons take focus, and a click opens their menu.
  Two presses, and the second one is on a button that says what it does.
- (c) Up focuses the button. Up does nothing today, but the button sits at
  the bottom of the screen, so up to reach something below reads wrong.

Chosen: (b). The owner asked for a button; (b) is the one where the button
is the way in, and the hold stays for those who know it.

### 2. Next episode first, then the button

While the Next episode button shows (the last 30 seconds of an episode
with a next one), down keeps going to it first, as
`up-next/up-next-on-the-siri-remote` says. Down from it goes on to the
bar's button, and up from the bar's button comes back to it. Options were
to let down skip the Next episode button for the bar (breaks a shipped
requirement and its test) or to give each its own direction (none is free).
While the Up next card shows, the card keeps its rules and the bar's
button cannot be reached; the card is up for 15 seconds at most, and the
hold still works once it goes.

### 3. Which tab opens

The button opens the panel on Subtitles, since the bubble is the subtitle
symbol and subtitles are what people look for. The hold keeps opening on
Audio so nothing a viewer has learned changes. Options were Subtitles for
both (changes the hold), or Audio for both (the bubble would open on the
wrong tab).

### 4. Live gets a line, not a button

Every direction and select on the Live picture already does something
(decided in `tv-zap-bar-and-number-entry`, `tv-channel-overlay` and `session-restore-and-recently-watched`), so a
focusable button on the info bar would need a press taken from channel
changes. Options:

- (a) A focusable button on the info bar. No press can reach it without
  taking one from zapping.
- (b) Click down opens the panel while swipe down changes channel. The
  first-generation Siri Remote clicks anywhere on its touch surface, and a
  viewer who clicks down to zap would land in the panel.
- (c) A footer line on the info bar naming the hold. It shows after every
  channel change, which is when a viewer is looking at the bar.

Chosen: (c). The legend already names the hold on Live; the line keeps it
on screen whenever the bar is.

### 5. The bar stays while the button has focus

`TitleTransport.held` already keeps the controls up while VoiceOver runs.
It becomes VoiceOver or the button having focus. When focus leaves, `held`
turns false and the bar hides after the usual 5 seconds.

### 6. Focus moves only by the screen's rules

The UI tests on the simulator found two moves the focus engine made by
itself. It gave the bar's button focus with nobody pressing anything,
which held the bar up. And a swipe down from the Next episode button went
to the full-screen picture, which contains every point below the button,
instead of to the bar. So the bar's button can take
focus only after a down sent focus there (`reachable`), and the picture
cannot take focus while the Next episode button or the bar's button has
it. Focus goes back to the picture through one path that enables it first.
The button keeps its resting look while it cannot take focus, so it uses
its own button style (white and grown with focus) instead of the system
one, which would dim it.

That is an exception to `design-system/controls-use-system-styles`, and
`scripts/check-rules.sh` lists the button's file next to the other
app-drawn parts. Two ways to keep the system's bordered style failed on
the simulator. With `.focusable(reachable)` the button took focus, but
select on it opened no panel. Applying `.focusable(false)` only while out
of reach replaced the view each time `reachable` changed, and the button
never took focus.

### 7. Grayed out

With one sound and no subtitles (`TitleTracks.hasTrackChoices` false) the
button is disabled and at 0.4, as on iPhone, iPad and Mac. A disabled
button cannot take focus on tvOS, so down only shows the bar. The hold
still opens the panel, whose Subtitles tab says there are none.

## Identifiers and types

- `Transport.Bar` gets a `@ViewBuilder accessory` shown at the end of the
  title row; the Live info bar and previews pass none (`EmptyView`).
- `Transport.TracksButton` (tvOS, in `Components/Transport/`): values
  `subtitlesOn`, `isAvailable`, `reachable`, closure `open`. Captions bubble,
  `captions.bubble.fill` while subtitles are on. Label "Audio and
  Subtitles", value "Subtitles On" or "Subtitles Off", identifier
  `title.transport.tracks`.
- `TitlePanelFocus.tracks` for the button.
- `TitleRemoteMoves.down(nextEpisode:focus:hasChoices:)` and `.up(...)`:
  where down and up go from the picture, the Next episode button and the
  bar's button, as a pure function the tvOS unit tests call.
- `ControlHintScreen.titleTracksButton`: Click, "Audio and subtitles";
  Back, "Keep watching". `.titlePlayer(scrubbing: false, nextEpisode:
  false)` lists swipe down, "Audio and subtitles" in place of the hold.
  Its place for the schedule is the title player, and it belongs to no
  section.
- `ZapBarText.tracksHint(_:)` returns "Hold for info, audio and subtitles",
  a new string in the Core catalog. `ZapBar.Status` takes it as
  `tracksHint` and draws it as a second line, identifier
  `zapBar.tracksHint`.

## Tests

- AntennaCore: `ControlHintsTests` for the new and changed legends,
  `ZapBarTextTests` for the new line.
- tvOS unit tests: `TitleRemoteMovesTests` for where down and up go.
- tvOS UI tests (`ShelfTVUITests+Tracks`): swipe down focuses the button,
  select opens the panel on Subtitles, Back returns to the picture; down
  twice near the end of an episode reaches the button past Next episode.
  `ZapBarUITests` checks the info bar's new line.
- Screenshots: the `TVJourneys` title player step anchors on
  `title.transport`, which now includes the button. No new step.
