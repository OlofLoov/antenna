## 1. Parser

- [ ] 1.1 Add a test named `m3u-playlists/leading-byte-order-mark-is-ignored` in `Packages/AntennaCore/Tests/AntennaCoreTests/M3UParserTests.swift` covering the three spec scenarios (header, first channel with no header, mark only). Verify: it fails on the current parser
- [ ] 1.2 Drop one leading `U+FEFF` at the start of `M3UParser.parse(_:)` in `Packages/AntennaCore/Sources/AntennaCore/Parsers/M3UParser.swift`. Verify: `swift test --package-path Packages/AntennaCore` passes, including 1.1 and the existing M3U tests

## 2. Verify

- [ ] 2.1 Every requirement this change adds has a test citing `m3u-playlists/<requirement-slug>`. Verify: `scripts/check-spec-refs.sh` passes
- [ ] 2.2 `/opsx:verify ignore-m3u-byte-order-mark` passes and `openspec validate ignore-m3u-byte-order-mark --strict` reports the change valid

## Workflow follow-up

- Archive the change with `/opsx:archive` in the same pull request.
