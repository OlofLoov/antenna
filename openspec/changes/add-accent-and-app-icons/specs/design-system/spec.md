# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: One accent color`
- TO: `### Requirement: One accent color per profile`

## MODIFIED Requirements

### Requirement: One accent color per profile
Each profile MUST have exactly one accent color, picked from a fixed set of five (Blue, Teal, Amber, Pink and Violet), with the reference's accent blue as the default. Every accent in the set MUST reach 4.5:1 against the app background, a raised row and glass. The current profile's accent MUST be the app's tint, so system controls draw with it. It SHALL appear only on progress fills, the guide's now line, the NOW and UP NEXT badges, links, the selected iPhone tab, the app icon, and system controls that tint by default (the prominent button on iPhone, iPad and Mac, switches, and selected picker values). Eyebrows, titles, icons and decoration are not tinted. On Apple TV focus keeps the system look whatever the accent.

#### Scenario: A tinted icon
- **WHEN** a reviewer finds an icon or label tinted in a color other than the current profile's accent
- **THEN** it fails this requirement

#### Scenario: Accent on a decorative element
- **WHEN** the accent appears on something that is not progress, the now line, a NOW or UP NEXT badge, a link, the selected iPhone tab, the app icon or a system control's tint
- **THEN** it fails this requirement

#### Scenario: Two accents on one screen
- **GIVEN** the current profile's accent is Teal
- **WHEN** a reviewer finds Blue, or any accent but Teal, on a progress bar, badge, link or system control
- **THEN** it fails this requirement

#### Scenario: The whole app follows the profile
- **GIVEN** Dad's accent is Blue and Kids's is Amber
- **WHEN** the device switches from Dad to Kids
- **THEN** progress bars, the now line, the badges, links, switches, the prominent button and the selected iPhone tab all show Amber

#### Scenario: Contrast of every accent
- **WHEN** a reviewer measures any of the five accents against the app background, a raised row or glass
- **THEN** the contrast is at least 4.5:1

#### Scenario: Focus on Apple TV
- **GIVEN** an Apple TV on a profile whose accent is Pink
- **WHEN** a row or button has focus
- **THEN** it is the light platter with dark text, with no pink ring or pink fill

#### Scenario: The app icon
- **WHEN** a reviewer checks the standard app icon
- **THEN** its mark is in the accent blue on the dark ground, and the mark uses no other color

#### Scenario: An eyebrow over a title
- **WHEN** a reviewer finds an eyebrow such as "RECENTLY ADDED" or "SERIES" in the accent
- **THEN** it fails this requirement

#### Scenario: Connect on iPhone
- **WHEN** the add-source sheet shows on iPhone
- **THEN** Connect is the prominent system button in the current profile's accent
