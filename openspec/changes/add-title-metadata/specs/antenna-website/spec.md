## MODIFIED Requirements

### Requirement: The Privacy Policy rules out tracking
The system SHALL say in the Privacy Policy that Antenna has no analytics, tracking, advertising or third-party SDK, that network requests go only to the user's sources, the addresses those sources list, Apple's services and the movie info service, and that Apple handles purchases. It SHALL say that the movie info service receives only the name, year and database ids of a title whose page the user opens, keeps no record of the request, and can be turned off in Settings.

#### Scenario: Looking for tracking
- **WHEN** someone looks for what Antenna collects about them
- **THEN** the policy says Antenna has no analytics or tracking and that Code Crave keeps nothing it receives

#### Scenario: Where the app connects
- **WHEN** someone reads the section on network connections
- **THEN** it lists their sources, addresses their sources list such as logos and guides, Apple, and the movie info service with what it receives and the Settings switch that turns it off
