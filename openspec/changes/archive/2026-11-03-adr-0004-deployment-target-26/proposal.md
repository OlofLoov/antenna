# Proposal: deployment target 26.0 on every platform (adr-0004)

## Why

tvOS 27 dropped the Apple TV HD, so the only Apple TVs that can run current
software are 4K models, and they all run tvOS 26. Supporting older iOS or
macOS would cost availability checks across SwiftData, SwiftUI and the
renderer APIs, with almost no users to gain.

Accepted on 2026-11-03.

## What Changes

- iOS, macOS and tvOS deployment targets are 26.0.
- No `#available` checks below 26.0.
- AntennaCore keeps a lower floor (iOS 17, macOS 14) only because it has no
  platform-specific code and the lower floor keeps `swift test` simple.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- The latest SwiftData, SwiftUI and AVFoundation APIs are available without
  branches.
- Anyone holding back an OS update cannot install Antenna.
