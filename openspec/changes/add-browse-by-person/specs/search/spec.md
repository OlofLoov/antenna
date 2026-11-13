## MODIFIED Requirements

### Requirement: Results grouped, best first
The system SHALL show results under Channels, In the guide, Movies & series and People in that order, each with its count, leave out empty sections, put names starting with the query first, order programmes by start, and highlight the matched letters.

#### Scenario: Results of every kind
- **GIVEN** results of every kind
- **WHEN** the user looks at them
- **THEN** they appear under Channels, In the guide, Movies & series and People, in that order, each with its count, and a section with nothing in it is left out
- **AND** channels whose names start with what was typed come first, programmes run in start order so what is on now leads, and titles starting with what was typed come first
- **AND** the matched letters are highlighted in every row

#### Scenario: The same programme on two channels
- **GIVEN** a programme on air on one channel and later on another
- **WHEN** it is found
- **THEN** it shows twice, on-air first

#### Scenario: Large text and VoiceOver
- **GIVEN** a large text size or VoiceOver
- **WHEN** results show
- **THEN** rows grow and highlights follow the text
- **AND** VoiceOver reads section headers as headings and each result as its section, name and second line

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user searches
- **THEN** search covers everything already loaded, and missing logos and posters get their stand-ins
