## MODIFIED Requirements

### Requirement: Filter channels by typing
The system SHALL narrow the guide to the group's channels whose name matches or whose number starts with the typed digits, after each letter typed, on iPhone, iPad and Mac.

#### Scenario: Type in the filter
- **GIVEN** a group of 42 channels on iPad or Mac
- **WHEN** the user types in the filter field, or presses Command-F and types
- **THEN** after each letter only the group's channels whose name matches, or whose number starts with the digits typed, remain, matched as in Search, with the header count following

#### Scenario: Clear the filter
- **GIVEN** a filtered guide
- **WHEN** the user clears the field, picks another group, or opens the guide at a programme
- **THEN** the whole group comes back

#### Scenario: No filter on iPhone
- **WHEN** the user opens the Guide on iPhone
- **THEN** there is no filter field until they pull the channel list down

#### Scenario: Filter on iPhone
- **GIVEN** the Guide on iPhone
- **WHEN** the user pulls the channel list down and types in the search field that appears
- **THEN** the rows narrow the same way after each letter, and canceling the field brings the whole group back
