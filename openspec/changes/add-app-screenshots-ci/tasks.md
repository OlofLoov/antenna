# Tasks

## 1. Seed data and test targets

- [x] 1.1 Add `Apps/Shared/Debug/UITestingScreenshots.swift` with `-ui-screenshots full|empty`, Debug only, wired into the iOS app entry and the tvOS shell. Verify: a unit test in `AntennaTests` builds the `full` data and counts 2 sources, 12 channels and 4 favorites.
- [x] 1.2 Add `AntennaJourneys` and `AntennaTVJourneys` to `project.yml` and the schemes, with the `snap(_:anchor:)` helper. Verify: `Build apps` passes in CI.

## 2. Walk-throughs

- [ ] 2.1 iOS `firstRun` and `browse`, adding accessibility identifiers where a step has no anchor. Verify: both pass on iPhone and iPad in CI with one screenshot per step.
- [ ] 2.2 tvOS `shell` and `shellStates`. Verify: both pass on Apple TV in CI with one screenshot per step.

## 3. CI job

- [ ] 3.1 Add `scripts/export-screenshots.sh` around `xcrun xcresulttool export attachments`. Verify: `shellcheck` passes in the Lint workflow.
- [ ] 3.2 Add the `App screenshots` job as in design.md. Verify: a PR run has an `app-screenshots` artifact with `<device>/<test>/<nn>-<step>.png` files for iPhone, iPad and Apple TV.
- [ ] 3.3 Say where the artifact is and how to add a step in `docs/conventions.md` and `CLAUDE.md`. Verify: the `Doc links` check passes.

## 4. Verify

- [ ] 4.1 No requirement is added or changed (`skip_specs: true`), so no test cites a new one. Verify: `scripts/check-spec-refs.sh` and `openspec validate --all --strict` pass.
- [ ] 4.2 `/opsx:verify add-app-screenshots-ci` passes.
