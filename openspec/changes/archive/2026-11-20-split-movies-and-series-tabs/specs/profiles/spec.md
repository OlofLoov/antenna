## MODIFIED Requirements

### Requirement: Switching profile
The system SHALL let the user switch profile from the top of Settings on Apple TV, from the profile button on iPhone, and from Settings on every device, and SHALL then show the new profile's favorites, hidden groups, last channel and history.

#### Scenario: Switching on Apple TV
- **GIVEN** two or more profiles and the tab bar raised
- **WHEN** the user selects the profile button and chooses another profile
- **THEN** Live opens on that profile's last channel on this Apple TV, or as at launch when it has none
- **AND** the channel overlay and Favorites show that profile's favorites

#### Scenario: Switching from the profile button on iPhone
- **GIVEN** two or more profiles, on iPhone or in a narrow iPad window
- **WHEN** the user taps the profile button at the top right, chooses Switch profile and picks another profile
- **THEN** what played stops, and every tab shows that profile's favorites, hidden groups and history

#### Scenario: Switching on iPhone, iPad or Mac
- **GIVEN** two or more profiles
- **WHEN** the user opens Settings, selects Profiles and chooses another profile
- **THEN** every tab shows that profile's favorites, hidden groups and history

#### Scenario: Which profile a device is on
- **GIVEN** the Apple TV is on Kids and the iPhone on Dad
- **WHEN** either is opened again later
- **THEN** the Apple TV's "Who's watching?" screen starts on Kids and the iPhone's on Dad
- **AND** choosing a profile on one device never changes the other
