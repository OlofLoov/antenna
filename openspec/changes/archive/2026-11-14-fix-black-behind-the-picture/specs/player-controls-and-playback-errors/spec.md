## ADDED Requirements

### Requirement: Black around the picture
The system SHALL show pure black around a picture that does not fill the player, on every platform and both playback paths, for movies, episodes and live TV.

#### Scenario: A 4:3 or wide film
- **GIVEN** a movie or episode whose picture is 4:3 or wider than the screen
- **WHEN** it plays full screen
- **THEN** the bars beside or above and below the picture are pure black

#### Scenario: A phone held upright
- **GIVEN** an iPhone held upright
- **WHEN** a movie plays
- **THEN** the screen above and below the picture is pure black

#### Scenario: Before the first frame
- **GIVEN** a movie or episode that is still opening
- **WHEN** the player shows
- **THEN** the area where the picture will be is black
