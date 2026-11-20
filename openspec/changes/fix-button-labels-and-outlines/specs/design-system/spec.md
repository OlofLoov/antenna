## MODIFIED Requirements

### Requirement: Focus is the lifted white card
On Apple TV the focused element MUST use the system focus effect for its
control: the light platter with dark text, the lift, the shadow and the
motion that follows the remote. The parts the reference lists as drawn by
the app use the same light card with the highlight hover effect, in the
card's shape, on the focused element only. Text in a focused row MUST stay
readable. Accent borders, white rings and focus shown by scale alone are not
allowed, nothing other than the focused element is filled white, and an
element at rest MUST NOT show a rim or outline.

#### Scenario: Moving focus down a list
- **WHEN** the viewer moves focus to a row on Apple TV
- **THEN** that row becomes a light card with dark text and a shadow, and it tilts slightly as the viewer rests a thumb on the remote
- **AND** no other element on screen is filled white

#### Scenario: Rows at rest
- **GIVEN** the channel overlay is open on Apple TV with the highlight on a channel
- **WHEN** the viewer looks at the other channels, the groups, the programmes coming next and the buttons under them
- **THEN** none of them has a line around it

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

### Requirement: Controls use system styles
Buttons, toggles, pickers, text fields and lists MUST use a system style on
every platform: bordered, bordered prominent, glass, glass prominent,
borderless, or card on Apple TV. A screen MUST NOT draw its own fill, border
or focus look for a control. The only exceptions are the parts the reference
lists as drawn by the app: guide programme blocks, channel overlay rows, zap
bar sections, multi-view tiles and the passcode digits. A button MUST NOT be
an outline, and a button's meaning MUST NOT rest on a glyph whose meaning is
not clear to everyone, such as a plus for My list.

#### Scenario: A primary button on any platform
- **WHEN** a reviewer finds the main action of a screen, such as Connect, Start watching or Play
- **THEN** it uses the prominent system style for that platform and gets the platform's pressed and focused looks without code of its own

#### Scenario: A custom-drawn button
- **WHEN** a reviewer finds a button whose fill, border, scale or shadow is drawn by the app and it is not on the reference's exception list
- **THEN** it fails this requirement

#### Scenario: The channel overlay's buttons
- **WHEN** the channel overlay shows Watch, the favorite star and Add to multi-view on Apple TV
- **THEN** Watch looks like Watch in the Guide, and the star and Add to multi-view like More info on the Movies banner

#### Scenario: An outlined button
- **WHEN** a reviewer finds a button drawn as a line around its label, such as LIVE while behind live
- **THEN** it fails this requirement; the button is a system style or a plain surface instead

#### Scenario: A poster on Apple TV
- **WHEN** the viewer moves focus to a poster in a Movies or Series row
- **THEN** the poster lifts, grows and tilts with the remote the way posters do in the TV app, with no drawn ring
