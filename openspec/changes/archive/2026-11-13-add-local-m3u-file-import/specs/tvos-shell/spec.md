# Spec Delta

## ADDED Requirements

### Requirement: A file source waiting for iCloud
The system SHALL show an imported file source whose contents have not yet arrived on Apple TV as waiting for iCloud, where a source without its login shows as waiting for its login, and load its channels without a relaunch once they arrive.

#### Scenario: Contents arrive later
- **GIVEN** a file source synced to Apple TV without its contents yet
- **WHEN** the contents arrive through iCloud
- **THEN** the source stops showing as waiting for iCloud and its channels appear without a relaunch
