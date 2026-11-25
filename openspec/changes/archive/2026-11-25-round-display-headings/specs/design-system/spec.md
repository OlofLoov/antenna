## ADDED Requirements

### Requirement: Display headings are rounded
Text MUST be set in the system font. The two largest text styles of each platform MUST use its rounded design: Large Title and Title 1 on iPhone, iPad and Mac, Title 1 and Title 2 on Apple TV. Every smaller style MUST be plain. The design MUST follow from the size a board gives, never from the screen. The app MUST NOT bundle or download a font.

#### Scenario: The paywall headline
- **WHEN** a reviewer looks at "Unlock Antuna" on the paywall on iPhone and on Apple TV
- **THEN** it is in the rounded face on both, and the text and product rows under it are plain

#### Scenario: A movie's page
- **WHEN** the user opens a movie on iPad
- **THEN** its title is rounded, and the year, length, description and buttons are plain

#### Scenario: A row of channels
- **WHEN** a reviewer checks a channel row, a programme title in the guide or a Settings row on any platform
- **THEN** it is plain

#### Scenario: Larger text
- **GIVEN** the user has picked a larger text size on iPhone
- **WHEN** they open Movies
- **THEN** the screen title grows with the system and is still rounded

#### Scenario: Arabic
- **GIVEN** the device language is Arabic
- **WHEN** the user opens the paywall
- **THEN** the headline is in the system Arabic font and laid out right to left

#### Scenario: A system title
- **WHEN** the user opens Sources & Settings on iPhone
- **THEN** its large navigation title is drawn by the system in its usual face

#### Scenario: A bundled font
- **WHEN** a reviewer finds a font file in the app, or a screen that loads a font by name
- **THEN** it fails this requirement

## MODIFIED Requirements

### Requirement: Type uses text styles
Text MUST use the platform's text styles (large title, title 1 to 3,
headline, body, callout, subheadline, footnote, caption 1 and 2), with a
weight change where the board asks for one. The design, rounded or plain,
comes with the style (design-system/display-headings-are-rounded). A fixed
point size is allowed only for glyphs that are not text, for the channel
number entry, and for the guide grid's time labels. A board gives the size;
the reference maps each size to its text style.

#### Scenario: Body copy on Apple TV
- **WHEN** a reviewer checks a description line on Apple TV
- **THEN** it is the body text style, 29 pt, and changes size with the system when the platform scales text

#### Scenario: Larger text on iPhone
- **GIVEN** the user has picked a larger text size on iPhone
- **WHEN** they open the add-source sheet
- **THEN** every label and field grows with it and nothing is cut off

#### Scenario: A fixed size in a screen
- **WHEN** a reviewer finds a fixed point size on text that is not on the exception list
- **THEN** it fails this requirement
