## 1. Headers from the playlist

- [x] 1.1 `StreamHeaders` with names only in `description` and `dump`, and line breaks refused, with a core test
- [x] 1.2 `M3UParser` reads `#EXTVLCOPT`, `#EXTHTTP`, `#KODIPROP`, the `user-agent` attribute and the `|` suffix into `Channel.headers`, with a core test
- [x] 1.3 `StreamHeaderBook` by address and by server origin; `SourceLoader` and `SourceSetup` register each load, with a core test
- [x] 1.4 `StreamProbe`, `HTTPByteStream` and `AVPlayerEngine` send the headers, with a core test on the probe

## 2. A User-Agent per source

- [x] 2.1 `SourceRecord.userAgent` and `SourceDescriptor.userAgent`, optional and synced
- [x] 2.2 `XtreamClient(userAgent:)` and the playlist download send it; the book gets it by server origin, with a core test
- [x] 2.3 The source details on iPhone, iPad, Mac and Apple TV edit it, with the boards updated and a UI test

## 3. Verify

- [x] 3.1 Each requirement this change adds has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 /opsx:verify passes
