# 0005. Keep domain logic in a UI-free Swift package

- Status: Accepted
- Date: 2026-11-03

## Context

Parsers, protocol clients and playback routing are the parts most likely to
have bugs and least likely to need a simulator. Xcode-only tests are slow and
need a generated project.

## Decision

`Packages/AntennaCore` holds models, parsers, the Xtream client and the
`PlaybackEngine` protocol. It imports Foundation only and runs under
`swift test` with swift-testing. Apps depend on it; it never depends on Apps.
SwiftData models stay in Apps because they are an app persistence concern.

## Consequences

- Good: Core tests run in seconds in CI without XcodeGen.
- Bad: Some duplication between `SourceDescriptor` (core) and `SourceRecord`
  (app). Accepted as the cost of the boundary.
