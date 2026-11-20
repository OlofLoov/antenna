# Tasks

## 1. Boards and change

- [x] 1.1 `iPhone-Live-Groups`, `iPhone-Live-Groups-Search` and `iPad-Live-Groups-Search`; the iPhone boards that drew the chip row draw the group button
- [x] 1.2 Proposal, delta specs, design and tasks

## 2. Group search in AntennaCore

- [x] 2.1 `CatalogueGroup.isBuiltIn` and `GroupChoices`, matching with `ChannelFilter`
- [x] 2.2 `GroupChoicesTests`: order, built-in groups first, locked groups last with no index, case and accents, renamed groups, no match (live-tv-on-iphone-ipad-mac/find-a-group-among-many)

## 3. iPhone button and sheet

- [x] 3.1 `Browse.GroupButton` and `Browse.GroupChoiceRow` with previews; the group chips go, and Search keeps `Browse.Chips`
- [x] 3.2 `LiveGroupButton` and `LiveGroupSheet`: detents, search, close, opens on the open group, locked groups ask for the passcode after the sheet closes
- [x] 3.3 Live and the Guide on iPhone show the button in place of the chips; the Guide's rows open at the first row on another group
- [x] 3.4 Strings in sv, de, es, fr, pt-BR and ar

## 4. iPad and Mac sidebar

- [x] 4.1 A search field above the sidebar's groups on Live and the Guide, through `GroupChoices`, with "No groups match"

## 5. Tests

- [x] 5.1 `pickGroup(_:)` in the UI tests; every iPhone test that tapped a chip uses it or opens the sheet
- [x] 5.2 `-ui-testing-many-groups` and `GroupPickerUITests`: open, search, pick, and 200 groups scroll and search
- [x] 5.3 `LiveRegularUITests` searches the sidebar's groups
- [x] 5.4 `AppJourneys` opens the sheet to reach New

## 6. Verify

- [x] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 6.2 `LiveUITests`, `GuideUITests`, `GuideRegularUITests`, `LiveRegularUITests`, `LocalizationRTLUITests`, `GroupPickerUITests` and the other classes that tapped chips pass on local simulators; screenshots checked in English and Arabic
- [x] 6.3 `/opsx:verify` passes
