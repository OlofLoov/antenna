# Tasks

## 1. Version and release workflow

- [ ] 1.1 Add `Config/version.yml` with `MARKETING_VERSION`, include it from `project.yml`, drop `MARKETING_VERSION` from `Config/Shared.xcconfig`, and set `CFBundleShortVersionString` and `CFBundleVersion` to the build settings in the three Info.plists through `project.yml`; `ReleaseTests` checks each plist and the include, and the built apps report 0.1.0
- [ ] 1.2 Add `release-please-config.json` (type `simple`, `yaml` extra file, `bump-minor-pre-major`, `bootstrap-sha`, title pattern) and `.release-please-manifest.json` at 0.0.0; `ReleaseTests` checks the jsonpath resolves in `Config/version.yml` and the title passes `scripts/lint-commit.sh`
- [ ] 1.3 Add `.github/workflows/release.yml` running release-please on pushes to main, pinned by commit, exposing `release_created`, `tag_name` and `version`, and dispatching `pages.yml` after a release; actionlint passes and `ReleaseTests` checks the trigger, the pin and the outputs

## 2. Privacy manifests

- [ ] 2.1 Add `PrivacyInfo.xcprivacy` to `Apps/Mobile`, `Apps/TV` and `Apps/TopShelf` with the categories and reasons in design.md; `ReleaseTests` parses each one
- [ ] 2.2 Build both schemes and confirm each `.app` and the `.appex` contain `PrivacyInfo.xcprivacy`
- [ ] 2.3 Write `docs/release/app-privacy.md` with the App Store Connect answers and why

## 3. Reviewer source

- [ ] 3.1 Add `Web/review/antenna-review.m3u` with Apple's four sample streams and the guide address in its header
- [ ] 3.2 Add `scripts/make-review-guide.py` and run it from `scripts/publish-web.sh`; `WebsiteTests` parses the published guide with the app's XMLTV parser and checks it covers every playlist channel for at least four weeks from a fixed start date
- [ ] 3.3 Add a `scripts/check-rules.sh` grep that fails when `Apps/` names the review address; the script passes
- [ ] 3.4 Write `docs/release/app-review-notes.md` with the reviewer text: no content (5.2.3), adding the source, the sandbox purchase

## 4. Docs

- [ ] 4.1 Add the release flow to CLAUDE.md's Commands and How we work, and the review files to the `Web/` entry in Layout

## 5. Verify

- [ ] 5.1 Each requirement in `app-release` has a test citing `app-release/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 5.2 `swift test` for AntennaCore, swift format, SwiftLint, `scripts/check-rules.sh`, `openspec validate --all --strict` and the iOS and tvOS builds pass
- [ ] 5.3 `/opsx:verify` passes

## Workflow follow-up

- Archive the change in the last commit of the PR.
- After the merge, confirm release-please ran on main and opened its release PR. The owner merges that PR to approve the first release.
