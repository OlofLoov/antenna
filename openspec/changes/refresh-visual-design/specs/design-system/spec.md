## ADDED Requirements

### Requirement: Controls use system styles
Buttons, toggles, pickers, text fields and lists MUST use a system style on
every platform: bordered, bordered prominent, glass, glass prominent,
borderless, or card on Apple TV. A screen MUST NOT draw its own fill, border
or focus look for a control. The only exceptions are the parts the reference
lists as drawn by the app: guide programme blocks, channel overlay rows, zap
bar sections, multi-view tiles and the passcode digits.

#### Scenario: A primary button on any platform
- **WHEN** a reviewer finds the main action of a screen, such as Connect, Start watching or Play
- **THEN** it uses the prominent system style for that platform and gets the platform's pressed and focused looks without code of its own

#### Scenario: A custom-drawn button
- **WHEN** a reviewer finds a button whose fill, border, scale or shadow is drawn by the app and it is not on the reference's exception list
- **THEN** it fails this requirement

#### Scenario: A poster on Apple TV
- **WHEN** the viewer moves focus to a poster in a Movies or Series row
- **THEN** the poster lifts, grows and tilts with the remote the way posters do in the TV app, with no drawn ring

### Requirement: Type uses text styles
Text MUST use the platform's text styles (large title, title 1 to 3,
headline, body, callout, subheadline, footnote, caption 1 and 2), with a
weight or design change where the board asks for one. A fixed point size is
allowed only for glyphs that are not text, for the channel number entry, and
for the guide grid's time labels. A board gives the size; the reference maps
each size to its text style.

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

### Requirement: Modals are system presentations
A screen shown over another one MUST be a system sheet, full-screen cover,
alert, confirmation dialog or popover. Its content MUST fit the presentation
it uses at the platform's size: on Apple TV a sheet holds no more than its
own width, and a layout wider than that uses a full-screen cover. A modal
MUST have a title and a visible way out (Cancel, Done or Back) in its
content, and Menu on the Siri Remote MUST close it.

#### Scenario: Adding a source from Settings on Apple TV
- **WHEN** the viewer selects Add a source in Settings on Apple TV
- **THEN** the add-source screen opens as one system presentation with the system's dimmed and blurred backdrop
- **AND** every field, the QR card and the buttons are fully visible without scrolling sideways

#### Scenario: Leaving a modal with the remote
- **GIVEN** the add-source screen is open on Apple TV
- **WHEN** the viewer presses Menu with nothing typed
- **THEN** it closes and focus returns to Add a source

#### Scenario: A modal that crops its content
- **WHEN** a reviewer finds a field, button or card cut off at the edge of a sheet
- **THEN** it fails this requirement

### Requirement: Forms use the platform form style
Screens where the user types or picks settings (add a source, source
details, sign-in, Settings, preferences, profiles) MUST use the system
grouped form or list. On Apple TV each field is a row with its label and
current value, and selecting it opens the system keyboard. A choice among
values MUST be a row that shows its label and current value, never an
unlabeled segmented control. Adding and editing the same kind of record MUST
use the same rows.

#### Scenario: Add and edit look alike
- **WHEN** a reviewer compares the add-source screen with the source details screen on the same platform
- **THEN** both use the same grouped rows for name, address and login

#### Scenario: A preference on Apple TV
- **WHEN** the viewer moves focus to the guide window preference in Settings on Apple TV
- **THEN** the row reads "Guide window" with its value, and selecting it lists the choices with a checkmark on the current one

#### Scenario: Typing a server address on Apple TV
- **WHEN** the viewer selects the Server row
- **THEN** the system keyboard opens full screen, and the row shows the typed address after it closes

### Requirement: Liquid Glass stays on the navigation layer
Tab bars, toolbars, floating controls over video, and buttons in sheets MUST
use Liquid Glass through the system components or the glass effect. Rows,
cards, posters, the guide grid and other content MUST NOT use glass; panels
in the content layer use the materials in the reference. Glass MUST NOT sit
on glass.

#### Scenario: The player controls over video
- **WHEN** the player controls show over a playing picture on iPhone, iPad or Mac
- **THEN** the buttons sit on glass and the picture shows through them

#### Scenario: Glass on a content card
- **WHEN** a reviewer finds the glass effect on a row, poster or guide block
- **THEN** it fails this requirement

### Requirement: One spacing and radius scale
Padding and gaps MUST come from the spacing scale in the reference (4, 8,
12, 16, 24, 32, 48, 64, 80). Corner radii MUST be one of the four in the
reference: small, medium, large, or capsule, or follow the container with a
concentric shape. Buttons and chips are capsules.

#### Scenario: A new card
- **WHEN** a reviewer measures the corner radius of a card on any platform
- **THEN** it is the large radius for that platform or concentric with its container

#### Scenario: An off-scale value
- **WHEN** a reviewer finds a padding of 14 or a radius of 9
- **THEN** it fails this requirement

### Requirement: Apple TV content stays in the safe area
On Apple TV, text, buttons and focusable items MUST stay at least 80 pt from
the left and right edges and 60 pt from the top and bottom, including the
room a focused item takes when it grows. Full-bleed art, video and scrims
may run to the edge.

#### Scenario: A row of cards
- **WHEN** the viewer focuses the first or last card in a row on Apple TV
- **THEN** the grown card and its shadow stay inside the safe area

#### Scenario: The kind picker
- **WHEN** the add-source kinds show on Apple TV
- **THEN** the first card starts at least 80 pt from the left edge

### Requirement: Pages cover what is behind them
A page or panel opened over another screen MUST either hide that screen
with an opaque background or blur and dim it with the system backdrop or a
material from the reference. Text from the screen behind MUST never show
through or under the page's own text. Live video under the Apple TV live
overlays is the one screen allowed to stay visible, behind the overlay scrim.

#### Scenario: Settings opened from the Guide on Apple TV
- **GIVEN** the Guide is open on Apple TV
- **WHEN** the viewer opens Sources and Settings from the tab bar
- **THEN** no part of the guide grid or its programme text shows through Settings

#### Scenario: A modal over Settings
- **WHEN** the add-source screen opens over Settings on Apple TV
- **THEN** Settings behind it is dimmed and blurred by the system and none of its text competes with it

#### Scenario: A stand-in screen behind a modal
- **GIVEN** a tab that shows a placeholder or empty state
- **WHEN** a modal opens over it
- **THEN** the placeholder's text is not readable through the modal

### Requirement: Content clears the tab bar
On Apple TV a page's first line of content MUST start below the tab bar
while the bar shows, and nothing scrolls under the bar without the system
scroll edge effect. Titles, eyebrows, search fields and toolbar buttons MUST
NOT overlap the bar, the Antenna mark or the clock.

#### Scenario: Opening Settings
- **WHEN** Sources and Settings opens on Apple TV
- **THEN** its title is not drawn under or behind the tab bar

#### Scenario: The Movies hero
- **WHEN** the viewer opens Movies on Apple TV
- **THEN** the hero's eyebrow and title start below the tab bar and the Antenna mark

### Requirement: Empty and error states share one layout
Every empty, unavailable and error state MUST use one layout: a symbol, a
title in the title style for the platform, a message in body, and up to two
actions in system button styles, the first of which moves the user forward.
A screen MUST show one such state at a time.

#### Scenario: No channels on Apple TV
- **GIVEN** every source loaded without channels
- **WHEN** Live opens on Apple TV
- **THEN** it shows a symbol, "No channels yet", a line per source, and Open Settings and Try again as buttons

#### Scenario: Two states at once
- **WHEN** a reviewer finds an empty player placeholder and a separate error message on the same screen
- **THEN** it fails this requirement

## MODIFIED Requirements

### Requirement: Focus is the lifted white card
On Apple TV the focused element MUST use the system focus effect for its
control: the light platter with dark text, the lift, the shadow and the
motion that follows the remote, from bordered and glass buttons, list rows
and card buttons, and the highlight hover effect on images. The parts the
reference lists as drawn by the app use the same light card with dark text
and shadow and add the highlight hover effect for motion. Text inside a
focused system row MUST take the row's focused colors and stay readable.
Accent borders, white rings and focus shown by scale alone are not allowed,
and nothing other than the focused element is filled white.

#### Scenario: Moving focus down a list
- **WHEN** the viewer moves focus to a row on Apple TV
- **THEN** that row becomes a light card with dark text and a shadow, and it tilts slightly as the viewer rests a thumb on the remote
- **AND** no other element on screen is filled white

#### Scenario: Focus without the card
- **WHEN** a reviewer finds a focused element shown only by a colored border, a white ring or a size change
- **THEN** it fails this requirement

#### Scenario: Text that vanishes on focus
- **WHEN** a reviewer focuses a Settings row on Apple TV
- **THEN** its title and value are dark on the light platter, never light text on light

#### Scenario: An element that only holds focus
- **GIVEN** the full-screen picture, a loading screen, or a screen whose only content is a line of text
- **WHEN** it has focus on Apple TV
- **THEN** it shows no card and no other focus effect, because there is nothing on it to lift

### Requirement: One accent color
The accent blue from the reference MUST be the only accent color and MUST be
the app's tint, so system controls draw with it. It SHALL appear only on
progress fills, the guide's now line, the NOW and UP NEXT badges, links, the
selected iPhone tab, and system controls that tint by default (the
prominent button on iPhone, iPad and Mac, switches, and selected picker
values). Eyebrows, titles, icons and decoration are not tinted.

#### Scenario: A tinted icon
- **WHEN** a reviewer finds an icon or label tinted in a color other than the accent
- **THEN** it fails this requirement

#### Scenario: Accent on a decorative element
- **WHEN** the accent appears on something that is not progress, the now line, a NOW or UP NEXT badge, a link, the selected iPhone tab or a system control's tint
- **THEN** it fails this requirement

#### Scenario: An eyebrow over a title
- **WHEN** a reviewer finds an eyebrow such as "RECENTLY ADDED" or "SERIES" in the accent
- **THEN** it fails this requirement

#### Scenario: Connect on iPhone
- **WHEN** the add-source sheet shows on iPhone
- **THEN** Connect is the prominent system button in the accent tint

### Requirement: Text stays above the platform caption floor
Text MUST never be smaller than the platform's caption minimum in the
reference type scale: 23 pt on Apple TV, 13 pt on iPad and Mac, 12 pt on
iPhone.

#### Scenario: Small metadata on Apple TV
- **WHEN** a screen on Apple TV shows a caption, a footnote or legal text
- **THEN** it is at least 23 pt

#### Scenario: Small metadata on iPhone
- **WHEN** a screen on iPhone shows a caption
- **THEN** it is at least 12 pt
