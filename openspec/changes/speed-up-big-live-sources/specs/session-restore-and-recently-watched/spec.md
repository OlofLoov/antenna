## ADDED Requirements

### Requirement: The last channel does not wait for bookkeeping
The system SHALL tune the restored channel as soon as its source's channels are loaded, before it records which channels the device has seen, on every platform. The New group SHALL show what that record finds once it is written.

#### Scenario: A very large source at launch
- **GIVEN** the last channel belongs to a source with 50 000 channels
- **WHEN** the app launches and the source loads
- **THEN** the channel starts without waiting for the seen-channel record to be read or written

#### Scenario: New channels after the record
- **GIVEN** a source that gained channels since its last load
- **WHEN** it loads and the record is written
- **THEN** the New group shows the gained channels, as before
