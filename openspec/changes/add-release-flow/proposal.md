# Proposal

## Why

The owner has no way to cut a version of Antenna. Nothing records what changed
since the last build, the apps all say version 1.0, and App Review would reject
a first submission: there is no privacy manifest, no review notes, and the
reviewer has no source to add, because Antenna ships no content. After this
change the owner approves a release by merging one pull request, every app
bundle carries that version and a privacy manifest, and the reviewer gets
notes and a test playlist with a working guide.

## What Changes

- release-please runs on every push to main and keeps one release pull request
  open. Its changelog comes from the Conventional Commits the repo already
  enforces. Merging it tags `vX.Y.Z` and publishes a GitHub release.
- The marketing version lives in one file that release-please bumps and the
  Xcode project reads. The iPhone, iPad, Mac, Apple TV and Top Shelf bundles
  all report it.
- Each app bundle and the Top Shelf extension carry a privacy manifest: no
  tracking, no collected data, and the required-reason APIs the code calls.
- `docs/release/` holds the App Review notes and the App Store Connect App
  Privacy answers.
- The site at antenna.code-crave.se serves a reviewer playlist of Apple's
  public HLS sample streams and an XMLTV guide for them, regenerated each time
  the site publishes and after each release. The app never names or links it.

Out of scope:

- Uploading to App Store Connect or TestFlight, signing and archiving. The
  release workflow exposes `release_created` for that later job.
- Crash or diagnostics data in the privacy manifest; a later diagnostics change
  adds it.
- App Store metadata, screenshots and the description.

## Capabilities

### New Capabilities

- `app-release`: how a version of Antenna is approved and published, what
  version the apps report, what each bundle declares about privacy, and the
  test source App Review uses.

### Modified Capabilities

None.

## Impact

- New: `.github/workflows/release.yml`, `release-please-config.json`,
  `.release-please-manifest.json`, `Config/version.yml`, `PrivacyInfo.xcprivacy`
  in `Apps/Mobile`, `Apps/TV` and `Apps/TopShelf`, `docs/release/`,
  `Web/review/`, `scripts/make-review-guide.py`.
- Changed: `project.yml` (includes the version file, Info.plist version keys),
  `Config/Shared.xcconfig` (drops `MARKETING_VERSION`), the three Info.plists,
  `scripts/publish-web.sh`, `WebsiteTests`, `scripts/check-rules.sh`, CLAUDE.md.
- Depends on the site from `add-antenna-website` and its Pages workflow, and on
  the commit lint in `scripts/lint-commit.sh`.
- Blocked on the owner for one setting: GitHub Actions must be allowed to
  create pull requests in the repository settings, or release-please cannot
  open its pull request.
