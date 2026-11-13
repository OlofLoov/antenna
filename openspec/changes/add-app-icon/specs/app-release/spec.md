## ADDED Requirements

### Requirement: Every app shows its icon
Antenna on iPhone, iPad, Mac and Apple TV MUST show the Antenna icon wherever the system shows an app icon: the Home Screen, the Dock, Settings, Spotlight, the App Switcher and the App Store. The icon MUST contain no text and no third-party mark.

#### Scenario: Installing on iPhone
- **WHEN** the user installs Antenna on an iPhone or iPad
- **THEN** the Home Screen shows the Antenna icon, not the blank placeholder

#### Scenario: Opening on a Mac
- **WHEN** the user opens Antenna on a Mac
- **THEN** the Dock and Finder show the Antenna icon, and the mark is still recognizable at 16 pixels in a list

#### Scenario: Focusing the icon on Apple TV
- **WHEN** the user moves focus to Antenna on the Apple TV Home Screen
- **THEN** the icon lifts and its layers shift apart as the user moves a finger on the Siri Remote

#### Scenario: Top Shelf with nothing to list
- **GIVEN** Antenna sits in the top row on Apple TV and has no favorites or recents to show
- **WHEN** the user focuses it
- **THEN** the Top Shelf shows the Antenna mark on the dark ground instead of an empty area

### Requirement: The icon follows the Home Screen appearance
On iPhone, iPad and Mac the icon MUST have a dark, a tinted and a clear version in which the mark stays legible, matching the icon appearance the user picked.

#### Scenario: Dark icons
- **WHEN** the user sets Home Screen icons to dark
- **THEN** Antenna's icon shows the blue mark on a black ground

#### Scenario: Tinted icons
- **WHEN** the user sets Home Screen icons to tinted with any color
- **THEN** Antenna's mark shows in that tint and stays readable at Home Screen size
