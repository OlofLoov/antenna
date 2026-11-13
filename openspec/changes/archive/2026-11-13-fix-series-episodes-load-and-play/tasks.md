# Tasks

## 1. Decoding

- [x] 1.1 `XtreamBody.readable` cleans a byte-order mark, a PHP notice, trailing text, non-UTF-8 bytes and control characters, and every Xtream decoder runs it first
- [x] 1.2 `episodes` as an array of season arrays, and a season keyed by episode number or holding one episode, give their episodes
- [x] 1.3 Fixtures `series_info_season_arrays.json`, `series_info_episodes_by_number.json` and `series_info_php_notice.txt` with tests

## 2. Playback

- [x] 2.1 `StreamSniff` tells Matroska and AVI; Apple's player hands MPEG-TS, Matroska and AVI to the demuxer through `EngineHandoff.toDemuxer`
- [x] 2.2 `RoutedEngine` loads the address on the demuxer after the handoff, with no failure shown

## 3. App

- [x] 3.1 A panel unreachable while offline shows the offline message on the title page
- [x] 3.2 Failed title loads, episode lists and episode addresses log a reason with no address, login or body
- [x] 3.3 A playlist series missing from the kept load asks the playlist again once

## 4. Verify

- [x] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 `/opsx:verify` passes
