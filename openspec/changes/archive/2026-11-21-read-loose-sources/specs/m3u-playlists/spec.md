## MODIFIED Requirements

### Requirement: Standard attributes map to the channel
The system SHALL map the `#EXTINF` attributes `tvg-id`, `tvg-name`, `tvg-logo`, `group-title` and `tvg-chno` to the channel's guide id, name, logo, group and number. Attribute names SHALL be matched without regard to case, quoted and unquoted values SHALL both be read, values SHALL be kept as written without trimming, and the last duplicate attribute SHALL win. An unquoted value SHALL end at the first space. A word with no `=` among the attributes SHALL be skipped and the attributes after it read.

#### Scenario: All standard attributes present
- **GIVEN** an entry with `tvg-id="x.uk" tvg-name="X" tvg-logo="http://l/x.png" group-title="UK" tvg-chno="12"`
- **WHEN** the playlist is parsed
- **THEN** the channel has guide id "x.uk", name "X", logo `http://l/x.png`, group "UK" and number 12

#### Scenario: A channel number that is not an integer
- **GIVEN** an entry with `tvg-chno="twelve"`, or `tvg-chno="012"`
- **WHEN** the playlist is parsed
- **THEN** the first channel is produced with no number and the second with number 12

#### Scenario: A logo that is not a URL
- **GIVEN** an entry with `tvg-logo="not a url"`
- **WHEN** the playlist is parsed
- **THEN** the logo is kept as the relative link `not%20a%20url`, and an empty `tvg-logo` gives no logo

#### Scenario: Attribute reading stops at a bare word
- **GIVEN** an entry `#EXTINF:-1 catchup tvg-id="b" group-title="G",B`, or `#EXTINF:-1 tvg-name=Two Words tvg-id="x",T`
- **WHEN** the playlist is parsed
- **THEN** reading stops at the bare word only to skip it, so the first channel has guide id "b" and group "G", and the second is named "Two" with guide id "x"

## ADDED Requirements

### Requirement: Playlist text in older encodings
The system SHALL read a playlist from a link or a file as UTF-8, as UTF-16 when it starts with a UTF-16 byte-order mark, and each byte that is not part of valid UTF-8 as Windows-1252, so names saved in Latin-1 or Windows-1252 show their letters.

#### Scenario: A Latin-1 playlist link
- **GIVEN** a playlist link whose text is in Latin-1, with a channel named "München"
- **WHEN** the source loads
- **THEN** the channel is named "München"

#### Scenario: UTF-8 with a few Latin-1 names
- **GIVEN** a playlist in UTF-8 with one channel named "Zürich" in UTF-8 and one named "Málaga" in Latin-1
- **WHEN** the playlist is read
- **THEN** both names read as written

#### Scenario: A UTF-16 playlist link
- **GIVEN** a playlist link whose text is UTF-16 with a byte-order mark
- **WHEN** the source loads
- **THEN** its channels load as from the same text in UTF-8
