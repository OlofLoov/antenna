# Proposal

## Why

> As someone looking at Antenna's App Store page, I want the pictures to show a finished app: posters on Movies, guide times that match the clock, and nothing cut off or floating in empty space, on every device I might buy it for, Mac included.

The store set from `add-store-localization` shows layout bugs every user
hits, not only the screenshots:

- On iPad the Live details panel cuts the programme title short ("News
  Ho…"), wraps 12-hour times in Up next over two lines ("6:00 P" / "M"),
  and in Spanish cuts off the list title ("Todos los canal…").
- On iPhone, Live and Guide leave an empty band above and below the group
  chips. The chip row takes half the height left over instead of its own.
- On iPad the guide's rows start a third of the way down the grid when a
  group has few channels.

It also shows gaps that only the store set has: Movies with no art, guide
times that disagree with the 9:41 status bar, and no Mac pictures.

## What Changes

- The details panel puts the times under the programme title when both do
  not fit on one line, sizes Up next's time column to its widest time on
  one line, and moves the channel count under a long list title.
- The group chip row on iPhone is as tall as its chips, on Live, Guide and
  Search.
- The iPad and Mac guide grid starts its rows under the time labels
  whatever the group's size.
- In the Debug-only store-shot mode: made-up posters and backdrops for the
  scripted movies and series, drawn by a script; the app's wall clock
  reads 9:41 at launch; and on a Mac the window opens at 1440 by 900 points.
- The `App screenshots` workflow runs the store walk on a Mac in every
  store language and files the pictures in the same `store-screenshots`
  artifact.

Out of scope:

- Captions or device frames on the pictures.
- Uploading anything to App Store Connect.
- The Apple TV shell, which `adopt-tvos-tab-view` is changing now. The
  Apple TV pictures get the art and the clock through the shared code.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: the chips sit under the now-playing line;
  the details panel keeps titles and times whole; a long group name keeps
  its count readable.
- `guide-on-iphone-ipad-and-mac`: rows start under the time labels in a
  short group; the iPhone chips take one row.
- `store-listing`: the store set covers the Mac, shows art on Movies, and
  shows the same time as the status bar.

## Impact

- Changed: `Apps/Shared/Components/Browse/`, `Apps/Shared/Views/Guide/GuideScrollGrid.swift`,
  `Apps/Shared/Debug/` (store-shot mode, shelf fixtures), `Apps/Journeys/Snap.swift`,
  `Config/Shared.xcconfig`, `project.yml` (a Mac journeys target and an
  `AntennaMac` scheme), `.github/workflows/screenshots.yml`,
  `scripts/export-screenshots.sh`.
- New: `scripts/make-store-art.py`, the `StoreArt-*.jpg` files it draws,
  `Apps/MacJourneys/`.
- Depends on: `add-store-localization` (the store walk and artifact).
- Blocked on: nothing.
