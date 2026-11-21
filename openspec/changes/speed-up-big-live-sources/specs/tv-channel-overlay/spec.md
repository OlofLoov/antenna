## ADDED Requirements

### Requirement: A large group stays light
The system SHALL move each channel row on to the next programme at the minute it starts without walking every row of the group.

#### Scenario: The minute passes in a large group
- **GIVEN** the overlay shows a group of 50 000 channels
- **WHEN** a minute passes
- **THEN** the rows on screen show the programme on now, and the rows off screen are not built
