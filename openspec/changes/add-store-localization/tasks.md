# Tasks

## 1. Listing and check (PR 1)

- [x] 1.1 Write the English listing in `fastlane/metadata/en-US/` and the app-wide files, each claim traced to a spec as in design.md decision 3, and run the no-ai-slop Detect pass on it
- [x] 1.2 Add `scripts/store_metadata.py` and `scripts/check-store-metadata.sh`, run them from `scripts/fast-checks.sh` and the Repo rules job, and verify the check fails on a missing locale, a long subtitle, spaced keywords and a broadcaster name
- [x] 1.3 Machine-translate the listing into `sv`, `de-DE`, `es-ES`, `es-MX`, `fr-FR`, `fr-CA`, `pt-BR` and `ar-SA` with the terms in decision 5, and verify the check passes with Arabic reported as held
- [x] 1.4 Add `StoreListingTests` to AntennaCore, citing the requirements, and verify it passes with the CLT toolchain
- [x] 1.5 Add a store listing section to `docs/release/` (where the files are, what is held, what the owner sets in App Store Connect)

## 2. Store screenshots (PR 2)

- [x] 2.1 Open iPhone tabs by their place in the tab bar instead of their label, and rename the seed's "Tennis TV"; verify `AppJourneys` passes on a local iPhone simulator in English and in German
- [x] 2.2 Add `testStore` to `AppJourneys` and `TVJourneys`, reading `STORE_LANGUAGE` and `STORE_REGION`; verify it passes on a local iPhone and Apple TV simulator with `TEST_RUNNER_STORE_LANGUAGE=de`
- [x] 2.3 Add the `--store` mode to `scripts/export-screenshots.sh` and the per-language store pass to the `App screenshots` workflow, with the Pro Max iPhone and the `languages` input; verify `actionlint` and `shellcheck` pass
- [ ] 2.4 Run the workflow on the branch with `gh workflow run` and verify `store-screenshots` has every ready store locale with iPhone, iPad and Apple TV pictures in its language
- [x] 2.5 Update `docs/conventions.md` (Tests) for the store walk and artifact

## 3. Review (PR 3)

- [ ] 3.1 Review each language's listing for meaning, Apple's terms, length, keywords per market and claims, fix what it finds, and record the findings in design.md
- [ ] 3.2 Look at the store screenshots of each ready language for untranslated or cut-off text

## 4. Verify

- [ ] 4.1 Each requirement in `store-listing` has a test citing `store-listing/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 4.2 `/opsx:verify add-store-localization` passes, then archive the change
