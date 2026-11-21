## ADDED Requirements

### Requirement: Login checks are remembered
The system SHALL ask the Keychain whether a source has its login once while the app stays in front, after the login is found. A missing login SHALL be checked again each time, and a login that cannot be read SHALL count as here. Saving or deleting a login, and the app coming back to the front, SHALL make the next check ask the Keychain again.

#### Scenario: Browsing a library
- **GIVEN** an Xtream source whose login is on this device
- **WHEN** the user opens title pages, watches previews and presses Play many times
- **THEN** the Keychain is asked about that login once

#### Scenario: A login that arrives later
- **GIVEN** a source waiting for its login
- **WHEN** iCloud Keychain delivers the login
- **THEN** the next check finds it and the source loads

#### Scenario: A login removed on another device
- **GIVEN** a source whose login was found, and the user deletes the source on another device
- **WHEN** this device comes back to the front
- **THEN** the next check asks the Keychain again and finds the login missing

#### Scenario: A locked Keychain
- **GIVEN** a source whose login cannot be read
- **WHEN** the app checks for it
- **THEN** it counts as here, so the load runs and reports the failure
