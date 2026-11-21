## MODIFIED Requirements

### Requirement: Download limits and timeouts
The system SHALL fail a guide as too large past 128 MB of gzip or 512 MB of XML on Apple TV, and 256 MB of gzip or 1000 MB of XML elsewhere, counting 1,000,000 bytes to the MB and checking unpacked XML too. A declared length over the limit SHALL fail once the first bytes show the kind of file. A download SHALL time out after 30 seconds without data or 600 seconds in all, and SHALL use no cache and no cookies.

#### Scenario: Declared length over the limit
- **GIVEN** a gzip guide whose server declares a length above the gzip limit
- **WHEN** the guide loads
- **THEN** it fails as too large after the first chunk, without reading the rest

#### Scenario: A small file that unpacks too large
- **GIVEN** a gzip guide under the gzip limit that unpacks past the XML limit
- **WHEN** the guide loads
- **THEN** it fails as too large

#### Scenario: A guide past the old limits
- **GIVEN** a 300 MB XML guide on iPhone, or a 150 MB one on Apple TV
- **WHEN** the guide loads
- **THEN** it loads instead of failing as too large

#### Scenario: Request settings
- **GIVEN** any guide download
- **WHEN** the request is sent
- **THEN** it sends no cookie and no range, reads nothing from a cache, and times out as described

## ADDED Requirements

### Requirement: A large guide keeps what the channels can use
The system SHALL keep only programmes from 7 days before the download to 14 days after it, at most 1,000,000 programmes and 64 MB of their text on Apple TV and 3,000,000 and 192 MB elsewhere. Guide ids the source's channels name SHALL fill the caps; other ids SHALL stop at half of either cap.

#### Scenario: Old and far-off programmes
- **GIVEN** a guide with programmes from 10 days ago to 20 days ahead
- **WHEN** the guide loads
- **THEN** only programmes from 7 days back to 14 days ahead are available

#### Scenario: A guide for every country
- **GIVEN** a guide with more programmes than the cap, most of them for channels the source does not have
- **WHEN** the guide loads
- **THEN** the source's channels that name a guide id have their programmes, up to the cap
- **AND** programmes for other guide ids fill at most half the cap, so channels matched by name can still find some

#### Scenario: A guide under the caps
- **GIVEN** a guide that fits within the caps
- **WHEN** the guide loads
- **THEN** every programme in the window is kept, for every guide id, and the guide entry search lists every entry with its programmes
