# Antenna

Native IPTV player for iPhone, iPad, Mac and Apple TV. Plays the user's own
sources (M3U, Xtream, later Stalker / Jellyfin / Channels DVR). Ships no content.

## Commands

```sh
swift test --package-path Packages/AntennaCore          # core tests, no Xcode needed
swift format lint --strict --recursive --parallel Apps Packages   # formatting, ships with the toolchain
swiftlint lint --strict                                  # conventions; brew install swiftlint
scripts/check-rules.sh                                   # ADR greps: layering, CloudKit, availability
scripts/check-arch.sh                                    # architectural change needs an ADR or diagram update
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

- **Design first for screens.** Every screen has a board in `docs/design/`.
  Specs cite the board and the design rules (`DR-n`) that apply; reviewers
  check against them. No board, no spec, no code.
- **Spec first.** Feature work starts from a spec in `docs/specs/` with
  Given/When/Then acceptance criteria. No feature code without a spec id.
  Use the `spec` skill to write one, then run the `spec-reviewer` agent on it.
- **Decisions are ADRs.** Anything that would be hard to reverse (data model,
  playback path, sync, dependency) gets a record in `docs/adr/` via the `adr`
  skill. Read `docs/adr/README.md` before proposing architecture changes.
- **Diagrams follow the code.** C4 context and container diagrams live in
  `docs/architecture/` as `.drawio.svg`. `scripts/check-arch.sh` fails a PR
  that changes architectural paths without touching them or an ADR; the
  `arch-reviewer` agent says which to update.
- **Tests cite criteria.** A test that proves acceptance criterion `AC-3` of
  spec `0007` says so in its name or a comment: `// 0007/AC-3`.
- **Implement with the `implement` skill.** Give it a spec id. It checks the
  spec is Accepted and unblocked, cuts the work into the fewest small
  shippable PRs, writes the code and a test per criterion, sets the spec to
  Implemented in the last diff, runs the `impl-reviewer` agent, then hands
  each PR to the `pr` skill. Main is rebase-merged. Nothing tracks status on the
  side. `scripts/check-specs.sh` fails CI when a spec claims Implemented
  without a test citing every criterion.
- **Everything ends in a PR.** Code, specs, ADRs, CI changes, this file. Never
  commit on main and never push to main. Hooks refuse both. Finish work with
  the `pr` skill, which branches, verifies, commits and opens the PR.
- **Conventional Commits** are enforced by a commit-msg hook and in CI:
  `type(scope): subject`. Details in `docs/conventions.md`.
- **No AI slop.** Every doc, spec, ADR, commit message, PR body and code
  comment goes through the `no-ai-slop` skill (imported from
  petergyang/no-ai-slop, MIT). A hook reminds you after each file change and
  before each commit or PR; run its Detect pass and fix what it names.
- Conventions (style, concurrency, errors, SwiftData rules): `docs/conventions.md`.

## Hard constraints

- CloudKit-backed SwiftData: every stored property optional or defaulted, no
  `@Attribute(.unique)`, relationships optional. See ADR-0002.
- Secrets never go in SwiftData or logs. Keychain only, synchronizable. See ADR-0003.
- Strict concurrency is `complete`. Fix warnings, do not suppress them.
- Deployment target is 26.0 on every platform. Do not add availability checks below it.
- No bundled playlists, provider links, or marketplace features (App Review 5.2.3).
