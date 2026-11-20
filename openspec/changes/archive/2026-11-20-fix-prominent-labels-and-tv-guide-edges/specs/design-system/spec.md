## ADDED Requirements

### Requirement: Text on the accent is dark
Text and glyphs drawn on an accent fill MUST be the dark ground color, never
white: a prominent button's label, a picked chip, a NOW, UP NEXT or catch-up
badge, the now line's time tag and a check mark in an accent circle. The
dark label MUST reach 4.5:1 on each of the five accents. On Apple TV a
focused button keeps the system's light platter with dark text.

#### Scenario: Connect on iPhone
- **GIVEN** the current profile's accent is Blue
- **WHEN** the add-source sheet shows Connect
- **THEN** Connect is filled with the accent and its label is dark

#### Scenario: Every accent
- **WHEN** a reviewer measures the label of a prominent button on Blue, Teal, Amber, Pink or Violet
- **THEN** its contrast is at least 4.5:1

#### Scenario: A white label
- **WHEN** a reviewer finds white text or a white glyph on an accent fill on iPhone, iPad or Mac
- **THEN** it fails this requirement

#### Scenario: A picked chip
- **WHEN** the viewer picks a season or a genre chip on iPhone, iPad or Mac
- **THEN** the picked chip is filled with the accent and its name is dark

#### Scenario: Focus on Apple TV
- **WHEN** a button has focus on Apple TV
- **THEN** it is the light platter with dark text, as before

## MODIFIED Requirements

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

#### Scenario: The guide
- **WHEN** the Guide tab shows on Apple TV
- **THEN** the small picture and the channel column start 80 pt from the left edge, and the last half-hour column ends 80 pt from the right edge
