# Spec Delta

## ADDED Requirements

### Requirement: Layouts mirror in right-to-left languages
In a right-to-left language every screen MUST mirror its horizontal layout:
what sits at the leading edge in English sits at the right edge, rows and
chips run from the right, and back and disclosure arrows point the other
way. Photos, posters, channel logos and the video picture MUST NOT be
flipped.

#### Scenario: A channel row in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the viewer opens the Live list on any platform
- **THEN** each row reads from the right: channel number, logo tile, name, current programme and progress bar
- **AND** the catch-up glyph sits at the row's left edge

#### Scenario: Group chips in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer looks at the group chips above the Live list
- **THEN** the first chip is at the right and the chips scroll toward the left

#### Scenario: A channel logo with text in it
- **GIVEN** the app is in Arabic
- **WHEN** a channel logo that contains Latin letters is shown
- **THEN** the logo is drawn as supplied, not mirrored

#### Scenario: The Apple TV channel overlay
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens the channel overlay
- **THEN** the groups column is at the right, the channels in the middle and now and next at the left

### Requirement: Progress runs in the reading direction
Every progress bar, the player scrubber and the timeshift bar MUST fill from
the leading edge, so in a right-to-left language they fill from the right.
The digits inside a time or number MUST keep their order.

#### Scenario: A programme's progress in Arabic
- **GIVEN** the app is in Arabic and a programme is half over
- **WHEN** its channel row is shown
- **THEN** the right half of the bar is filled

#### Scenario: The scrubber in Arabic
- **GIVEN** the app is in Arabic and the viewer is behind live
- **WHEN** the player controls show
- **THEN** the start time is at the right, the live edge at the left, and dragging toward the left moves forward in time

### Requirement: The guide's time axis follows the reading direction
In a right-to-left language the guide grid MUST place the channel column at
the right edge and run time from right to left: earlier programmes to the
right, later ones to the left, with the now line moving left as time
passes. The iPhone guide's programme strips MUST run the same way.

#### Scenario: The Apple TV guide in Arabic
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens the guide
- **THEN** the channel column is at the right, the programme on now sits next to it, and later programmes follow to the left

#### Scenario: The iPhone guide in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer scrolls a channel's programme strip
- **THEN** the current programme is at the right and later programmes come in from the left

#### Scenario: The guide in English
- **WHEN** the app is in a left-to-right language
- **THEN** the guide keeps the channel column at the left and time running to the right, as today

### Requirement: Playback glyphs keep their meaning
Play, pause, Picture in Picture, AirPlay and track glyphs MUST NOT flip. In
a right-to-left language the skip back and skip forward buttons MUST swap
sides so skip back is on the right, and each MUST keep the glyph that shows
its time direction.

#### Scenario: The player strip in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the player controls show on iPhone, iPad or Mac
- **THEN** the play triangle points right as in English
- **AND** skip back sits to the right of play and skip forward to its left

### Requirement: Focus moves where the remote points
On Apple TV a swipe or click MUST move focus to the element drawn in that
direction on screen, in every language. In a right-to-left language the
first focus on a screen MUST land on the rightmost element of the first row.

#### Scenario: Moving through the guide in Arabic
- **GIVEN** the app is in Arabic and focus is on the programme on now in the guide
- **WHEN** the viewer swipes left
- **THEN** focus moves to the next programme, which is drawn to the left

#### Scenario: First focus in Arabic
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens Movies
- **THEN** focus starts on the rightmost poster of the first row

### Requirement: Copy fits in every language
App copy MUST fit its control or line in every shipped language at the
default text size: a label wraps or the layout grows, and it MUST NOT be
cut off with an ellipsis where the English is not. Text MUST NOT shrink
below the platform caption floor to fit. Badges are uppercase only in
scripts that have case.

#### Scenario: A long German button
- **GIVEN** the app is in German
- **WHEN** the paywall shows its restore and purchase buttons
- **THEN** each label is shown in full

#### Scenario: An Arabic badge
- **GIVEN** the app is in Arabic
- **WHEN** a channel with catch-up shows its badge
- **THEN** the badge text is in Arabic, in the badge outline, at least as large as the platform caption floor
