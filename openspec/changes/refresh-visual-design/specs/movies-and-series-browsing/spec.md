## MODIFIED Requirements

### Requirement: Play a series from the next episode
The system SHALL show that a series poster is working while its episode list loads and then start the episode Play on its title page starts: the one last in progress, else the first unwatched one after the last one finished. It SHALL say when a series has no episodes or its list fails.

#### Scenario: Selecting a series
- **GIVEN** a series poster
- **WHEN** the user selects it
- **THEN** the poster shows it is working while the episode list loads
- **AND** the episode last in progress resumes, or with none in progress, the first unwatched episode after the last one finished starts

#### Scenario: No episodes or a failed list
- **GIVEN** a series has no episodes, or its episode list fails to load
- **WHEN** the user selects it
- **THEN** it says "No episodes available", or "Could not load episodes" with Try again

### Requirement: When sources fail
The system SHALL show titles from sources that loaded under a dismissible banner naming each failed source, and SHALL show "Could not load movies" with Try again for only the failed sources when no source has titles.

#### Scenario: Some sources failed
- **GIVEN** at least one Xtream source failed to load and others have titles
- **WHEN** the user opens the section
- **THEN** titles from the other sources still show under a banner naming each failed source, which the user can dismiss

#### Scenario: No source has titles
- **GIVEN** no source has titles because they failed
- **WHEN** the user opens the section
- **THEN** "Could not load movies" with Try again that asks only the failed sources again takes their place
- **AND** offline, the message says so

#### Scenario: Every source answered with nothing
- **GIVEN** every source answered with no titles
- **WHEN** the user opens the section
- **THEN** it says "Nothing here yet" with a line per source and Open Settings

#### Scenario: A login not yet arrived
- **GIVEN** a source's login has not arrived from iCloud
- **WHEN** the user opens the section
- **THEN** the source is named as waiting for it
- **AND** it is tried again when the section opens and when the app returns to the foreground
