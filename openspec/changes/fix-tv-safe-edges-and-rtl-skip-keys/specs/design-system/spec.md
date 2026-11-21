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

#### Scenario: Movies and Series
- **WHEN** the Movies or Series tab shows on Apple TV
- **THEN** the hero's copy and buttons, the preview's copy and the first card of each row start 80 pt from the left edge, over art that still runs to the edge

#### Scenario: Search
- **WHEN** the Search tab shows results or recent searches on Apple TV
- **THEN** they start 80 pt from the left edge and end 80 pt from the right edge

#### Scenario: Typing a channel number
- **WHEN** the viewer types a channel number on a keyboard on Apple TV
- **THEN** the number box sits 80 pt from the left edge and 60 pt from the top

#### Scenario: The paywall
- **WHEN** the paywall shows on Apple TV
- **THEN** the wordmark sits 80 pt from the left and 60 pt from the top, and the legal line ends 60 pt above the bottom edge

### Requirement: Progress runs in the reading direction
Every progress bar, the player scrubber and the timeshift bar MUST fill from
the leading edge, so in a right-to-left language they fill from the right.
The digits inside a time or number MUST keep their order. The left and right
arrow keys and the Siri Remote's left and right MUST skip toward the end of
the bar they point at, so in a right-to-left language right skips back and
left skips forward, on the keyboard and in the Playback menu.

#### Scenario: A programme's progress in Arabic
- **GIVEN** the app is in Arabic and a programme is half over
- **WHEN** its channel row is shown
- **THEN** the right half of the bar is filled

#### Scenario: The scrubber in Arabic
- **GIVEN** the app is in Arabic and the viewer is behind live
- **WHEN** the player controls show
- **THEN** the start time is at the right, the live edge at the left, and dragging toward the left moves forward in time

#### Scenario: The arrow keys in Arabic
- **GIVEN** the app is in Arabic and a movie is playing on iPhone, iPad or Mac with a keyboard
- **WHEN** the viewer presses Left Arrow
- **THEN** the movie skips forward 10 seconds, toward the left end of the bar
- **AND** Right Arrow skips back 10 seconds, and on Live with timeshift Right skips back 15 seconds and Left forward 30

#### Scenario: The Playback menu in Arabic
- **GIVEN** the app is in Arabic on a Mac or an iPad with a keyboard
- **WHEN** the viewer opens the Playback menu
- **THEN** Back is listed with Right Arrow and Forward with Left Arrow

#### Scenario: The Siri Remote in Arabic
- **GIVEN** the app is in Arabic on Apple TV and the controls of a movie or of paused live TV show
- **WHEN** the viewer clicks the right side of the touch surface
- **THEN** the picture skips back, toward the right end of the bar
