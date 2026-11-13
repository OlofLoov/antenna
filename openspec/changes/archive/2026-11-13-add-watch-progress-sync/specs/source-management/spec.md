# Spec Delta

## ADDED Requirements

### Requirement: Deleting a source removes its watch history
The system SHALL remove a source's watch progress and My list entries when the user deletes that source, after its credential and record are gone, and SHALL leave recent searches in place.

#### Scenario: Delete a source with history
- **GIVEN** a source with watch progress and My list entries, and some recent searches
- **WHEN** the user deletes the source
- **THEN** its credential, its record, its progress and its My list entries are gone, and recent searches stay
