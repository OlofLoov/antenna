# Spec Delta

## ADDED Requirements

### Requirement: Pick the accent for your profile
The system SHALL show an Appearance section in Settings on every platform with an Accent row for the current profile, listing the five accents with a swatch and a name and a mark on the current one. Picking one SHALL change the accent for that profile on every device and show it at once on this one.

#### Scenario: Picking Teal on iPhone
- **GIVEN** the iPhone is on Dad, whose accent is Blue
- **WHEN** the user opens Settings, Appearance, Accent and picks Teal
- **THEN** the Accent row reads Teal, and progress bars, links, badges, switches and the selected tab show Teal

#### Scenario: Picking on Apple TV
- **GIVEN** an Apple TV on Kids
- **WHEN** the user selects Accent in Settings and picks Amber
- **THEN** the choices page closes, the row reads Amber, and the progress bars, now line and badges show Amber
- **AND** focus still shows as the light platter

#### Scenario: One profile
- **GIVEN** a single profile
- **WHEN** the user picks Pink in Settings
- **THEN** the app shows Pink, and still shows no profile name or profile button

#### Scenario: Another profile is unchanged
- **GIVEN** the profiles Dad and Kids, both Blue
- **WHEN** Dad picks Violet
- **THEN** Kids still shows Blue

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the Accent row is focused
- **THEN** it reads "Accent" and the current accent's name

### Requirement: Pick the app icon on this device
The system SHALL offer an App icon row in Settings, Appearance on iPhone, iPad and Apple TV, listing the standard icon and the six alternates with a picture of each and a mark on the current one. Picking one SHALL change the Home Screen icon of this device only, whichever profile is current. The Mac SHALL show no App icon row.

#### Scenario: Picking Mono on iPhone
- **GIVEN** the standard icon on an iPhone
- **WHEN** the user opens Settings, Appearance, App icon and picks Mono
- **THEN** the system confirms the change and the Home Screen shows the Mono icon
- **AND** the App icon row reads Mono

#### Scenario: Back to the standard icon
- **GIVEN** the Light icon
- **WHEN** the user picks Antenna
- **THEN** the Home Screen shows the standard icon again

#### Scenario: Another profile on the same device
- **GIVEN** Dad picked the Teal icon on the iPad
- **WHEN** the iPad switches to Kids
- **THEN** the icon stays Teal, and the App icon row reads Teal for Kids too

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
