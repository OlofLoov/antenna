# Design: deployment target 26.0 on every platform

## Context

tvOS 27 no longer supports the Apple TV HD. Every Apple TV that runs current
software is a 4K model on tvOS 26. Older iOS and macOS releases would need
availability checks across SwiftData, SwiftUI and the renderer APIs.

## Goals / Non-Goals

**Goals:**

- One API level on every platform, with no availability branches.

**Non-Goals:**

- Supporting devices or users on releases before 26.0.

## Decisions

**26.0 everywhere the app ships.** The iOS, macOS and tvOS deployment targets
are 26.0, and the code has no `#available` checks below it. AntennaCore keeps
a lower floor (iOS 17, macOS 14) because it has no platform-specific code and
the lower floor keeps `swift test` simple.

The decision recorded no alternatives. Supporting older releases would add
availability checks in every layer for almost no users.

## Risks / Trade-offs

- The latest SwiftData, SwiftUI and AVFoundation APIs are used without
  branches.
- Anyone holding back an OS update is excluded.
