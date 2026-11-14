## ADDED Requirements

### Requirement: Tap the open tab to go back to the top
The system SHALL scroll Live's channel list, the Guide's channels, Movies and Search back to their top when the user taps the tab that is already open in the tab bar on iPhone or in a narrow iPad window. On Movies, a movie or series page open from the rows SHALL close on the same tap. The channel playing SHALL not change.

#### Scenario: Movies scrolled down
- **GIVEN** Movies is open on iPhone and scrolled down past the banner
- **WHEN** the user taps Movies in the tab bar
- **THEN** the rows scroll back to the top with the banner showing

#### Scenario: Live's list scrolled down
- **GIVEN** Live is open on iPhone with a channel playing and the list scrolled down
- **WHEN** the user taps Live in the tab bar
- **THEN** the list scrolls back to its first channel and the channel keeps playing

#### Scenario: A page open on Movies
- **GIVEN** a movie's page opened from the Movies rows on iPhone
- **WHEN** the user taps Movies in the tab bar
- **THEN** the page closes and the rows show from the top

#### Scenario: Another tab
- **GIVEN** Live is open on iPhone
- **WHEN** the user taps Movies
- **THEN** Movies opens where it was left, without scrolling
