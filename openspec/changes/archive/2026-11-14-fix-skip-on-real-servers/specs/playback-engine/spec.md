## MODIFIED Requirements

### Requirement: Films start where you left off, skip, and end
The system SHALL start a film at a saved time within its length, land a skip within a second, finish a film on a skip past the end and fetch nothing more until replay, and SHALL ignore saved times and refuse skips for live TV and films whose server cannot skip. A server that sends part of a film when asked SHALL count as able to skip.

#### Scenario: Opening at a saved time
- **GIVEN** a film of known length and a saved time
- **WHEN** it is opened
- **THEN** it starts at the saved time, or at the beginning if the saved time is past the end

#### Scenario: Skipping and ending
- **GIVEN** a film is playing
- **WHEN** the user skips to another time, past the end, or it plays to the end
- **THEN** a skip lands within a second of the target and a skip past the end finishes the film
- **AND** a finished film fetches nothing more until play starts it again from the beginning

#### Scenario: A server that skips without saying so
- **GIVEN** a film whose server sends part of the file when asked, but never says it accepts ranges and gives no length unless asked for a part
- **WHEN** the user skips
- **THEN** the film moves to the new time

#### Scenario: A film behind a redirect
- **GIVEN** a film whose address redirects to another server that takes ranges
- **WHEN** the user skips
- **THEN** the film moves to the new time

#### Scenario: A skip while a skip is on its way
- **GIVEN** a film is reopening at a skipped time
- **WHEN** the user skips again before the picture comes back
- **THEN** the film moves to the second time and the skip is not refused

#### Scenario: Live TV and films that cannot skip
- **GIVEN** live TV, or a film whose server cannot skip
- **WHEN** it is opened at a saved time or asked to skip
- **THEN** it ignores the saved time and refuses to skip
- **AND** the player knows the film cannot skip from the moment it starts
- **AND** such a film starts again from the beginning after a pause

#### Scenario: A film that cannot skip in Apple's player
- **GIVEN** a film whose server cannot skip, in a container Apple's player handles
- **WHEN** it is asked to play
- **THEN** it fails as "stream could not be read"
