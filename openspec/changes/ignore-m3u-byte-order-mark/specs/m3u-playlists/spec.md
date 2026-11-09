## ADDED Requirements

### Requirement: Leading byte-order mark is ignored
The system SHALL ignore a byte-order mark at the very start of a playlist and parse the rest exactly as if it were not there.

#### Scenario: Header after a byte-order mark
- **GIVEN** a playlist that starts with a byte-order mark followed by `#EXTM3U url-tvg="http://a/epg.xml"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://a/epg.xml`, the same as without the mark

#### Scenario: First channel after a byte-order mark
- **GIVEN** a playlist with no header that starts with a byte-order mark followed by an `#EXTINF` line and its URL
- **WHEN** the playlist is parsed
- **THEN** that first channel is produced with its title and URL

#### Scenario: Only a byte-order mark
- **GIVEN** a playlist that holds only a byte-order mark
- **WHEN** the playlist is parsed
- **THEN** the result has zero channels and zero guide links
