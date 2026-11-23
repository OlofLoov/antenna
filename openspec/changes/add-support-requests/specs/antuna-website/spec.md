## MODIFIED Requirements

### Requirement: The Privacy Policy rules out tracking
The system SHALL say in the Privacy Policy that Antenna has no analytics, tracking, advertising or third-party SDK, that network requests go only to the user's sources, the addresses those sources list, Apple's services, the movie info service and, when the user sends a problem report, the support service, and that Apple handles purchases. It SHALL say that the movie info service receives only the name, year and database ids of a title whose page the user opens, keeps no record of the request, and can be turned off in Settings.

#### Scenario: Looking for tracking
- **WHEN** someone looks for what Antenna collects about them
- **THEN** the policy says Antenna has no analytics or tracking, and that the only thing Code Crave keeps is a problem report the user chooses to send

#### Scenario: Where the app connects
- **WHEN** someone reads the section on network connections
- **THEN** it lists their sources, addresses their sources list such as logos and guides, Apple, the movie info service with what it receives and the Settings switch that turns it off, and the support service when a report is sent

## ADDED Requirements

### Requirement: The Privacy Policy explains problem reports
The system SHALL say in the Privacy Policy what a problem report holds and never holds, that it holds nothing that says who sent it, so Code Crave cannot reply to it or find it without its reference, that the user sees it before sending, that a crash or hang report is attached only when the user ticks it, that reports are kept in a private GitHub repository only Code Crave can read and deleted 12 months after they were sent, and how to delete one from the device that sent it.

#### Scenario: Reading about reports
- **WHEN** someone opens the Privacy Policy
- **THEN** a section on problem reports lists what a report holds, says source addresses, names, logins, channels and any way to reach the user are never sent, says reports cannot be answered, and names GitHub as where reports are kept

#### Scenario: Asking for a report to be deleted
- **WHEN** someone wants a report they sent deleted
- **THEN** the policy tells them to open Report a problem, then Sent reports, on the device that sent it and choose Delete, and says the report is gone within seven days
- **AND** it says a report no longer listed on any device, for example after a reinstall, is deleted when the 12 months end, and names no email address for deletion
