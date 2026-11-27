## MODIFIED Requirements

### Requirement: The Privacy Policy says where data is kept
The system SHALL publish a Privacy Policy that names Code Crave as the publisher and says sources, favorites, preferences, reminders, groups and watch progress sync through the user's own private iCloud where Code Crave cannot read them, in encrypted fields that are end-to-end encrypted when the user turns on Advanced Data Protection, what Apple can still see of them, that logins stay in the user's iCloud Keychain except a sealed login sent from an iPhone to an Apple TV that waits in the user's private iCloud for at most ten minutes, how to delete the data, and how to reach the publisher.

#### Scenario: Reading the policy
- **WHEN** someone opens the Privacy Policy
- **THEN** they find sections on what Antuna stores, logins, network connections, analytics and tracking, purchases, deleting data, children, changes to the policy and contact

#### Scenario: Where a password goes
- **WHEN** someone reads the section on logins
- **THEN** it says passwords stay in their iCloud Keychain and names the ten-minute exception for sending a login to an Apple TV

#### Scenario: Who can read the library
- **WHEN** someone reads the section on what Antuna stores
- **THEN** it says the library is in encrypted fields, that with Advanced Data Protection only their devices hold the keys, that without it Apple holds them, and that Apple sees how many records there are, their size and when they changed
