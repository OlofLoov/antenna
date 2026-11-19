# Tasks

## 1. Boards and change

- [x] 1.1 `iPhone-Live-Groups`, `iPhone-Live-Groups-Search` and `iPad-Live-Groups-Search`; the iPhone boards that drew the chip row draw the group button
- [x] 1.2 Proposal, delta specs, design and tasks

## 2. Group search in AntennaCore

- [ ] 2.1 `CatalogueGroup.isBuiltIn` and `GroupChoices`, matching with `ChannelFilter`
- [ ] 2.2 `GroupChoicesTests`: order, built-in groups first, locked groups last with no index, case and accents, renamed groups, no match (live-tv-on-iphone-ipad-mac/find-a-group-among-many)

## 3. iPhone button and sheet

- [ ] 3.1 `Browse.GroupButton` and `Browse.GroupChoiceRow` with previews; the group chips go, and Search keeps `Browse.Chips`
- [ ] 3.2 `LiveGroupButton` and `LiveGroupSheet`: detents, search, close, opens on the open group, locked groups ask for the passcode after the sheet closes
- [ ] 3.3 Live and the Guide on iPhone show the button in place of the chips; the Guide's rows open at the first row on another group
- [ ] 3.4 Strings in sv, de, es, fr, pt-BR and ar

## 4. iPad and Mac sidebar

- [ ] 4.1 A search field above the sidebar's groups on Live and the Guide, through `GroupChoices`, with "No groups match"

## 5. Tests

- [ ] 5.1 `pickGroup(_:)` in the UI tests; every iPhone test that tapped a chip uses it or opens the sheet
- [ ] 5.2 `-ui-testing-many-groups` and `GroupPickerUITests`: open, search, pick, and 200 groups scroll and search
- [ ] 5.3 `LiveRegularUITests` searches the sidebar's groups
- [ ] 5.4 `AppJourneys` opens the sheet to reach New

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `LiveUITests`, `GuideUITests`, `GuideRegularUITests`, `LiveRegularUITests`, `LocalizationRTLUITests`, `GroupPickerUITests` and the other classes that tapped chips pass on local simulators; screenshots checked in English and Arabic
- [ ] 6.3 `/opsx:verify` passes
