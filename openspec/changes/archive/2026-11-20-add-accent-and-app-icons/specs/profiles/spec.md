# Spec Delta

## MODIFIED Requirements

### Requirement: Adding a profile
The system SHALL let the user add a profile with a name, one of eight colors and one of five accents from Manage profiles, reached from the "Who's watching?" screen or from Profiles in Settings, up to eight profiles. A new profile's accent SHALL start as Blue.

#### Scenario: The second profile
- **GIVEN** a single profile and no profile shown anywhere
- **WHEN** the user adds a profile named Kids from Settings
- **THEN** the existing profile is named "Main" and Kids is added after it
- **AND** the next launch shows the "Who's watching?" screen

#### Scenario: A name is needed
- **GIVEN** the user is adding a profile
- **WHEN** the name is empty or only spaces
- **THEN** the profile cannot be saved

#### Scenario: Eight profiles
- **GIVEN** eight profiles
- **WHEN** the user looks for a way to add another
- **THEN** there is none, and Manage profiles says eight is the most

#### Scenario: Picking an accent for a new profile
- **GIVEN** the user is adding a profile named Kids
- **WHEN** they pick Amber under Accent and save
- **THEN** Kids is added with the Amber accent, and the app shows Amber whenever Kids is the current profile

### Requirement: Editing and deleting a profile
The system SHALL let the user rename, recolor, change the accent of and delete a profile, SHALL ask before deleting and say that its favorites and history go with it, and SHALL NOT delete the last profile. A changed accent SHALL show at once if the profile is current.

#### Scenario: Deleting a profile
- **GIVEN** the profiles Dad and Kids
- **WHEN** the user deletes Kids and confirms
- **THEN** Kids, its favorites, hidden groups, watch progress, My list, recent searches and recently watched are removed on every device
- **AND** Dad is unchanged and the next launch shows no "Who's watching?" screen

#### Scenario: The last profile
- **GIVEN** a single profile
- **WHEN** the user edits it
- **THEN** it can be renamed, recolored and given another accent but not deleted

#### Scenario: A device on a deleted profile
- **GIVEN** the Apple TV is on Kids
- **WHEN** Kids is deleted on the iPhone
- **THEN** the Apple TV shows the "Who's watching?" screen, or opens on the only profile left

#### Scenario: Changing the accent of the current profile
- **GIVEN** the iPhone is on Dad, whose accent is Blue
- **WHEN** the user edits Dad, picks Violet and saves
- **THEN** progress bars, links, badges and system controls show Violet without a restart

### Requirement: Profiles sync between devices
The system SHALL sync profiles, their names, colors, accents and order through the user's private iCloud account, and SHALL keep which profile is current on each device on that device only. A profile with no accent stored, or one this version does not know, SHALL show Blue.

#### Scenario: A profile added on the iPhone
- **GIVEN** the Apple TV and the iPhone use the same iCloud account
- **WHEN** Kids is added on the iPhone
- **THEN** the Apple TV lists Kids on its next "Who's watching?" screen

#### Scenario: A new device before profiles arrive
- **GIVEN** a device signed into iCloud whose profiles have not synced yet
- **WHEN** the user opens Antenna
- **THEN** it opens as with one profile, and shows the "Who's watching?" screen at the next launch after the profiles arrive

#### Scenario: The same profile made on two devices
- **GIVEN** the first extra profile is added on two devices before they sync
- **WHEN** they sync
- **THEN** each device lists one "Main" profile, not two, and both new profiles

#### Scenario: An accent picked on the iPhone
- **GIVEN** the Apple TV and the iPhone use the same iCloud account and both are on Dad
- **WHEN** Dad's accent is changed to Teal on the iPhone
- **THEN** the Apple TV shows Teal on Dad once the change arrives

#### Scenario: Profiles from before accents
- **GIVEN** profiles made before accents existed
- **WHEN** the user updates Antenna
- **THEN** every profile shows Blue until someone picks another accent
