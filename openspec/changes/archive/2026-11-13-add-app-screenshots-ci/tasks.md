# Tasks

## 1. Seed data and test targets

- [x] 1.1 Add `Apps/Shared/Debug/UITestingScreenshots.swift` with `-ui-screenshots full|empty`, Debug only, wired into the iOS app entry and the tvOS shell. Verify: a unit test in `AntennaTests` builds the `full` data and counts 2 sources, 12 channels and 4 favorites.
- [x] 1.2 Add `AntennaJourneys` and `AntennaTVJourneys` to `project.yml` and the schemes, with the `snap(_:anchor:)` helper. Verify: `Build apps` passes in CI.

## 2. Walk-throughs

- [x] 2.1 iOS `firstRun` and `browse`, adding accessibility identifiers where a step has no anchor. Verify: both pass on iPhone and iPad with one screenshot per step.
- [x] 2.2 tvOS `firstRun`, `shell` and `shellStates`. Verify: all pass on Apple TV with one screenshot per step.

## 3. CI job

- [x] 3.1 Add `scripts/export-screenshots.sh` around `xcrun xcresulttool export attachments`. Verify: `shellcheck` passes in the Lint workflow.
- [x] 3.2 Add the `App screenshots` workflow as in design.md: nightly, by hand, and on PRs labeled `screenshots`. Verify: `actionlint` passes, and a labeled PR run has an `app-screenshots` artifact with `<device>/<test>/<nn>-<step>.png` files for iPhone, iPad and Apple TV.
- [x] 3.3 Say where the artifact is and how to add a step in `docs/conventions.md` and `CLAUDE.md`. Verify: the `Doc links` check passes.

## 4. Verify

- [x] 4.1 No requirement is added or changed (`skip_specs: true`), so no test cites a new one. Verify: `scripts/check-spec-refs.sh` and `openspec validate --all --strict` pass.
- [x] 4.2 `/opsx:verify add-app-screenshots-ci` passes.
