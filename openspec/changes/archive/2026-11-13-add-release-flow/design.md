# Design

## Context

Commits on main already follow Conventional Commits: `scripts/lint-commit.sh`
checks every PR commit and title in CI, and main is rebase-merged, so each
commit lands as written. The repo ruleset on main only forbids deletion and
force pushes; no status check is required.

`MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1` sit in
`Config/Shared.xcconfig`, but the three committed Info.plists hard-code
`CFBundleShortVersionString` 1.0 and `CFBundleVersion` 1, so no build reports
0.1.0 today.

No bundle has a privacy manifest. The required-reason APIs the code calls:

| Category | Where | Use |
|----------|-------|-----|
| User defaults | every screen's per-device state (`shell.`, `recents.`, `paywall.entitlement` and others) | the app's own values, read and written only by the app |
| Disk space | `TimeshiftStore` reads `volumeAvailableCapacityForImportantUsage` | checks there is room before the timeshift buffer writes to disk |
| File timestamp | `PosterCache` reads `contentModificationDate` of its own files | evicts the least recently used posters from the app's cache folder |

No code reads system boot time or the active keyboards. `ContinuousClock` is
not on Apple's list. `nm -u` on the built tvOS bundles shows:

- the app: `NSUserDefaults`, `NSURLVolumeAvailableCapacityKey`,
  `NSURLContentModificationDateKey`, `NSFileModificationDate`;
- the Top Shelf extension: `NSURLVolumeAvailableCapacityKey` only. It never
  checks disk space, but it links AntennaCore, which holds the timeshift check;
- FFmpeg.framework: `fstat`, from FFmpeg's own file helpers. FFmpeg is built
  with `--disable-everything` and no protocols and Antenna never calls them.

The site at antenna.code-crave.se is static, published by `pages.yml` when a
push to main touches `Web/`, and checked by `WebsiteTests`.

## Goals / Non-Goals

**Goals:**

- One merge by the owner produces a tag, a GitHub release and a version every
  bundle reports.
- A later job can archive and upload a build when a release is created,
  without changing how releases are approved.
- A first App Review submission has a privacy manifest per bundle, notes, a
  test source and the App Privacy answers ready to paste.

**Non-Goals:**

- Signing, archiving, uploading, App Store Connect API keys.
- A changelog shown inside the app.
- Crash and diagnostics reporting.

## Decisions

### release-please, pinned by commit

`googleapis/release-please-action` v5.0.0, pinned to commit
`45996ed1f6d02564a971a2fa1b5860e934307cf7`, runs in
`.github/workflows/release.yml` on every push to main, with
`release-please-config.json` and `.release-please-manifest.json` at the root.

Options considered:

- release-please. Keeps a release PR up to date, changelog from the commit
  types the repo already enforces, tag and GitHub release on merge, and an
  output (`release_created`) a later job can gate on. Chosen.
- semantic-release. Releases on every push with releasable commits. The owner
  wants to approve each release, and there is no PR to merge.
- A hand-run `workflow_dispatch` that tags and writes notes. Approval by
  clicking a button gives no reviewable diff of the changelog and version.

The action runs with `contents: write` and `pull-requests: write`. It uses
the `RELEASE_PLEASE_TOKEN` secret when the owner adds one and the workflow
token otherwise. Pull requests opened with the workflow token start no other
workflow, so the release PR shows no CI checks. Nothing on main requires a
check, so it still merges, and CI runs on main after the merge. A
fine-grained token with contents and pull requests write access, stored as
`RELEASE_PLEASE_TOKEN`, makes CI run on the release PR too.

The repository setting "Allow GitHub Actions to create and approve pull
requests" must be on for the workflow token to open the PR.

### Release type and where the version lives

Release type `simple`, with the version in `Config/version.yml`:

```yaml
settings:
  base:
    MARKETING_VERSION: 0.1.0
```

`project.yml` includes it, so XcodeGen writes `MARKETING_VERSION` as a
project-level build setting every target inherits, and `Config/Shared.xcconfig`
drops its copy. release-please's `yaml` updater sets
`$.settings.base.MARKETING_VERSION` there. The Info.plists read
`$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` instead of fixed
strings, set in `project.yml` so XcodeGen keeps them.

Options considered:

- The generic updater with an `x-release-please-version` marker on the
  `MARKETING_VERSION` line of `Shared.xcconfig`. Needs a marker comment in a
  config file, and config files here carry no comments.
- release-please's `yaml` updater on `project.yml`. It reloads and dumps the
  whole file, which drops its comments and reflows it on every release.
- `version.txt`, the `simple` default, read by a build phase that patches the
  Info.plist. Adds a script phase under user script sandboxing to every
  target, and a plain build stops showing the version in build settings.
- A small included YAML file that the `yaml` updater may reformat freely.
  The file holds one key, so the reformat is a no-op. Chosen.

### Build number

`CURRENT_PROJECT_VERSION` stays `1` in `Shared.xcconfig` for local and CI
builds. The future upload job passes
`CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)` to `xcodebuild archive`.
Main is linear (rebase merges, force pushes refused by the ruleset), so the
commit count only grows, a rerun of the same commit gets the same number, and
anyone can reproduce it from a checkout. `github.run_number` was the other
option; it changes on reruns and depends on the workflow file's history.

### Starting version and bumps

The manifest starts at `0.0.0` with `bootstrap-sha` set to the main commit
before this change, so the first release PR covers what lands after it and
proposes `0.1.0`, the version the apps already carry. `Config/version.yml`
starts at `0.1.0`.

`bump-minor-pre-major` is on: before 1.0, a breaking commit bumps the minor
version instead of jumping to 1.0.0. The App Store launch becomes 1.0.0 with a
`Release-As: 1.0.0` footer on a commit, a decision the owner makes once.

Tags are `vX.Y.Z` with no component (`include-component-in-tag: false`). The
existing `ffmpeg-*` releases do not parse as this package's releases, so they
do not disturb the version.

### The release PR passes commit lint

release-please titles its PR and commit `chore(main): release 0.1.0` by
default. The lint regex accepts any lowercase scope, but `main` is not one of
the documented scopes, so `pull-request-title-pattern` is
`chore(build): release ${version}`. The PR body and `CHANGELOG.md` are
release-please's defaults. `ReleaseTests` runs the title through
`scripts/lint-commit.sh`.

### The future upload step

`release.yml` exposes `release_created`, `tag_name` and `version` as job
outputs. The upload change adds a job:

```yaml
upload:
  needs: release
  if: needs.release.outputs.release_created == 'true'
  runs-on: macos-26
```

that checks out the tag, sets the build number from the commit count,
archives both schemes and uploads with an App Store Connect API key. Nothing
in the approval flow changes.

### Privacy manifests

One `PrivacyInfo.xcprivacy` per bundle: `Apps/Mobile/` (iPhone, iPad and Mac),
`Apps/TV/` and `Apps/TopShelf/`. XcodeGen adds each to its target's resources
because the folder is already that target's source.

Every manifest has `NSPrivacyTracking` false, no tracking domains and an empty
`NSPrivacyCollectedDataTypes`. The apps declare:

- `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (the app's own
  values).
- `NSPrivacyAccessedAPICategoryDiskSpace`, reason `E174.1` (checking room
  before writing the timeshift buffer).
- `NSPrivacyAccessedAPICategoryFileTimestamp`, reason `C617.1` (dates of files
  inside the app's container).

The Top Shelf extension declares only the disk space category, with
`E174.1`, for the AntennaCore code it links.

FFmpeg.framework is a separate bundle, so Apple reads its `fstat` against a
manifest inside the framework. `scripts/build-ffmpeg.sh` writes none today.
Adding one means a new `ffmpeg-*` build and a new checksum in
`Packages/FFmpeg/Package.swift`, which belongs with the next FFmpeg update, not
here. Until then the app's manifest declares the file timestamp category, and
the upload change must add the framework manifest before the first upload if
App Store Connect warns about it.

"Collected" in Apple's sense means data the developer or a partner can read
off the device. Antenna sends data to the user's own sources and guide
servers, to the user's private iCloud database, which Code Crave cannot read,
and to Apple for purchases. None of that is collection by Code Crave, so the
App Store answer is "Data Not Collected". `docs/release/app-privacy.md` has
the answers and the reasoning. A later diagnostics change that sends crash
reports adds Crash Data and Performance Data to both the manifests and the
answers.

### Reviewer test source

The site serves `/review/antenna-review.m3u` and `/review/guide.xml`. The
playlist lists four of Apple's public HLS examples from
developer.apple.com/streaming/examples: Basic 4:3, Basic 16:9, Advanced fMP4
and Advanced HEVC, all on `devstreaming-cdn.apple.com`. Its `#EXTM3U` header
names the guide with `url-tvg`, so the reviewer pastes one address.

The guide is generated, not committed: `scripts/make-review-guide.py` writes
an XMLTV file for a start date and a number of days, and `publish-web.sh`
runs it from yesterday (UTC) for 36 days. `release.yml` dispatches `pages.yml`
after each release, so a build submitted for review has a guide that runs at
least four weeks past its release day.

Options considered for the guide:

- A committed XMLTV file. Its dates go stale and the guide goes empty weeks
  after it was written.
- A weekly scheduled publish. Keeps the guide fresh with no release, but the
  site would then publish without a change landing on main, which the
  antenna-website capability rules out.
- Generated on each publish, republished after each release. Chosen.

The site rule in CLAUDE.md, "no scripts, images or third-party content", is
about what a browser loads from a page. The playlist and guide are data files
for the app, not pages: no browser renders them, and the stream links are
addresses inside a text file. The rule stays and CLAUDE.md says the review
files are the one place the site names outside addresses.

The app never names the review address. `scripts/check-rules.sh` gains a grep
that fails when `Apps/` mentions `/review/`. The App Review notes in
`docs/release/app-review-notes.md` give the address to the reviewer.

### Architecture diagrams

No diagram changes. GitHub Releases and Apple's sample stream host are not
systems the app talks to at run time. A reviewer's source is a user source
like any other, already in the context diagram.

## Risks / Trade-offs

- [Apple moves or removes a sample stream] → `WebsiteTests` cannot see the
  network. The review notes say to check each address with `curl -I` before
  a submission.
- [The repository setting for Actions-created PRs is off] → release-please
  fails with a permission error on the first push. The owner turns it on, or
  adds `RELEASE_PLEASE_TOKEN`.
- [CI does not run on the release PR] → the PR changes only
  `CHANGELOG.md`, `Config/version.yml` and the manifest; CI runs on main after
  the merge. A token secret turns CI on for it.
- [The guide is generated in UTC] → a reviewer far east of UTC sees the guide
  start a few hours later than midnight local; it starts the day before
  publishing to cover that.

## Migration Plan

Merge, then turn on "Allow GitHub Actions to create and approve pull
requests" if release-please reports it cannot open the PR. The first release
PR appears after the next `feat` or `fix` lands on main. Rollback is deleting
`release.yml`; tags and releases already made stay.
