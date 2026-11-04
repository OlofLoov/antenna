# Conventions

## Swift

- Swift 6 language mode, strict concurrency `complete`. Prefer value types and
  `Sendable`. Isolate UI state to `@MainActor`; keep AntennaCore free of actors
  that assume the main thread.
- `any` is required for existentials (`SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY`).
- Public API in AntennaCore is documented with a `///` comment that says what
  the caller can rely on, not what the code does.
- Errors are typed enums per subsystem (`XtreamClient.Error`,
  `CredentialStore.StoreError`). Do not throw `NSError` or strings.
- No force unwraps outside tests and fixtures.

## Layering

- AntennaCore must not import SwiftUI, SwiftData, UIKit or AppKit.
- Apps talk to playback only through `PlaybackEngine`. Engine selection goes
  through `EngineRouter`.
- Network parsing (M3U, XMLTV, Xtream JSON) is pure functions over `String` /
  `Data` so it is testable with fixtures.

## SwiftData + CloudKit

- All stored properties optional or with a default. No `@Attribute(.unique)`.
  Relationships optional. Enums stored as raw values with a computed accessor.
- Schema changes need an ADR and a migration note in the spec.

## Tests

- AntennaCore: swift-testing, fixtures in `Tests/AntennaCoreTests/Fixtures`.
- Every acceptance criterion in an accepted spec has at least one test that
  names it: `@Test("0007/AC-3 empty tvg-id is not an EPG id")`. In an
  XCUITest the citation is a comment, `// 0007/AC-3`. `scripts/check-specs.sh`
  greps for exactly this form, so write the id as `NNNN/AC-n` with no spaces.
- UI tests use accessibility identifiers of the form `screen.element`
  (`channels.searchField`). Never match on display text.

## Git

- Nothing is committed on main or pushed to main. Every change, including a
  single ADR, goes through a branch and a PR opened with the `pr` skill.
- Branches: `feat/NNNN-slug`, `fix/slug`, `docs/adr-NNNN-slug`,
  `docs/spec-NNNN-slug`, `chore/slug`, `ci/slug`.
- Conventional Commits, enforced locally by `scripts/githooks/commit-msg` and
  in CI on every PR commit and on the PR title:
  - `type(scope): subject`, header at most 72 characters, imperative, no
    trailing period.
  - Types: feat, fix, docs, refactor, test, build, ci, chore, perf, style, revert.
  - Scopes (optional): core, app, tv, mobile, adr, spec, ci, build, docs.
  - Footer `Spec: NNNN` on feature commits, `ADR: NNNN` when an ADR is added
    or superseded. Breaking changes use `!` after the scope.
- One logical change per commit. Specs and ADRs go in their own commit ahead
  of the code that implements them.
- PR title is the conventional header of the main commit. PR body follows the
  template and links spec and ADRs. Squash-merge, so the PR title becomes the
  commit on main.
