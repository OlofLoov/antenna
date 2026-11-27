## ADDED Requirements

### Requirement: The account says whether HLS is offered
The system SHALL keep linking an Xtream source's live channels as MPEG-TS, and SHALL count the source as offering HLS when the account's allowed output formats list `m3u8`, when the panel sends no list or an empty one, and when the account call fails, and as not offering it when the list names formats without `m3u8`. The list SHALL be read as a list of names or as one comma-separated text, without regard to case or surrounding spaces.

#### Scenario: The account allows HLS
- **GIVEN** an account whose allowed output formats are `m3u8`, `ts` and `rtmp`
- **WHEN** the provider's channels are loaded
- **THEN** stream 42's playable link ends in `42.ts` and the source offers HLS

#### Scenario: The account allows only MPEG-TS
- **GIVEN** an account whose allowed output formats are `ts` alone
- **WHEN** the provider's channels are loaded
- **THEN** stream 42's playable link ends in `42.ts` and the source does not offer HLS

#### Scenario: The panel does not say
- **GIVEN** an account with no allowed output formats, an empty list, or an account call that fails
- **WHEN** the provider's channels are loaded
- **THEN** the source offers HLS, and a channel whose HLS does not start says so when it goes to AirPlay

#### Scenario: Loose shapes
- **GIVEN** allowed output formats sent as the text "ts, M3U8", or as something that is neither a list nor text
- **WHEN** the account info is decoded
- **THEN** the first offers HLS and the second counts as no list
