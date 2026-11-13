## MODIFIED Requirements

### Requirement: Nothing fake and nothing bundled
The app MUST draw no fake status bars and bundle no channels, titles,
third-party logos or artwork, except the logo a data service's licence
requires for its credit in Settings, About. Sample names on the boards are
for layout and never ship, and sample logins never use a real name. Copy
MUST NOT name the user, the user's device or a state the app cannot see.
Naming the platform is allowed.

#### Scenario: Fresh install
- **WHEN** the user opens the app before adding a source
- **THEN** no channel, title, logo or artwork appears that the user did not supply

#### Scenario: Copy that names the device
- **WHEN** a reviewer finds copy such as "your iPhone", a device name, or a notification on another device
- **THEN** it fails this requirement

#### Scenario: Copy that names the platform
- **WHEN** copy says "this Apple TV" or "Antenna on iPhone"
- **THEN** it passes

#### Scenario: A credit logo
- **WHEN** the TMDB logo shows in Settings, About, because its terms require it
- **THEN** it passes, and the same logo anywhere else fails
