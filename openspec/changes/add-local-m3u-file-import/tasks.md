# Tasks

## 1. Storage

- [ ] 1.1 Add the file source kind with its contents, file name and import date to the source record, and verify a migration test with an existing store

## 2. Import checks and logins in AntennaCore

- [ ] 2.1 Add the import check for size, decoding, single stream, link list and channel list, and verify a test per outcome including a web page named `.m3u`
- [ ] 2.2 Add the summary of channels, groups, guide link and skipped entries, and verify it against the 412-channel fixture
- [ ] 2.3 Strip logins in the query, Xtream path and `user:pass@host` forms into one Keychain item per source and restore them on load, and verify tests that the stored text holds no login

## 3. Import sheet and ways in

- [ ] 3.1 Add the import sheet with reading state, summary, name, guide link and Import, and verify UI tests for a good file, a too-large file and each refused kind
- [ ] 3.2 Add "Import a file" in Sources and Settings, share and Open With handling, and the onboarding link, and verify UI tests for each way in
- [ ] 3.3 Save the source and load its channels without a relaunch or a playlist request, and verify an integration test that counts match the summary

## 4. Re-import and delete

- [ ] 4.1 Add Re-import onto the same record and the "imported before" choice, and verify an integration test that favorites survive
- [ ] 4.2 Delete a file source with its contents, guide and login, and verify an integration test

## 5. Sync and other devices

- [ ] 5.1 Show waiting for iCloud and waiting for login for a file source on Apple TV and other devices, and verify on an Apple TV that channels arrive and play
- [ ] 5.2 Take a file source's guide links from its header, and verify a guide data test
- [ ] 5.3 Register no import control or document type on Apple TV, and verify a UI test

## 6. Drag and drop

- [ ] 6.1 Add the drop target on iPad and Mac for Settings, welcome and the add-source sheet, and verify UI tests for a file and for non-file drags

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
