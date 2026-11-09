## Context

The app downloads a playlist, turns the bytes into text with `String(decoding:as: UTF8.self)`, which keeps a leading byte-order mark as the scalar `U+FEFF`, and hands the text to `M3UParser.parse(_:)`. The parser splits on newlines and trims each line with `.whitespaces`, which does not include `U+FEFF`. The first line then matches neither `#EXTM3U` nor `#EXTINF:` nor `#`, so it is treated as a URL line with no pending entry and dropped.

## Goals / Non-Goals

**Goals:**
- Fix it in AntennaCore, so every caller of the parser gets the fix, today and when local file import lands.
- Keep the per-line loop unchanged so the "Large playlists stay fast" requirement is not at risk.

**Non-Goals:**
- Changing how the app decodes bytes into text.

## Decisions

### Drop one leading U+FEFF in `parse(_:)` before splitting

If the first unicode scalar of the input is `U+FEFF`, parse the text after it. Nothing else changes.

Options considered:
- Add `U+FEFF` to the trim set for every line. Rejected: it costs a check on every line of a 50,000-entry playlist and would also hide marks in the middle of a file, which the proposal leaves out of scope.
- Strip the mark in the app before calling the parser. Rejected: parsing logic belongs in AntennaCore, and the next caller (local file import) would have to remember to do it too.
- Strip at the start of the input (chosen): one check per parse, in the one place every caller goes through.

Check the unicode scalar, not the first `Character`, so the test does not depend on how the mark clusters with the text after it.

## Risks / Trade-offs

- [A playlist with two leading marks] → Only the first is dropped and the second still breaks the first line. No provider is known to do this; it stays out of scope.
