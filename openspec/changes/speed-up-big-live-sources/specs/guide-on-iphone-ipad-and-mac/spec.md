## ADDED Requirements

### Requirement: The clock redraws only what shows the time
The system SHALL move the Guide's now marks, progress and day chips with the clock without building the list of rows again, on iPhone, iPad and Mac.

#### Scenario: The clock ticks in a large group
- **GIVEN** the Guide shows a group of 50 000 channels on iPhone
- **WHEN** the five-second clock tick passes
- **THEN** only the rows on screen and the header redraw, and the list of rows is not built again

#### Scenario: A programme ends
- **GIVEN** a row on screen whose programme ends
- **WHEN** the next tick passes
- **THEN** that row shows the next programme as on now, as before
