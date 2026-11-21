## MODIFIED Requirements

### Requirement: Results grouped, best first
The system SHALL show results under Channels, In the guide, Movies & series and People in that order, each with its count, leave out empty sections, put names starting with the query first, order programmes by start, and highlight the matched letters. Each kind of result SHALL look the way the rest of the app shows it: a channel as a row of the channel list, a programme as the guide shows programmes, a movie or series as its poster in Movies or Series with the same menu, and a person as a name in a title's cast.

#### Scenario: Results of every kind
- **GIVEN** results of every kind
- **WHEN** the user looks at them
- **THEN** they appear under Channels, In the guide, Movies & series and People, in that order, each with its count, and a section with nothing in it is left out
- **AND** channels whose names start with what was typed come first, programmes run in start order so what is on now leads, and titles starting with what was typed come first
- **AND** the matched letters are highlighted in every row

#### Scenario: Results look like the rest of the app
- **GIVEN** results of every kind on iPhone, iPad, Mac or Apple TV
- **WHEN** the user looks at them
- **THEN** a channel row is as tall as a row in the channel list and shows its number after the name, what is on now and its progress
- **AND** a poster is the size and shape of a poster in Movies, with its name under it and SERIES on a series
- **AND** a person is a chip like the names under a title's Cast and crew

#### Scenario: A poster's menu in Search
- **GIVEN** a movie or series in the results
- **WHEN** the user long-presses its poster, or holds Select on Apple TV
- **THEN** the menu offers what the poster offers in Movies or Series: More info on a movie, and Add to My list or Remove from My list

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
