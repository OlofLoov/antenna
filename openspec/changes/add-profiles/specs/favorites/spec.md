## ADDED Requirements

### Requirement: Favorites belong to a profile
The system SHALL keep each favorite for the profile that added it, list only the current profile's favorites, and SHALL count favorites made before the user had more than one profile as the first profile's.

#### Scenario: Two profiles
- **GIVEN** Dad favorited Sport One and Kids favorited Cartoon Club
- **WHEN** Kids opens the Favorites tab
- **THEN** only Cartoon Club is listed

#### Scenario: Favorites from before profiles
- **GIVEN** favorites saved while there was one profile
- **WHEN** the user adds a second profile
- **THEN** those favorites stay with the first profile, now named "Main", and the new profile has none

## MODIFIED Requirements

### Requirement: Favorites sync between devices
The system SHALL sync favorites through the user's private iCloud account to every device signed into it, each favorite with its profile. This is checked by hand on two devices.

#### Scenario: Second device
- **GIVEN** a favorite saved on device A
- **WHEN** device B, an iPhone, iPad or Mac signed into the same iCloud account, is online
- **THEN** the favorite appears in device B's Favorites tab

#### Scenario: Another profile on the second device
- **GIVEN** Dad saved a favorite on device A
- **WHEN** device B is on Kids
- **THEN** the favorite is not in device B's Favorites tab until Dad is chosen there
