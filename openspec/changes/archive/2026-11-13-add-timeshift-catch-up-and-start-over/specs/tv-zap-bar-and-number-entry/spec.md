# Spec Delta

## MODIFIED Requirements

### Requirement: Play/pause shows the bar
The system SHALL show the bar when the user presses play/pause during full-screen live TV, or keep it five more seconds if already showing, and SHALL pause the video or play it again.

#### Scenario: Play/pause with the bar hidden or showing
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses play/pause
- **THEN** the bar shows, or stays five more seconds if it was already showing
- **AND** the video pauses, and the next press plays it again

#### Scenario: A half-typed number
- **GIVEN** the number box shows digits
- **WHEN** the user presses play/pause
- **THEN** the typed digits are dropped first and the bar shows
