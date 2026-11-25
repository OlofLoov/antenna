## 1. Proposal and boards

- [x] 1.1 Write the proposal, the delta specs, design.md and tasks.md
- [x] 1.2 Draw `Brand-Mark.dc.html` and update the boards design.md lists

## 2. Mark and motions

- [x] 2.1 Add `MarkGeometry`, `MarkPath` and the arc conversion in AntennaCore, with tests citing `design-system/the-antuna-mark` and `design-system/the-mark-s-colors`
- [x] 2.2 Add `CubicBezier`, `MarkPose` and `MarkMotion` with the tracks from design.md decision 2, with tests citing `design-system/the-mark-moves-at-three-moments` and `design-system/reduce-motion-stills-the-mark`
- [x] 2.3 Add `BrandMark` (`Word`, `Letter`, `Drawing`, `Ink`, `Clock`) with previews of each motion at fixed times, on dark and light, and with Reduce Motion
- [x] 2.4 Play Hello on both welcome screens, Tuning on the splash and both loading screens, Got it on the restored paywall, and the still wordmark in the iPad and Mac sidebar; delete `AntennaMark` and `Paywall.mark`, and move `AppIconTile` to `Components/Brand/`
- [x] 2.5 Assert each placement's identifier and moment in the onboarding, paywall and loading UI tests, citing their requirements, and run those classes on a local simulator

## 3. Icons

- [x] 3.1 Replace the sources in `design/icon/` and update `scripts/render-icons.sh` for the glow, letter and tips layers, the Apple TV layers, Top Shelf and the alternates; run it
- [x] 3.2 Change `AppIconChoice` to ink, tip and ground, replace Teal with Blue in it, `project.yml` and the titles, and draw `AppIconTile` with `BrandMark.Letter`
- [x] 3.3 Update `AppIconTests` and the appearance UI tests, citing the modified `app-release` and `sources-and-settings` requirements

## 4. Website

- [x] 4.1 Put the wordmark in the site header with the `--tip` color for both modes, and replace the favicon
- [x] 4.2 Add a site test citing `antuna-website/the-header-shows-the-wordmark`

## 5. Verify

- [x] 5.1 Core tests in English and German, `swift format`, `swiftlint`, `check-rules`, `check-spec-refs`, `check-translations`, `sync-strings --check`, `openspec validate --all --strict`, the site's lint, check, build and tests, and the iOS and tvOS builds pass
- [x] 5.2 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 5.3 `/opsx:verify` passes
