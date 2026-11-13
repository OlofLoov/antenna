# Tasks

## 1. Panel links in AntennaCore

- [x] 1.1 Add `XtreamPanelLink` with the server, login, add-form fields and the live id map, and verify core tests citing `source-management/xtream-panel-playlist-links-are-recognized`
- [x] 1.2 Fall back to the panel's guide for a panel playlist in `GuideURLResolver`, `GuideList` and `GuideEngine`, and verify core tests citing `guide-data/a-panel-playlist-falls-back-to-the-panel-s-guide`

## 2. The offer in the app

- [x] 2.1 Draw `iPhone-Onboard-2-XtreamLink`, `TV-Onboard-3-XtreamLink` and `iPhone-Settings-Detail-XtreamLink`
- [x] 2.2 Show the offer in the add form on iPhone, iPad, Mac and Apple TV, with previews, and verify a model test citing `source-management/the-add-form-offers-xtream-for-a-panel-link`
- [x] 2.3 Switch a panel playlist to Xtream from its details, rewriting favorites and own-group channels, and verify integration tests citing `source-management/a-playlist-source-switches-to-xtream-in-place`
- [x] 2.4 Count the panel guide in the refresher's guide status
- [x] 2.5 Run the onboarding and Settings UI test classes on local simulators

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
