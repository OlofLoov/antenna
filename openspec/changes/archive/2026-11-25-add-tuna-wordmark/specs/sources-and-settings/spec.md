## MODIFIED Requirements

### Requirement: Pick the app icon on this device
The system SHALL offer an App icon row in Settings, Appearance on iPhone, iPad and Apple TV, listing the standard icon and the six alternates with a picture of each and a mark on the current one. Picking one SHALL change the Home Screen icon of this device only, whichever profile is current. The Mac SHALL show no App icon row.

#### Scenario: Picking Mono on iPhone
- **GIVEN** the standard icon on an iPhone
- **WHEN** the user opens Settings, Appearance, App icon and picks Mono
- **THEN** the system confirms the change and the Home Screen shows the Mono icon
- **AND** the App icon row reads Mono

#### Scenario: Back to the standard icon
- **GIVEN** the Light icon
- **WHEN** the user picks Antuna
- **THEN** the Home Screen shows the standard icon again

#### Scenario: Another profile on the same device
- **GIVEN** Dad picked the Blue icon on the iPad
- **WHEN** the iPad switches to Kids
- **THEN** the icon stays Blue, and the App icon row reads Blue for Kids too

#### Scenario: Another device
- **GIVEN** Dad picked the Amber icon on the iPhone
- **WHEN** Dad opens Settings on the Apple TV
- **THEN** the Apple TV keeps its own icon

#### Scenario: On a Mac
- **WHEN** the user opens Settings, Appearance on a Mac
- **THEN** it shows Accent and no App icon row

#### Scenario: The system refuses the change
- **GIVEN** the system cannot change the icon right now
- **WHEN** the user picks an icon
- **THEN** the row keeps the icon the Home Screen shows

#### Scenario: The pictures in the row
- **WHEN** the user opens the App icon row
- **THEN** each picture is the Antuna a in that icon's colors, the standard one with teal tips
