---
name: sim
description: Build and run Antenna on an iOS or tvOS simulator, run UI tests, or take a screenshot. Use when asked to run the app, see a change on screen, run XCUITests, or check that a build works on simulator.
---

# Running on simulator

Project is generated. Always start with:

```sh
xcodegen generate
```

## Pick a simulator

```sh
xcrun simctl list devices available | grep -E "iPhone|Apple TV"
```

Prefer the newest iPhone and "Apple TV 4K". Boot with
`xcrun simctl boot "<name>"` and open Simulator.app if a screenshot is wanted.

## Build and install

iOS:
```sh
xcodebuild build -project Antenna.xcodeproj -scheme Antenna \
  -destination 'platform=iOS Simulator,name=<name>' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build/dd 2>&1 | tail -20
xcrun simctl install booted .build/dd/Build/Products/Debug-iphonesimulator/Antenna.app
xcrun simctl launch booted se.codecrave.antenna
```

tvOS: scheme `AntennaTV`, destination `platform=tvOS Simulator`, product dir
`Debug-appletvsimulator`, bundle id `se.codecrave.antenna.tv`.

CloudKit does not sync on simulator. SwiftData still works locally.

## UI tests

```sh
xcodebuild test -project Antenna.xcodeproj -scheme Antenna \
  -destination 'platform=iOS Simulator,name=<name>' CODE_SIGNING_ALLOWED=NO \
  -only-testing:AntennaUITests 2>&1 | grep -E "Test Case|error|passed|failed"
```

If the UI test target does not exist yet, say so rather than inventing one.
Adding it is a change to `project.yml`, not the pbxproj.

## Screenshot

```sh
xcrun simctl io booted screenshot /private/tmp/antenna-shot.png
```

Then read the PNG and describe what is on screen.

## Reporting

Show the last lines of a failing build verbatim. Never report a build as
passing from a truncated log.
