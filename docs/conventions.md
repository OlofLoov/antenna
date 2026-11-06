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
- Formatting is what `swift format` produces with `.swift-format`: four-space
  indent, 140 columns, trailing commas in multi-line collections. SwiftLint
  (`.swiftlint.yml`) enforces the rest of this list. CI runs both with
  `--strict`, so a warning fails the PR.

## Layering

- AntennaCore must not import SwiftUI, SwiftData, UIKit or AppKit.
- Apps talk to playback only through `PlaybackEngine`. Engine selection goes
  through `EngineRouter`.
- Network parsing (M3U, XMLTV, Xtream JSON) is pure functions over `String` /
  `Data` so it is testable with fixtures.

## SwiftData + CloudKit

- All stored properties optional or with a default. No `@Attribute(.unique)`.
  Relationships optional. Enums stored as raw values with a computed accessor.
- Schema changes are decided in the change's `design.md`, with a migration note.

## Tests

- AntennaCore: swift-testing, fixtures in `Tests/AntennaCoreTests/Fixtures`.
- Every requirement a change adds has at least one test that names it as
  `<capability>/<requirement-slug>`:
  `@Test("m3u-playlists/empty-tvg-id-is-not-a-guide-id: ...")`. In an
  XCUITest the citation is a comment. The slug is the requirement name
  lowercased, with each run of other characters turned into one hyphen.
  `scripts/check-spec-refs.sh` fails CI when a cited requirement is missing
  from `openspec/specs/`, so a change that renames a requirement updates the
  tests that cite it.
- Benchmarks run only with `ANTENNA_BENCHMARKS=1`. Gate them with
  `.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1")`.
- UI tests use accessibility identifiers of the form `screen.element`
  (`channels.searchField`). Never match on display text.

## Git

- Nothing is committed on main or pushed to main. Every change, including a
  single change proposal, goes through a branch and a PR opened with the
  `pr` skill.
- Branches: `feat/<change-name>`, `fix/slug`, `docs/<change-name>`,
  `chore/slug`, `ci/slug`.
- Conventional Commits, enforced locally by `scripts/githooks/commit-msg` and
  in CI on every PR commit and on the PR title:
  - `type(scope): subject`, header at most 72 characters, imperative, no
    trailing period.
  - Types: feat, fix, docs, refactor, test, build, ci, chore, perf, style, revert.
  - Scopes (optional): core, app, tv, mobile, spec, ci, build, docs.
  - Footer `Change: <name>` on commits that implement an OpenSpec change.
    Breaking changes use `!` after the scope.
- One logical change per commit. Proposal and spec edits go in their own
  commit ahead of the code that implements them; the archive goes last.
- PR title is the conventional header of the main commit. PR body follows the
  template and links the change folder. Rebase-merge, so every commit on the
  branch lands on main as pushed; no WIP or fixup commits in a PR.
- A change too big for one small PR ships as a stack: `feat/<name>-1`,
  `-2` and so on, each based on the one before. The task groups in
  `tasks.md` set the cut, the `pr` skill opens and rebases it with `gh stack`, so GitHub
  shows the PRs as one stack.
