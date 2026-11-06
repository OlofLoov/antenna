# Design: AntennaCore as a UI-free package

## Context

The code most likely to have bugs is parsing, protocol clients and playback
routing, and none of it needs a simulator. Tests that only run in Xcode are
slow and need a generated project.

## Goals / Non-Goals

**Goals:**

- Domain logic tested with `swift test` in seconds, in CI, without XcodeGen.
- A one-way dependency from Apps to the core.

**Non-Goals:**

- Moving persistence into the core. SwiftData models stay in Apps.

## Decisions

**A Foundation-only package.** `Packages/AntennaCore` holds models, parsers,
the Xtream client and the `PlaybackEngine` protocol. It imports Foundation
only and its tests use swift-testing. Apps depend on it and it never depends
on Apps. SwiftData models stay in Apps because they are an app persistence
concern.

The decision recorded no alternatives. Keeping this logic in the app targets
would tie its tests to Xcode and a generated project, which is what the
context rules out.

## Risks / Trade-offs

- Some duplication between `SourceDescriptor` (core) and `SourceRecord`
  (app). Accepted as the cost of the boundary.
