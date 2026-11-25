# Antuna

Native IPTV player for iPhone, iPad, Mac and Apple TV. Plays the user's own
sources (M3U, Xtream, later Stalker / Jellyfin / Channels DVR). Ships no content.

Antuna is the name people see: the app, the store listing, the site at
antuna.app and the docs. Code names keep "Antenna": the packages, modules,
targets, schemes, `Antenna.xcodeproj`, type names, bundle ids, the iCloud
container, App Group and Keychain ids, UserDefaults keys and file names
(`rename-to-antuna` design.md lists them). Do not rename them.

## Commands

```sh
swift test --build-system swiftbuild --package-path Packages/AntennaCore   # core tests; Swift Build compiles the String Catalog
scripts/test-core-in-language.sh ar-SA ar_SA   # core tests as on a Mac set to Arabic; CI and pre-push run German
swift format lint --strict --recursive --parallel Apps Packages   # formatting, ships with the toolchain
swiftlint lint --strict                                  # conventions; brew install swiftlint
scripts/check-rules.sh                                   # decision greps: layering, CloudKit, availability
openspec validate --all --strict                         # specs and changes; npm install -g @fission-ai/openspec@1.16.0
scripts/check-spec-refs.sh                               # every cited requirement exists in openspec/specs or an active change
scripts/check-translations.sh                            # every catalog key has text in each language in Config/languages
scripts/sync-strings.sh                                  # write new string literals into the String Catalogs; --check fails instead
scripts/build-ffmpeg.sh macos                            # LGPL demux-only FFmpeg.framework; all platforms and the xcframework need Xcode
swift test --disable-keychain --package-path Packages/FFmpeg   # the published FFmpeg build against the stream fixtures
swift test --disable-keychain --package-path Packages/AntennaDemux   # the FFmpeg playback path, decoded by VideoToolbox
scripts/make-review-guide.py Web/review/antuna-review.m3u 2026-01-01 36   # the App Review guide for a start day and length
actionlint                                               # workflow files, including release.yml; brew install actionlint
(cd Web/site && npm ci && npm run lint && npm run check)  # the website: Prettier, ESLint, svelte-check; Node 22 from Web/site/.nvmrc
(cd Web/site && npm run build && npm test)                # prerender every page, then the link, route, policy and budget check
scripts/publish-web.sh /tmp/site Web/site/build           # the final file tree: plain files in Web/ plus the built app
scripts/site-screenshots.sh en                           # the site's pictures from the newest store-screenshots artifact, with gh and sips
terraform fmt -check -recursive Infra                    # Terraform 1.17.2, pinned in each root
terraform -chdir=Infra/antuna init -backend=false && terraform -chdir=Infra/antuna test   # infra plans against a mocked AWS; Infra/ci too
node --test Infra/modules/site/tests/review.test.mjs     # the App Review demo server's CloudFront Function against the generated answers
scripts/render-icons.sh                                  # app icons and Apple TV brand assets from design/icon/*.svg
xcodegen generate                                        # regenerate Antenna.xcodeproj (git-ignored)
xcodebuild build -project Antenna.xcodeproj -scheme Antenna   -destination 'generic/platform=iOS Simulator'  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Antenna.xcodeproj -scheme AntennaTV -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Run `scripts/setup.sh` once per clone. It points git at `scripts/githooks`
(commit lint, no commits on main, `scripts/fast-checks.sh` before each push)
and checks for xcodegen and gh.

`Config/Local.xcconfig` holds `DEVELOPMENT_TEAM` and is git-ignored. Copy it
from `Config/Local.xcconfig.example` for device builds. With a personal (free)
team set `ANTENNA_PAID_TEAM = NO` there: it signs without iCloud, push and
associated domains, and the app runs without sync.

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
- `Web/` the site, served from CloudFront at antuna.app and
  uploaded from main by the site job in `.github/workflows/infra.yml` through
  `scripts/publish-web.sh <out> <site build>`. It is live.
  `Web/site/` is a SvelteKit app with every page prerendered
  (home, nine feature pages, pricing, support, the Terms of Use and Privacy
  Policy the paywall links to, 404), built
  with Node 22 from its committed lockfile. It runs only its own bundled
  JavaScript and shows only its own images: no third-party scripts, fonts,
  trackers or analytics, no cookies, no inline scripts or styles, and no
  requests to other origins. `Web/site/scripts/check-site.js` enforces that on
  the build. The plain files outside the app stay as they are: the setup page
  (no script, no image, no stylesheet), the association file whose Apple team
  id the publish step fills from the `APPLE_TEAM_ID` repository variable, and
  `review/`, the App Review playlist of Apple's sample streams, whose guide
  the publish step writes with `scripts/make-review-guide.py`; these data
  files are the one place the site names outside addresses, and the app never
  names them. `WebsiteTests`, `SetupPageTests` and `ReleaseTests` in
  AntennaCore check the plain files and the legal text, the site's Vitest
  checks the built pages.
- `Infra/` the Terraform for AWS: `bootstrap/` (state bucket), the `ci` and
  `antuna` roots, and `modules/`. `.github/workflows/infra.yml` plans on PRs,
  applies on main and uploads the site. There is no API and no server of our
  own; the site is static files.
- `docs/release/` the App Review notes and the App Store Connect privacy and
  trader contact answers.
- `design/icon/` the SVG sources of the app icons. `scripts/render-icons.sh`
  copies them into `Apps/Mobile/AppIcon.icon` (Icon Composer, iPhone, iPad
  and Mac) and renders `Apps/TV/Assets.xcassets` (Apple TV layers and Top Shelf).
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
- **Releases are a merge.** release-please (`.github/workflows/release.yml`)
  keeps a `chore(build): release X.Y.Z` PR open with the changelog from the
  commits on main. Merging it tags `vX.Y.Z`, publishes the GitHub release,
  bumps `MARKETING_VERSION` in `Config/version.yml` and republishes the site.
  Nothing is uploaded to App Store Connect yet. Only the owner merges a
  release PR. A `feat` commit bumps the minor version, a `fix` the patch.
- **Lint before commit.** The git pre-commit hook runs `swift format lint
  --strict` on staged Swift files, and `swiftlint` when it is installed.
- **Simulator tests run nightly.** PR CI runs AntennaCore and builds the
  apps, and skips both when a PR changes only `openspec/`. A push to main
  runs only the Linux checks. Every night CI runs AntennaCore, the app
  builds and the preview snapshots on main, and the `UI tests` workflow runs
  the iPhone, iPad and tvOS UI tests and the tvOS unit tests, split across
  parallel jobs. A failing night opens an issue. No PR runs the UI tests;
  to run them on a branch, `gh workflow run ui-tests.yml --ref <branch>`.
  Run the UI test classes a change touches on a local simulator before
  opening its PR (see the `sim` skill).
- **Screenshots on demand.** The `App screenshots` workflow walks the main
  screens on iPhone, iPad and Apple TV and uploads the PNGs as the
  `app-screenshots` artifact, plus the App Store set per ready language as
  `store-screenshots`. It runs every night; on a branch, `gh
  workflow run screenshots.yml --ref <branch>`. How to add a step: `docs/conventions.md`, Tests.
  The store listing text is in `fastlane/metadata/` (`docs/release/store-listing.md`).
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
- Secrets never go in SwiftData or logs. Keychain only, synchronizable. One
  exception: an HPKE-sealed login drop for an Apple TV may sit in the private
  CloudKit database, in encrypted values, for at most 10 minutes, and is
  deleted on pickup.
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
