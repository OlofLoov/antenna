## 1. Proposal and boards

- [x] 1.1 Write the proposal, the delta specs, design.md and tasks.md
- [x] 1.2 Give the display headings on the boards design.md lists the rounded face

## 2. App

- [ ] 2.1 Give `TypeScale.Step` a design, round the top two steps of each platform, add `step(for:in:)`, `design(of:in:)` and `boardStyle(_ style:weight:)`, and drop `boardStyle`'s `design:` parameter
- [ ] 2.2 Move the call sites design.md decision 2 lists to `boardStyle`, and show the rounded steps in the type scale preview, with an Arabic one
- [ ] 2.3 Add the `check-rules.sh` check for font designs and custom fonts
- [ ] 2.4 Pin the rounded steps in `TypeScaleTests`, citing `design-system/display-headings-are-rounded`, and update the type table in the design-system reference

## 3. Website

- [ ] 3.1 Set the rounded stack on `h1, h2` in `site.css`
- [ ] 3.2 Add a site test citing `antuna-website/headings-are-rounded-like-the-wordmark`

## 4. Verify

- [ ] 4.1 Core tests in English and Arabic, `swift format`, `swiftlint`, `check-rules`, `check-spec-refs`, `check-translations`, `openspec validate --all --strict`, the site's lint, check, build and tests, the iOS and tvOS builds, and the UI test classes for the paywall and onboarding on a local simulator
- [ ] 4.2 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.3 `/opsx:verify` passes
