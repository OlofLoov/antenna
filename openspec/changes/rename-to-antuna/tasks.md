## 1. Rename

- [x] 1.1 Rename the display names, the Mac product name and the Info.plist text in `project.yml` and `InfoPlist.xcstrings`
- [x] 1.2 Rename the app in Swift strings, previews, comments and both String Catalogs in every language, and run `scripts/sync-strings.sh` and `scripts/check-translations.sh`
- [x] 1.3 Move every antenna.code-crave.se address to antuna.app (`add-aws-hosting` group 5) and rename the review playlist
- [x] 1.4 Rename the site, the setup page, the store listing, docs, README, CLAUDE.md, the C4 diagrams, the boards' text, specs and active changes, and `antenna-website` to `antuna-website`
- [x] 1.5 Replace `<antenna-domain>` in the four active changes and record the owner's pick in `add-aws-hosting`
- [x] 1.6 Rename the Terraform root, buckets, roles, names, tags, the domain variable and the support repository and GitHub App names
- [x] 1.7 Add tests citing `app-release/the-app-is-called-antuna-wherever-a-person-sees-it` and `app-release/the-app-store-addresses-are-on-antuna-s-domain`

## 2. Verify

- [x] 2.1 Core tests in English and German, `swift format`, `swiftlint`, `check-rules`, `check-spec-refs`, `check-translations`, `sync-strings --check`, `openspec validate --all --strict`, `actionlint`, the site's tests, Terraform `fmt`, `validate` and `test`, and the iOS and tvOS builds pass
- [x] 2.2 A grep for "antenna" outside the kept identifiers and the archive finds only what design.md decision 1 keeps
- [x] 2.3 The app shows Antuna on an iPhone simulator, and `SetupUITests` and `SendLoginsUITests` pass there
- [x] 2.4 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 2.5 `/opsx:verify` passes
