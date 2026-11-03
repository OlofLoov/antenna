# 0004. Deployment target 26.0 on every platform

- Status: Accepted
- Date: 2026-11-03

## Context

tvOS 27 dropped the Apple TV HD, so the only Apple TVs that can run current
software are 4K models that all run tvOS 26. Supporting older iOS or macOS
costs availability checks across SwiftData, SwiftUI and the renderer APIs
with almost no users to gain.

## Decision

iOS, macOS and tvOS deployment targets are 26.0. No `#available` checks
below that. AntennaCore keeps a lower floor (17 / 14) only because it has no
platform-specific code and it keeps `swift test` simple.

## Consequences

- Good: Latest SwiftData, SwiftUI and AVFoundation APIs without branches.
- Bad: Excludes anyone holding back an OS update.
