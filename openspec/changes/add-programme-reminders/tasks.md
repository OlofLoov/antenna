# Tasks

## 1. Amendments to other changes

- [x] 1.1 Amend the guide grid, channel overlay, search, settings and phone guide changes with the Remind me placements, and verify each names the button or row

## 2. Reminder record and logic in AntennaCore

- [x] 2.1 Add the synced reminder record with its identity and the duplicate merge, and verify tests that duplicates show and deliver once and removal deletes every copy
- [x] 2.2 Add the schedule with lead time, the 64-notification window and the "Starts at" and "Starts now" text, and verify tests for each lead time and a reminder set inside the lead time
- [x] 2.3 Add guide matching for moved, dropped and returning programmes, and verify tests for each rule including the 6-hour limit and a guide that does not reach the start
- [x] 2.4 Add the hide-then-delete cleanup for ended programmes and the removal on source deletion, and verify tests with a fast clock

## 3. Setting and removing reminders

- [ ] 3.1 Add Remind me to the Apple TV guide panel and overlay next rows, and verify UI tests that only future programmes show it and that setting keeps focus in place
- [ ] 3.2 Add the bell to future guide results in Search on iPhone, iPad and Mac, and verify UI tests for set and unset
- [ ] 3.3 Remove reminders from the toggle and the list with confirmation on Apple TV and Mac, and verify an integration test that nothing is delivered afterwards

## 4. Delivery

- [ ] 4.1 Schedule notifications on iPhone, iPad and Mac and ask permission after the first reminder is saved, and verify integration tests for the prompt timing and the delivered text
- [ ] 4.2 Add the in-app banner on every device, the missed-reminder banner on return, and the 20-second timeout, and verify UI tests including Menu on Apple TV
- [ ] 4.3 Make Watch and a notification tap open Live and play the channel, and verify UI tests for a channel outside the current group, one already playing, a missing channel and the locked paywall

## 5. Reminders page

- [ ] 5.1 Add the Reminders page with the list, header count, empty state and moved or dropped notes, and verify UI tests
- [ ] 5.2 Add the per-device lead-time picker and the notice when the device cannot notify, and verify UI tests on iPhone and Apple TV
- [ ] 5.3 Set a reminder on a second device and confirm it appears in the list on the first, on hardware

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
