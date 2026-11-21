## MODIFIED Requirements

### Requirement: Progress is saved and read back
The system SHALL store one progress entry per title holding the latest saved position and length, on a device with or without a network or iCloud, and SHALL store no link, username or password with it. A new position SHALL update the title's entry rather than replace it with a new one.

#### Scenario: Save and read progress
- **GIVEN** a movie or episode from a source, on a device with or without a network or iCloud
- **WHEN** the screen saves the user's position, and later saves a new one
- **THEN** asking for that title's progress returns the latest position and length, and the store holds one entry for the title
- **AND** nothing stored holds a link, username or password

#### Scenario: A long movie
- **GIVEN** the user watches a two-hour movie, which saves the position every 30 seconds
- **WHEN** the saves reach iCloud
- **THEN** each one updates the movie's one entry, and no entry is made and deleted per save

#### Scenario: A failed save
- **GIVEN** a save that fails
- **WHEN** the screen reads progress again
- **THEN** the failed change does not show and no error reaches the screen

#### Scenario: Years of history
- **GIVEN** thousands of titles with progress
- **WHEN** time passes
- **THEN** nothing is pruned by age
