# Design

## Context

See proposal.md for why. What exists on 2026-11-23:

- The Live player error on iPhone, iPad and Mac is `PlayerStatus.Failure`
  inside `LivePicture`, with one button, "Try again" (`player.retry`). In
  full screen it also has the exit button.
- On Apple TV it is `PlayerTVFailure` on Live's page, with "Try again"
  focused and "Sign in" beside it for a missing or refused login. Swiping
  up or down changes channel. Menu with nothing open over the picture goes
  to the tab bar (tvos-shell/menu-shows-the-tab-bar-over-the-picture).
- The channel list each platform already has: the Apple TV channel overlay
  (groups, channels, panel), the iPhone Groups sheet behind the group
  button, and the iPad and Mac sidebar, which folds behind "Show sidebar"
  below 904 pt.

## Boards

- `TV-Player-Error`: "Channels" beside "Try again", unfocused.
- `iPhone-Player-Error`: "Channels" after "Try again" in the same row.
- `iPad-Player-Error`: the board's 1194 pt window shows the sidebar and the
  list, so it keeps "Try again" alone, with a note on the narrower and
  full-screen cases, where "Channels" follows it as on iPhone. The folded
  window with the error is not drawn.
- What the button opens is drawn already: `TV-Groups` and the overlay
  boards on Apple TV, `iPhone-Live-Groups`, and `iPad-Collapsed`.

Design-system requirements followed:
`design-system/empty-and-error-states-share-one-layout` (at most two
buttons, the first moves the user forward),
`design-system/live-video-keeps-playing-under-overlays`.

## Decisions

### 1. What "Channels" opens

Options:
- **A new list built for the error.** More code, and a second place to
  keep in step with the overlay and the Groups sheet. Ruled out.
- **The Guide.** On Apple TV it has a group list, but it moves the viewer
  off Live and its picture shows the error small. Ruled out.
- **The list Live already uses, on the current group.** Chosen.
  - Apple TV: the channel overlay, opened the way select on the picture
    opens it (`ChannelOverlayModel.open`: the last group tuned from, else
    the channel's own group), but with the highlight on that group in the
    group column instead of on the channel, so up and down move between
    groups at once.
  - iPhone and narrow iPad: the Groups sheet, with the open group checked.
    Picking a group closes it and the list under the picture shows the
    group.
  - iPad and Mac: the sidebar. Below 904 pt it opens over the others, as
    "Show sidebar" opens it; picking a group then shows its list over the
    picture below 672 pt, as it does today.

### 2. Full screen on iPhone, iPad and Mac

The list is hidden in full screen, so "Channels" leaves full screen first,
then opens the sheet or the sidebar. On iPhone the sheet opens on the next
turn of the main loop, once the group button is back on screen. An iPhone
held sideways stays out of full screen until it is turned upright and
sideways again, as with the exit button.

### 3. When the button shows

- Apple TV: when "Sign in" does not show. A login error keeps "Try again"
  and "Sign in", the two buttons the shared layout allows. Options
  considered: three buttons (breaks the design-system rule), or "Channels"
  in place of "Try again" (the requirement keeps "Try again" first).
- iPad and Mac with the sidebar and the list both on screen, out of full
  screen: no button. The groups are already one click away beside the
  error, and a button that only highlights them would do nothing visible.
- Everywhere else on Live: always.

The screens offer the action through an `@Entry`,
`openChannelGroups: OpenChannelGroupsAction?`, which `LiveCompactView` and
`LiveRegularView` set and `LivePicture` reads. Nil means no button.
`LiveRegularView` remembers its last columns in `layout`, since full
screen hides them. `LiveListColumn` moves to its own file to keep
`LiveRegularView.swift` under the 500-line limit.

### 4. Back and Menu

Unchanged, as the existing spec says:
- Apple TV: Menu on the error, with nothing open over it, shows the tab
  bar. With the overlay opened from "Channels", Menu closes it and the
  focus goes back to "Try again" (`ShellModel.liveFocus`).
- iPad and Mac: Escape leaves full screen, as before.
- iPhone has no Back on Live.

### 5. Focus on Apple TV

- `ShellFocus.channels` is the new button. Swiping up or down on it
  changes channel, as on "Try again". Left and right move between the two
  buttons.
- While the overlay is open, the error's buttons are disabled, so the
  focus engine cannot leave the overlay for them.
- Picking a channel in the overlay plays it as a pick from the overlay
  always does, and the error goes once it plays.

### 6. Identifiers and text

- `player.channels` on every platform.
- The label is `PlayerStatusText.channels(locale)` in AntennaCore, the
  catalog key "Channels", already translated in every language.

### 7. Test hook

`UITESTING_PLAYBACK=fail-<reason>` fails the first load of every stream,
so the channel picked from the list would fail too.
`UITESTING_FAIL_ONLY=<file>[,<file>]` limits the failures to the files
named, so a test can fail one channel and play another.

## Risks

- The sheet on iPhone opens a beat after full screen ends. The UI test
  covers the upright case; the owner checks the sideways case on a device.
