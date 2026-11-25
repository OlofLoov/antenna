## ADDED Requirements

### Requirement: A poster opens its page
The system SHALL open a title's page when the user selects its poster in a row, a grid or My list, on iPhone, iPad, Mac and Apple TV, for a movie as for a series, without starting playback. A Continue watching card SHALL play straight away, and so SHALL a movie in Recently watched. A poster's menu SHALL offer More info only where selecting the poster plays, and SHALL offer Add to My list or Remove from My list everywhere.

#### Scenario: Selecting a movie poster
- **GIVEN** a movie in Recently added, a genre row, My list or a grid
- **WHEN** the user taps or clicks its poster, or selects it with the remote
- **THEN** the movie's page opens and nothing starts playing

#### Scenario: Continue watching plays
- **GIVEN** a movie or series in Continue watching
- **WHEN** the user selects its card
- **THEN** it plays straight away, the movie from where it stopped and the series from its next episode

#### Scenario: A movie in Recently watched
- **GIVEN** a movie in Recently watched
- **WHEN** the user selects it
- **THEN** it plays straight away
- **AND** a series in Recently watched opens its page

#### Scenario: The poster's menu
- **GIVEN** a movie poster outside Continue watching and Recently watched
- **WHEN** the user long-presses it, or holds Select on Apple TV
- **THEN** the menu offers Add to My list or Remove from My list and no More info
- **AND** on a Continue watching card or a movie in Recently watched the menu offers More info and My list

#### Scenario: Back to the poster on Apple TV
- **GIVEN** the viewer opened a movie's page from a poster deep in a row on Apple TV
- **WHEN** they press Menu on the page
- **THEN** the same poster has the highlight and its preview shows

## MODIFIED Requirements

### Requirement: Resume where you left off
The system SHALL start a movie the user stopped part-way through within five seconds of where they stopped, from any place it can be played, and SHALL start a movie barely started or already finished from the beginning.

#### Scenario: Resuming a movie
- **GIVEN** a movie the user stopped part-way through
- **WHEN** the user plays it from the banner, Continue watching, Recently watched or its page
- **THEN** it starts within five seconds of where they stopped

#### Scenario: Barely started or finished
- **GIVEN** a movie barely started or already finished
- **WHEN** the user plays it
- **THEN** it starts from the beginning

#### Scenario: Leaving a movie
- **GIVEN** a movie is playing
- **WHEN** the user leaves it
- **THEN** they return to the card, button or page that started it
- **AND** the last live channel starts again the next time they open Live

### Requirement: Play a series from the next episode
The system SHALL show that a series' Continue watching card is working while its episode list loads and then start the episode Play on its title page starts: the one last in progress, else the first unwatched one after the last one finished. It SHALL say when a series has no episodes or its list fails.

#### Scenario: Selecting a series
- **GIVEN** a series in Continue watching
- **WHEN** the user selects its card
- **THEN** the card shows it is working while the episode list loads
- **AND** the episode last in progress resumes, or with none in progress, the first unwatched episode after the last one finished starts

#### Scenario: No episodes or a failed list
- **GIVEN** a series has no episodes, or its episode list fails to load
- **WHEN** the user plays it from its card or its page
- **THEN** it says "No episodes available", or "Could not load episodes" with Try again
