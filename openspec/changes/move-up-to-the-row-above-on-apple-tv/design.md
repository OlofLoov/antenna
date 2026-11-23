# Design

## Context

See proposal.md for why. What exists on 2026-11-23:

- On Apple TV, Movies and Series show a 520 pt preview at the top while the
  highlight is in a row. A mask hides rows that pass under it.
- The rows' scroll view has a 120 pt top inset for the system tab bar. The
  focus engine scrolls a newly focused poster only until it is inside that
  inset, so it does not know about the preview.
- After each row change the screen waits 350 ms for the focus engine's own
  scroll to finish, then scrolls the row to its place under the preview with
  `ScrollViewProxy.scrollTo` and a computed anchor.

A trace of the scroll offset on the tvOS 27.2 simulator, Series with the
`watching` script, showed the cause:

- Moving down, the focus engine scrolls about 370 pt at once to reveal the
  next row, and the screen's scroll corrects the last 60 pt.
- Moving up, the row above is already inside the 120 pt inset, under the
  preview. The focus engine scrolls it 0 to 30 pt, so for 350 ms the focused
  row stays hidden under the preview, then slides about 450 pt down over
  300 ms. That pause and the late slide are the lag the owner saw.
- The anchor assumed the scroll view lines anchors up within the whole
  1080 pt screen. It lines them up within the screen less the 120 pt inset,
  so rows rested 26 to 45 pt lower than designed.

## Boards

No board changes. `TV-Movies-Rows` and `TV-Movies-Preview` already show the
focused row's header 16 pt under the preview; this change makes a move up
land there too. Design-system requirements followed:
`design-system/apple-tv-content-stays-in-the-safe-area`.

## Decisions

### 1. When to place a row after a move up

Options:
- **Give the scroll view a top inset as tall as the preview while it
  shows**, so the focus engine itself scrolls a row up from under it. Tried
  on the simulator: the focus engine then scrolled some moves only 30 pt and
  `scrollTo` did not correct them, leaving the row under the preview.
  Ruled out.
- **Shorten the 350 ms wait for every move.** A move down would then scroll
  while the focus engine's own scroll is still running, the conflict the
  wait exists for. Ruled out.
- **Place at once when the focused row's top is above the preview's foot.**
  Each row already reports its height as it lays out; it now reports its top
  on screen too. When the highlight lands in a row whose top is above
  520 pt, the focus engine has nothing left to scroll, so the screen scrolls
  the row down at once. Any other row waits 350 ms as before. Chosen.

`ShelfRowPlacement` holds the rule (`wait(top:)`) and the anchor
(`anchor(rowHeight:)`), so a unit test can pin the rule without a screen.

### 2. The anchor

`anchor = (rowTop - barHeight) / (screenHeight - barHeight - rowHeight)`,
with `rowTop` 536 pt (the preview's 520 pt foot plus 16 pt). The UI test
checks the result: every focused row rests wholly between the preview's foot
and the foot of the screen.

### 3. The tab bar's gesture recognizer log

The owner's console showed `[!] <_UITabBarTouchDetectionGestureRecognizer:
...; phase = possible> has been in possible phase for 71.9 seconds`. It is
not from the app:

- `_UITabBarTouchDetectionGestureRecognizer` is a private UIKit class that
  the system tab bar installs. The app creates, configures or references no
  gesture recognizer of that kind, and the only recognizers it adds to the
  window are three long-press recognizers for play/pause and the arrows,
  which recognize alongside every other recognizer and so never make another
  one wait.
- The line is the system gesture watchdog (`com.apple.Gestures`, Critical),
  which logs any recognizer that stays in the possible phase. On the
  simulator the same watchdog logged PineBoard's own
  `PBSystemKeychordGestureRecognizer` after 322 seconds with no app input.
- Neither the app, driven through Series by the UI test, nor a minimal
  SwiftUI `TabView` app left idle for two minutes logged the line on the
  simulator. A script cannot rest a finger on the Siri Remote's touch
  surface there, which is what keeps a touch recognizer in the possible
  phase, so the owner can confirm on the device with any `TabView` app.

Nothing changes for it.

## Risks

- The device's focus engine may scroll on its own timing. Placing at once
  only when the row is under the preview keeps moves down as they were, and
  the UI test checks the resting place after each move, including two quick
  presses up.
