## MODIFIED Requirements

### Requirement: Results grouped, best first
The system SHALL show results under Channels, In the guide, Movies & series and People in that order, each with its count, leave out empty sections, put names starting with the query first, order programmes by start, and highlight the matched letters. Each result SHALL look as the rest of the app shows that kind of thing.

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
- **THEN** the menu offers what a poster in a Movies or Series row offers: Add to My list or Remove from My list

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

### Requirement: Pick a channel or title to watch
The system SHALL play a picked channel full screen on Apple TV and in Live elsewhere, switching to All channels when it is outside the current group and keeping the search for later, and SHALL open a picked movie's or series' page, as a poster in the Movies or Series section does. On Apple TV, coming back to Search SHALL put focus on the result the user picked.

#### Scenario: Picking a channel
- **GIVEN** a channel in the results
- **WHEN** the user picks it
- **THEN** it starts playing, full screen on Apple TV and in Live elsewhere
- **AND** the current group becomes All channels if the channel is not in it
- **AND** the search is kept for when the user comes back

#### Scenario: Picking a movie or series
- **GIVEN** a movie or series in the results
- **WHEN** the user picks it
- **THEN** its page opens over Search and nothing starts playing

#### Scenario: Back on the result on Apple TV
- **GIVEN** a channel, movie, series or person the user picked in Search on Apple TV
- **WHEN** they come back with Menu from the title's or person's page, or swipe down from the tab bar onto Search after the channel played
- **THEN** the result they picked has focus, with the query and results as they left them
