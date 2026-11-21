## 1. Xtream categories

- [x] 1.1 Category calls drop rows without a usable id or name and read a number name as text, with a core test
- [x] 1.2 `liveLoad()`, `vodLoad()` and `seriesLoad()` load without categories when the category call fails; `ShelfLoader` and `SourceSetup` use them or the same rule, with a core test
- [x] 1.3 `epg_channel_id` sent as a number is read as text, with a core test

## 2. Encodings

- [ ] 2.1 `TextEncoding` holds the UTF-8 check and the Windows-1252 table; `XtreamBody` uses it
- [ ] 2.2 `TextEncoding.text` reads the marks, UTF-8 and Windows-1252 per byte; `PlaylistImport`, `SourceLoader` and `SourceConnector` call it, with a core test
- [ ] 2.3 `XMLEntitySanitizer` reads invalid bytes as Windows-1252 in a guide with no declared encoding or UTF-8, with a core test for both parse paths

## 3. Guide matching

- [ ] 3.1 `XMLTVParser` keeps stopless programmes, ending each at the next start on its channel or after two hours, with a core test
- [ ] 3.2 `SourceGuide.slots(for:)` and `GuideIndex.located` retry a missed id ignoring case, exact matches first across layers, with a core test

## 4. M3U attributes

- [ ] 4.1 Both attribute readers skip a bare word and read on, with a core test

## 5. Verify

- [ ] 5.1 Each requirement this change adds or modifies has a test citing `<capability>/<requirement-slug>`
- [ ] 5.2 /opsx:verify passes
