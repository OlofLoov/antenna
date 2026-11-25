## ADDED Requirements

### Requirement: The Antuna mark
The app, its icons and the website MUST draw the Antuna mark from one set of shapes: the word "antuna" in round monoline letters, whose last "a" is a tuna head with a mouth and a soft tail, a play triangle through its middle and two antennae with round tips on top. Where the word does not fit, the a stands alone with its antennae. The still mark has no eye.

#### Scenario: The still mark
- **WHEN** a reviewer looks at the mark when it is not moving
- **THEN** the play triangle sits in the middle of the last a as the play button, and there is no eye

#### Scenario: A narrow place
- **WHEN** the mark has to fit a square, such as the app icon or the launch splash
- **THEN** it is the last a with its antennae, without the other letters

### Requirement: The mark's colors
On a dark ground the mark's letters MUST be #F2F4F8 and its tips teal #4FD1C5; on a light ground the letters MUST be #0B0E13 and the tips #119C8F. The play triangle and the mouth MUST show whatever is behind the mark.

#### Scenario: The mark on the dark ground
- **WHEN** a reviewer looks at the mark on the app's dark ground
- **THEN** the letters are near-white and the two tips teal

#### Scenario: The mark on a light ground
- **WHEN** the mark appears on a light page
- **THEN** the letters are near-black and the tips a darker teal

#### Scenario: The mark over a picture
- **GIVEN** the mark drawn over a photo or a gradient
- **WHEN** a reviewer looks at the play triangle and the mouth
- **THEN** they see the picture through them, not a patch of the app's ground color

### Requirement: The mark moves at three moments
The mark SHALL move only at three moments, Hello, Tuning and Got it, each tied to something the user did or is waiting for, and SHALL otherwise stand still. Each moment SHALL look the same on iPhone, iPad, Mac and Apple TV.

#### Scenario: Hello
- **WHEN** Hello plays
- **THEN** over 3.2 s the letters draw from left to right, the last a lands as a solid head, the play triangle opens in it, the antennae rise and their tips pop, and the mouth opens once
- **AND** the triangle slides forward and up to become a round eye, blinks once and slides back to be the play button

#### Scenario: Tuning
- **GIVEN** a wait that lasts ten seconds
- **WHEN** Tuning plays
- **THEN** the antennae keep leaning from side to side, once every 2.4 s, and the tips send out faint teal rings in turn
- **AND** the triangle has moved forward to be the eye, looks the way the antennae lean and blinks now and then, and the mouth opens and closes slowly

#### Scenario: Got it
- **WHEN** Got it plays
- **THEN** over 1.2 s the tail flicks once, the tips hop, the eye squints, the mouth gulps, and the eye slides back to the middle to become the play button

#### Scenario: Hello and Got it end on the still mark
- **WHEN** Hello has played for 3.2 s, or Got it for 1.2 s
- **THEN** the mark stands still with the play triangle in the middle and no eye

#### Scenario: Nothing to wait for
- **WHEN** a reviewer finds the mark moving where no screen is opening, loading or confirming
- **THEN** it fails this requirement

### Requirement: Reduce Motion stills the mark
When the system's Reduce Motion setting is on, the mark SHALL NOT draw, lean, hop or slide. Hello SHALL fade the still mark in over 0.4 s, Got it SHALL fade it from half to full strength over 0.4 s, and Tuning SHALL pulse the tips' opacity slowly while everything else stands still.

#### Scenario: Hello with Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the welcome screen opens
- **THEN** the still mark fades in and nothing on it moves

#### Scenario: Tuning with Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the Apple TV loading screen shows
- **THEN** only the two tips change, dimming and brightening every 2.4 s, and no eye appears

## MODIFIED Requirements

### Requirement: One accent color per profile
Each profile MUST have one accent color from a fixed set of five, Blue by default, and it MUST be the app's tint, so system controls draw with it. It SHALL appear only on progress fills, the guide's now line, the NOW and UP NEXT badges, links, the selected iPhone tab, the app icon, and system controls that tint by default. Eyebrows, titles, icons and decoration are not tinted. The Antuna mark is the one exception: its tips are teal on every profile, as the brand's color, and teal appears nowhere else on a screen because of it.

#### Scenario: The five accents
- **WHEN** a reviewer opens the accent choices
- **THEN** they are Blue, Teal, Amber, Pink and Violet, and a profile that never picked one shows Blue

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
- **THEN** it is the Antuna a in near-white with teal tips on the dark ground, and uses no other color

#### Scenario: The mark on an Amber profile
- **GIVEN** the current profile's accent is Amber
- **WHEN** the mark shows on a loading screen
- **THEN** its tips are teal and the progress on the same screen is amber

#### Scenario: An eyebrow over a title
- **WHEN** a reviewer finds an eyebrow such as "RECENTLY ADDED" or "SERIES" in the accent
- **THEN** it fails this requirement

#### Scenario: Connect on iPhone
- **WHEN** the add-source sheet shows on iPhone
- **THEN** Connect is the prominent system button in the current profile's accent
