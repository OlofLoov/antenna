## MODIFIED Requirements

### Requirement: Controls use system styles
Buttons, toggles, pickers, text fields and lists MUST use a system style on
every platform: bordered, bordered prominent, glass, glass prominent,
borderless, or card on Apple TV. A screen MUST NOT draw its own fill, border
or focus look for a control. The only exceptions are the parts the reference
lists as drawn by the app: guide programme blocks, channel overlay rows, zap
bar sections, multi-view tiles, the passcode digits and the expanded card on
Apple TV.

#### Scenario: A primary button on any platform
- **WHEN** a reviewer finds the main action of a screen, such as Connect, Start watching or Play
- **THEN** it uses the prominent system style for that platform and gets the platform's pressed and focused looks without code of its own

#### Scenario: A custom-drawn button
- **WHEN** a reviewer finds a button whose fill, border, scale or shadow is drawn by the app and it is not on the reference's exception list
- **THEN** it fails this requirement

#### Scenario: The channel overlay's buttons
- **WHEN** the channel overlay shows Watch, the favorite star and Add to multi-view on Apple TV
- **THEN** Watch looks like Watch in the Guide, and the star and Add to multi-view like More info on the Movies banner

#### Scenario: A glyph whose meaning is unclear
- **WHEN** a reviewer finds a button shown only by a glyph not everyone reads the same way, such as a plus for My list
- **THEN** it fails this requirement; the button says what it does in words

#### Scenario: An outlined button
- **WHEN** a reviewer finds a button drawn as a line around its label, such as LIVE while behind live
- **THEN** it fails this requirement; the button is a system style or a plain surface instead

#### Scenario: A poster on Apple TV
- **WHEN** the viewer moves focus to a poster in a genre grid or Search
- **THEN** the poster lifts, grows and tilts with the remote the way posters do in the TV app, with no drawn ring

#### Scenario: A poster that grows into its card on Apple TV
- **WHEN** the viewer moves focus to a poster in a Movies or Series row
- **THEN** the card it grows into lifts with a shadow around the whole card, with no drawn ring
- **AND** the poster's button under the card draws no focus look of its own
