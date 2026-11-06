# Spec Delta

## ADDED Requirements

### Requirement: Guide links for an imported file
The system SHALL take an imported file source's guide links from the file's header, or from the guide link the user entered when importing, and download them like any playlist's.

#### Scenario: A file with a guide link in its header
- **GIVEN** an imported file whose header names a guide link
- **WHEN** guide data loads for that source
- **THEN** the guide downloads from that link and its programmes show for the file's channels
