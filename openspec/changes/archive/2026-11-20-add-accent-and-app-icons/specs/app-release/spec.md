# Spec Delta

## ADDED Requirements

### Requirement: Alternate icons keep the mark
Antenna on iPhone, iPad and Apple TV MUST ship six alternate icons, Mono, Light, Teal, Amber, Pink and Violet, each the standard mark in one color on a plain ground, with no text and no third-party mark. On iPhone and iPad each MUST have a dark, a tinted and a clear version in which the mark stays legible, as the standard icon does. On Apple TV each MUST be a layered icon that lifts and shifts on focus.

#### Scenario: An alternate on the Home Screen
- **GIVEN** the user picked Amber in Settings
- **WHEN** they look at the Home Screen
- **THEN** the icon shows the Antenna mark in amber on the dark ground

#### Scenario: The Light icon in dark mode
- **GIVEN** the Light icon and Home Screen icons set to dark
- **WHEN** the user looks at the Home Screen
- **THEN** the system draws it dark like every other icon, with a light mark on a black ground

#### Scenario: Tinted icons
- **GIVEN** any alternate icon
- **WHEN** the user sets Home Screen icons to tinted with any color
- **THEN** the mark shows in that tint and stays readable at Home Screen size

#### Scenario: Focusing an alternate on Apple TV
- **GIVEN** the Violet icon on Apple TV
- **WHEN** the user moves focus to Antenna on the Home Screen
- **THEN** the violet mark lifts and its layers shift apart as the user moves a finger on the Siri Remote
