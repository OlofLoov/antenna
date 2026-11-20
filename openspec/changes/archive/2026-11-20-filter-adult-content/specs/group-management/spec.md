# Spec Delta

## MODIFIED Requirements

### Requirement: Changes follow you to every device
The system SHALL sync hidden, renamed, locked, adult-marked and user-made groups to every device on the same iCloud account, and the locks on each device SHALL stay closed until the passcode is entered there.

#### Scenario: A second device
- **GIVEN** the user hides one group, renames another, locks a third, marks a fourth adult and creates their own group on one device
- **WHEN** their other device, signed into the same iCloud account, is online
- **THEN** it shows all five changes
- **AND** its locks stay closed until the passcode is entered there

#### Scenario: Offline or signed out
- **GIVEN** the device is offline or signed out of iCloud
- **WHEN** the user changes group settings
- **THEN** the changes apply on this device and sync once it is back

#### Scenario: The subscription ends
- **GIVEN** the user has group settings
- **WHEN** the subscription ends
- **THEN** the paywall replaces these screens and every setting is kept
