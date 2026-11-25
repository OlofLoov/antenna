## MODIFIED Requirements

### Requirement: Every app shows its icon
Antuna on iPhone, iPad, Mac and Apple TV MUST show the Antuna icon wherever the system shows an app icon: the Home Screen, the Dock, Settings, Spotlight, the App Switcher and the App Store. The icon MUST show the Antuna a with its antennae on the dark ground, with no other text and no third-party mark.

#### Scenario: Installing on iPhone
- **WHEN** the user installs Antuna on an iPhone or iPad
- **THEN** the Home Screen shows the Antuna icon, not the blank placeholder

#### Scenario: Opening on a Mac
- **WHEN** the user opens Antuna on a Mac
- **THEN** the Dock and Finder show the Antuna icon, and the a is still recognizable at 16 pixels in a list

#### Scenario: Focusing the icon on Apple TV
- **WHEN** the user moves focus to Antuna on the Apple TV Home Screen
- **THEN** the icon lifts, and the antennae, the a and the ground shift apart as the user moves a finger on the Siri Remote

#### Scenario: Top Shelf with nothing to list
- **GIVEN** Antuna sits in the top row on Apple TV and has no favorites or recents to show
- **WHEN** the user focuses it
- **THEN** the Top Shelf shows the Antuna wordmark on the dark ground instead of an empty area

### Requirement: The icon follows the Home Screen appearance
On iPhone, iPad and Mac the icon MUST have a dark, a tinted and a clear version in which the mark stays legible, matching the icon appearance the user picked.

#### Scenario: Dark icons
- **WHEN** the user sets Home Screen icons to dark
- **THEN** Antuna's icon shows the near-white a with teal tips on a black ground

#### Scenario: Tinted icons
- **WHEN** the user sets Home Screen icons to tinted with any color
- **THEN** Antuna's mark shows in that tint and stays readable at Home Screen size

### Requirement: Alternate icons keep the mark
Antuna on iPhone, iPad and Apple TV MUST ship six alternate icons, Mono, Light, Blue, Amber, Pink and Violet, each the standard a with its tips in one color, with no other text and no third-party mark. Mono has near-white tips on the dark ground, Light a near-black a with darker teal tips on a light ground, and Blue, Amber, Pink and Violet a near-white a with tips in that accent on the dark ground. On iPhone and iPad each MUST have a dark, a tinted and a clear version in which the mark stays legible, as the standard icon does. On Apple TV each MUST be a layered icon that lifts and shifts on focus.

#### Scenario: An alternate on the Home Screen
- **GIVEN** the user picked Amber in Settings
- **WHEN** they look at the Home Screen
- **THEN** the icon shows the Antuna a with amber tips on the dark ground

#### Scenario: The Light icon in dark mode
- **GIVEN** the Light icon and Home Screen icons set to dark
- **WHEN** the user looks at the Home Screen
- **THEN** the system draws it dark like every other icon, with a light a on a black ground

#### Scenario: Tinted icons
- **GIVEN** any alternate icon
- **WHEN** the user sets Home Screen icons to tinted with any color
- **THEN** the mark shows in that tint and stays readable at Home Screen size

#### Scenario: Focusing an alternate on Apple TV
- **GIVEN** the Violet icon on Apple TV
- **WHEN** the user moves focus to Antuna on the Home Screen
- **THEN** the a with its violet tips lifts and its layers shift apart as the user moves a finger on the Siri Remote

#### Scenario: A device that had the Teal icon
- **GIVEN** a test build where the owner picked the Teal alternate
- **WHEN** this build is installed over it
- **THEN** the device shows the standard icon, which is teal now
