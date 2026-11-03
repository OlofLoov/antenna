# Antenna

Native IPTV player for iPhone, iPad, Mac and Apple TV. Plays the user's own
sources (M3U, Xtream, later Stalker / Jellyfin / Channels DVR). Ships no content.

## Commands

```sh
swift test --package-path Packages/AntennaCore          # core tests, no Xcode needed
xcodegen generate                                        # regenerate Antenna.xcodeproj (git-ignored)
xcodebuild build -project Antenna.xcodeproj -scheme Antenna   -destination 'generic/platform=iOS Simulator'  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Antenna.xcodeproj -scheme AntennaTV -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Run `scripts/setup.sh` once per clone. It points git at `scripts/githooks`
(commit lint, no commits on main) and checks for xcodegen and gh.

`Config/Local.xcconfig` holds `DEVELOPMENT_TEAM` and is git-ignored. Copy it
from `Config/Local.xcconfig.example` for device builds.

## Layout

- `Packages/AntennaCore/` pure Swift, no UI: models, M3U + XMLTV parsers,
  Xtream client, `PlaybackEngine` protocol and `EngineRouter`. Swift 6 language
  mode, swift-testing. All parsing and protocol logic goes here, never in Apps.
- `Apps/Shared/` SwiftUI shared by every platform. SwiftData records and the
  Keychain `CredentialStore` live in `Persistence/`.
- `Apps/Mobile/`, `Apps/TV/` per-target extras only (`Platform.swift`, Info.plist).
- `project.yml` is the source of truth for the Xcode project. Edit it, not the pbxproj.

## How we work

- **Spec first.** Feature work starts from a spec in `docs/specs/` with
  Given/When/Then acceptance criteria. No feature code without a spec id.
  Use the `spec` skill to write one, then run the `spec-reviewer` agent on it.
- **Decisions are ADRs.** Anything that would be hard to reverse (data model,
  playback path, sync, dependency) gets a record in `docs/adr/` via the `adr`
  skill. Read `docs/adr/README.md` before proposing architecture changes.
- **Tests cite criteria.** A test that proves acceptance criterion `AC-3` of
  spec `0007` says so in its name or a comment: `// 0007/AC-3`.
- **Review against the spec.** Before a PR, run the `impl-reviewer` agent with
  the spec id and the diff.
- **Everything ends in a PR.** Code, specs, ADRs, CI changes, this file. Never
  commit on main and never push to main. Hooks refuse both. Finish work with
  the `pr` skill, which branches, verifies, commits and opens the PR.
- **Conventional Commits** are enforced by a commit-msg hook and in CI:
  `type(scope): subject`. Details in `docs/conventions.md`.
- Conventions (style, concurrency, errors, SwiftData rules): `docs/conventions.md`.

## Hard constraints

- CloudKit-backed SwiftData: every stored property optional or defaulted, no
  `@Attribute(.unique)`, relationships optional. See ADR-0002.
- Secrets never go in SwiftData or logs. Keychain only, synchronizable. See ADR-0003.
- Strict concurrency is `complete`. Fix warnings, do not suppress them.
- Deployment target is 26.0 on every platform. Do not add availability checks below it.
- No bundled playlists, provider links, or marketplace features (App Review 5.2.3).
