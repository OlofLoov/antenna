# Tasks

## 1. Settings holds the channel

- [x] 1.1 `LiveModel.tabOpened(.settings)` holds the channel as Movies, Series and Search do
- [x] 1.2 `LiveModel.settingsSheet(shown:over:)`, called by `CompactTabs` when the sheet opens and closes, without storing Settings as the launch tab
- [x] 1.3 `ShellModel.opened(.settings)` holds the video on Apple TV
- [x] 1.4 Unit tests in `LiveHoldTests` and `ShellNavigationTests`
- [x] 1.5 UI tests: `LiveUITests.testSettingsPausesTheChannelAndClosePlaysItOn` on iPhone, `ShellUITests.testSettingsPausesTheChannelAndLivePlaysItOn` and `testSettingsOpensOverPicture` on Apple TV

## 2. Verify

- [x] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 2.2 `/opsx:verify` passes
