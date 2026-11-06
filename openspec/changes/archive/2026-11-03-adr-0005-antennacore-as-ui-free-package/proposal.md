# Proposal: keep domain logic in a UI-free Swift package (adr-0005)

## Why

Parsers, protocol clients and playback routing are the parts most likely to
have bugs and least likely to need a simulator. Xcode-only tests are slow and
need a generated project.

Accepted on 2026-11-03.

## What Changes

- `Packages/AntennaCore` holds models, parsers, the Xtream client and the
  `PlaybackEngine` protocol.
- AntennaCore imports Foundation only and runs under `swift test` with
  swift-testing.
- Apps depend on AntennaCore. AntennaCore never depends on Apps.
- SwiftData models stay in Apps, because persistence is an app concern.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- Core tests run in seconds in CI without XcodeGen.
- Some duplication between `SourceDescriptor` in the core and `SourceRecord`
  in the app, accepted as the cost of the boundary.
