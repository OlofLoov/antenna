## ADDED Requirements

### Requirement: Logins are shared between the apps
The system SHALL keep every login where both the iPhone, iPad and Mac app and the Apple TV app can read it, so a login saved in one app reaches the other through iCloud Keychain.

#### Scenario: A login saved on the iPhone reaches the Apple TV
- **GIVEN** an Xtream source saved on the iPhone, and an Apple TV signed in to the same iCloud account
- **WHEN** iCloud Keychain delivers the login to the Apple TV
- **THEN** the Apple TV reads the login and loads the source's channels without asking for it

#### Scenario: A new login is written to the shared place
- **WHEN** the user saves a source with a login on any device
- **THEN** the login is stored where both apps can read it

### Requirement: Logins saved by an earlier version move to the shared place
The system SHALL move a login that an earlier version kept where only one app could read it to the shared place the first time it reads that login, and SHALL remove the old copy once the new one is written.

#### Scenario: First read after the update
- **GIVEN** a login saved by an earlier version where only the iPhone app can read it
- **WHEN** the iPhone app reads it
- **THEN** the source loads with that login, the login is now in the shared place, and the old copy is gone

#### Scenario: The move fails
- **GIVEN** a login saved by an earlier version, and a Keychain that refuses the new copy
- **WHEN** the app reads it
- **THEN** the source still loads with that login, the old copy stays, and the next read tries the move again

#### Scenario: Both copies exist
- **GIVEN** a login in the shared place and an older copy where only one app can read it
- **WHEN** the app reads it
- **THEN** it uses the shared copy and removes the older one

#### Scenario: Deleting a source removes every copy
- **GIVEN** a source whose login is in the shared place and an older copy
- **WHEN** the user deletes the source
- **THEN** no copy of the login is left

### Requirement: Sources stay on the device without iCloud
The system SHALL keep adding, loading and playing sources on a device that cannot reach iCloud, because the build has no iCloud capability or the device is signed out, and SHALL treat features that need iCloud, such as sending a login to an Apple TV, as not signed in.

#### Scenario: A build without the iCloud capability
- **GIVEN** a build signed without the iCloud capability, or not signed at all
- **WHEN** the user adds a source, quits and opens the app again
- **THEN** the source is still there with its channels, nothing is sent to iCloud, and the app does not stop

#### Scenario: Sending a login without iCloud
- **GIVEN** a build or device that cannot reach iCloud
- **WHEN** the Apple TV sign-in or the iPhone's send screen checks iCloud
- **THEN** it shows its not-signed-in state, as on a device signed out of iCloud
