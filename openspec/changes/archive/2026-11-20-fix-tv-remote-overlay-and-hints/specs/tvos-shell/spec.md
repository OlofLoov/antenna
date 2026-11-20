## ADDED Requirements

### Requirement: One press does one thing
The system SHALL act once on each press of the Siri Remote. On a control where a click of select does one thing and holding it does another, the release that ends a hold SHALL NOT also count as a click.

#### Scenario: Holding select on the picture
- **GIVEN** a channel playing full screen
- **WHEN** the user holds select until the info panel opens and lets go
- **THEN** the info panel stays open and the channel list does not open

#### Scenario: Holding select on a multi-view tile
- **GIVEN** multi-view with a tile highlighted
- **WHEN** the user holds select until the tile's actions open and lets go
- **THEN** the actions stay open and the picker does not open

#### Scenario: Holding select on an error
- **GIVEN** the error in place of the picture with Try again highlighted
- **WHEN** the user holds select and lets go
- **THEN** the channel loads again once

#### Scenario: Holding select in a movie
- **GIVEN** a movie or episode playing
- **WHEN** the user holds select until Audio and Subtitles open and lets go
- **THEN** the panel stays open and the movie neither pauses nor plays

#### Scenario: A click after a hold
- **GIVEN** the user held select a moment ago
- **WHEN** the user clicks select again after letting go
- **THEN** the click does what a click does
