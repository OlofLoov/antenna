# Tasks

## 1. Dark labels on the accent

- [x] 1.1 `ProfileAccent.label` in AntennaCore and a `ProfileAccentTests` case that fails under 4.5:1 on any accent (design-system/text-on-the-accent-is-dark)
- [x] 1.2 `Palette.onAccent` and `prominentStyle(_:)`; `primaryActionStyle()`, `chipStyle`, the Up Next card and the reminder banner use it
- [x] 1.3 Save under a source's fields on Apple TV takes `primaryActionStyle()`
- [x] 1.4 `scripts/check-rules.sh` fails on a prominent style outside `PrimaryAction.swift`
- [x] 1.5 `ProminentLabelUITests` on iPhone checks Add a source and Connect draw a dark label
- [x] 1.6 The design-system reference names the label color and `prominentStyle(_:)`

## 2. Apple TV guide edges

- [x] 2.1 `GuideScale.television` at 365 pt per half hour; core tests follow
- [x] 2.2 `GuideGrid.Screen` pads with `Metrics.televisionSafeArea` at the sides
- [x] 2.3 `testTheGuideKeepsTheSafeEdges` on Apple TV (design-system/apple-tv-content-stays-in-the-safe-area)
- [x] 2.4 The five `TV-Guide` boards and the reference at 80 pt sides and 365 pt columns

## 3. Verify

- [x] 3.1 Each requirement this change adds or modifies has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes, then archive
