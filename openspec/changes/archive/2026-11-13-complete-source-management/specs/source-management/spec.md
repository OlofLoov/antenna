## ADDED Requirements

### Requirement: Sources sync between devices
The system SHALL list a source saved on one device in Sources and Settings on every other device signed in to the same iCloud account, without the user doing anything, with its name, type and status and never its link, and SHALL load its channels there.

#### Scenario: Second device
- **GIVEN** a source saved on device A
- **WHEN** device B, signed in to the same iCloud account, receives it from iCloud
- **THEN** B lists it in the user's order with its name, type and status line, and no link
- **AND** its channels load on B

#### Scenario: The Xtream login arrives later
- **GIVEN** an Xtream source saved on device A whose login has not reached device B yet
- **WHEN** B lists the source
- **THEN** its status line says it is waiting for the login from iCloud
- **AND** its channels load once the login arrives through iCloud Keychain
