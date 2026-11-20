# Tasks

## 1. Change and boards

- [x] 1.1 Proposal, delta specs, design and tasks
- [x] 1.2 `iPhone-Settings-Appearance`, `iPhone-Settings-AppIcon`, `iPad-Settings-Appearance`, `Mac-Settings-Appearance`, `TV-Settings-Appearance`, `TV-Settings-Accent`, `iPhone-Profiles-Edit-Accent`, `TV-Profiles-Edit-Accent`

## 2. Accent per profile

- [x] 2.1 `ProfileAccent` and `Contrast` in AntennaCore; `Profile.accent`, Blue by default and for unknown values; `ProfileAccentTests` for the table in design.md (design-system/one-accent-color-per-profile)
- [x] 2.2 `ProfileRecord.accent`, `ProfileStore.add`, `edit` and `setAccent` (profiles/profiles-sync-between-devices)
- [x] 2.3 The `accent` environment value from `ProfileGate`, the tint on iPhone, iPad and Mac; every `Palette.accent` reader moves to it and `Palette.accent` goes; `scripts/check-rules.sh` guards it
- [x] 2.4 `SwatchChoiceRow` and `SwatchChoiceList`; `AppearanceSection` with Accent in Settings on every platform (sources-and-settings/pick-the-accent-for-your-profile)
- [x] 2.5 Accent swatches in `ProfileEditSheet` and the Apple TV `ProfileEdit` (profiles/adding-a-profile, profiles/editing-and-deleting-a-profile)
- [x] 2.6 Strings in every catalog language
- [x] 2.7 UI tests on iPhone and Apple TV: picking an accent changes the Accent row's value, which reads the environment; a journey step for Appearance

## 3. Alternate app icons

- [x] 3.1 `AppIconChoice` in AntennaCore; `scripts/render-icons.sh` writes the six `.icon` files and Apple TV image stacks; `project.yml` names them for iOS and tvOS; `AppIconTests` (app-release/alternate-icons-keep-the-mark)
- [x] 3.2 The App icon row and page on iPhone, iPad and Apple TV, with `setAlternateIconName`; none on the Mac (sources-and-settings/pick-the-app-icon-on-this-device)
- [x] 3.3 Strings in every catalog language
- [x] 3.4 UI tests on iPhone and Apple TV: the App icon page lists the seven icons

## 4. Verify

- [x] 4.1 Each requirement this change adds or modifies has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 `/opsx:verify` passes, then archive
