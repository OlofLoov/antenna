# Antenna

Native IPTV player for iPhone, iPad, Mac and Apple TV. Plays the user's own
sources (M3U, Xtream, later Stalker / Jellyfin / Channels DVR). Ships no content.

## Commands

```sh
swift test --package-path Packages/AntennaCore          # core tests, no Xcode needed
swift format lint --strict --recursive --parallel Apps Packages   # formatting, ships with the toolchain
swiftlint lint --strict                                  # conventions; brew install swiftlint
scripts/check-rules.sh                                   # decision greps: layering, CloudKit, availability
openspec validate --all --strict                         # specs and changes; npm install -g @fission-ai/openspec@1.16.0
scripts/check-spec-refs.sh                               # every cited requirement exists in openspec/specs or an active change
scripts/build-ffmpeg.sh macos                            # LGPL demux-only FFmpeg.framework; all platforms and the xcframework need Xcode
swift test --disable-keychain --package-path Packages/FFmpeg   # the published FFmpeg build against the stream fixtures
swift test --disable-keychain --package-path Packages/AntennaDemux   # the FFmpeg playback path, decoded by VideoToolbox
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
- `Packages/AntennaDemux/` the FFmpeg playback path: HTTP bytes, FFmpeg demuxing,
  sample buffers for Apple's decoders. `Packages/FFmpeg/` is the LGPL FFmpeg
  build it links, published by `scripts/build-ffmpeg.sh`.
- `Apps/Shared/` SwiftUI shared by every platform. SwiftData records and the
  Keychain `CredentialStore` live in `Persistence/`.
- `Apps/Mobile/`, `Apps/TV/` per-target extras only (`Platform.swift`, Info.plist).
- `project.yml` is the source of truth for the Xcode project. Edit it, not the pbxproj.

## How we work

- **Specs and changes are OpenSpec.** `openspec/specs/<capability>/spec.md`
  says what the app does today: requirements with WHEN/THEN scenarios a user
  or caller can observe. New work is a change in `openspec/changes/<name>/`:
  `proposal.md` (why, what, which capabilities), delta specs, `design.md`
  (decisions, layout from the boards, identifiers) and `tasks.md`. Start one
  with `/opsx:propose` (or `/opsx:explore` first), build it with
  `/opsx:apply`, check it with `/opsx:verify`, and fold it into the specs
  with `/opsx:archive` in its last PR. No feature code without a change.
  `openspec/config.yaml` holds the project context and per-artifact rules
  every change follows.
- **Design first for screens.** Every screen has a board in
  `openspec/specs/design-system/boards/`, and the design rules are the
  `design-system` capability. A change's `design.md` names the boards and
  design-system requirements it follows. No board, no change.
- **Decisions live in design.md.** Anything hard to reverse (data model,
  playback path, sync, dependency) is decided in a change's `design.md` with
  the options considered. The standing rules those decisions produced are
  the hard constraints below and in `openspec/config.yaml`.
- **Views compose.** Components in `Apps/Shared/Components/` take values and
  closures, screens in `Apps/Shared/Views/` own queries and models and
  provide shared state through `@Entry`. No `Bool` picks a layout. The
  `swiftui-composition` skill has the rules and a grep pass.
- **Diagrams follow the code.** C4 context and container diagrams live in
  `docs/architecture/` as `.drawio.svg`. A change that adds a container,
  external system or dependency updates them in the same PR.
- **Lint before commit.** The git pre-commit hook runs `swift format lint
  --strict` on staged Swift files, and `swiftlint` when it is installed.
- **Tests cite requirements.** A test that proves a requirement names it as
  `<capability>/<requirement-slug>` in its name or a comment, for example
  `// guide-data/programmes-in-a-time-window`. `scripts/check-spec-refs.sh`
  fails CI when a cited requirement does not exist.
- **Everything ends in a PR.** Code, changes, CI changes, this file. Never
  commit on main and never push to main. Hooks refuse both. Finish work with
  the `pr` skill, which branches, verifies, commits and opens the PR.
- **Conventional Commits** are enforced by a commit-msg hook and in CI:
  `type(scope): subject`. Details in `docs/conventions.md`.
- **No AI slop.** Every doc, spec, change, commit message, PR body and code
  comment goes through the `no-ai-slop` skill (imported from
  petergyang/no-ai-slop, MIT). A hook reminds you after each file change and
  before each commit or PR; run its Detect pass and fix what it names.
- Conventions (style, concurrency, errors, SwiftData rules): `docs/conventions.md`.

## Hard constraints

- CloudKit-backed SwiftData: every stored property optional or defaulted, no
  `@Attribute(.unique)`, relationships optional. Duplicates are resolved in code.
- Secrets never go in SwiftData or logs. Keychain only, synchronizable.
- AntennaCore imports Foundation only. Apps depend on it, never the reverse.
- Two playback paths: `AVPlayer` for HLS and system-demuxable containers,
  FFmpeg demux with VideoToolbox decode and `AVSampleBufferVideoRenderer` for
  raw MPEG-TS. No software renderer. FFmpeg stays LGPL, linked dynamically.
- Per-device state that is not a secret goes in `UserDefaults`, not SwiftData
  or CloudKit. No secret or stream link is stored there.
- Paid unlock only. One entitlement from StoreKit 2 unlocks everything; no
  other feature gate and no trial logic in the app.
- Every `#Preview` is deterministic (fixtures, no network, no clock). CI
  exports each one as a PNG for review; nothing is compared automatically.
- Strict concurrency is `complete`. Fix warnings, do not suppress them.
- Deployment target is 26.0 on every platform. Do not add availability checks below it.
- No bundled playlists, provider links, or marketplace features (App Review 5.2.3).
