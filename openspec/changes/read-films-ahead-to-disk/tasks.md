# Tasks

## 1. Bound the connection

- [x] 1.1 `HTTPByteStream` closes a stream that takes ranges at `overflowLimit` unread
- [x] 1.2 `SeekableSource` opens a dropped connection again at its position
- [x] 1.3 `FixtureServer` serves generated bodies of any length, and a test reads one slower than it arrives

## 2. Read films ahead to disk

- [x] 2.1 `FilmReadAhead` and `FilmReader`: the ring file, the download thread, reads outside the ring
- [x] 2.2 `DemuxEngine` uses it for loads marked as films, keeps it over skips and reconnects, deletes it on close
- [x] 2.3 Tests for the ring's bytes, skips within and outside it, too little space, and the engine's skip with no request

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
