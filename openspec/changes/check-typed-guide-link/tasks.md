# Tasks

## 1. Check the link before saving (PR 1)

- [x] 1.1 Add `GuideLinkProbe` and the four refusal messages, translated, to AntennaCore
- [x] 1.2 Test each answer in the decision table through a stubbed network, citing `guide-sources-and-channel-mapping/add-a-guide-link`
- [x] 1.3 Run the probe in `GuideSourcesModel.add`, show "Checking…" on Save, and stop the check on Cancel
- [x] 1.4 Add the `-ui-testing-guide-sources` stub and a `GuideSourcesUITests` case for a refused web page; run the class on a local iPhone simulator
- [x] 1.5 Build the tvOS app to check the Apple TV form

## 2. Verify

- [x] 2.1 Each changed requirement has a test citing it, and `scripts/check-spec-refs.sh` passes
- [x] 2.2 `/opsx:verify check-typed-guide-link` passes, then archive the change
