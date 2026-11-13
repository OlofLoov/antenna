## MODIFIED Requirements

### Requirement: Your place is saved as you watch
The system SHALL save the position of a playing movie or episode every 30 seconds and when the user pauses or stops, skips or scrubs, the app goes to the background, or the title ends, and Continue watching and Resume SHALL show it from then on.

#### Scenario: Saving the position
- **GIVEN** a movie or episode is playing
- **WHEN** 30 seconds pass, or the user pauses or stops, the app goes to the background, or the title ends
- **THEN** the position is saved
- **AND** Continue watching and Resume show it from then on

#### Scenario: Closing right after a skip
- **GIVEN** the user skipped or scrubbed a movie to a new point
- **WHEN** they close it before the picture at the new point shows
- **THEN** Resume starts from the point they moved to
