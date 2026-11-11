# Spec Delta

## MODIFIED Requirements

### Requirement: The tabs, in order
The system SHALL show a tab bar holding, from left to right, the Antenna mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, with exactly one tab marked as the current one. Movies and Series SHALL appear whenever the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet.

#### Scenario: Sources with movies
- **GIVEN** the user has at least one Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds the mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, in that order, with exactly one tab marked current

#### Scenario: No Xtream source
- **GIVEN** the user has no Xtream source
- **WHEN** the tab bar shows
- **THEN** neither Movies nor Series appears

#### Scenario: Bar over the Guide
- **GIVEN** the Guide is open
- **WHEN** the tab bar shows over it
- **THEN** the bar leaves the clock's place empty, because the Guide shows its own clock

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the tab bar shows
- **THEN** it is read as a group of tabs, and the clock and the mark as plain text

### Requirement: Stand-in screens
The system SHALL show one line in place of each screen not built yet: "The programme guide is not available yet." on Guide, with the picture in a 480 by 270 box at the top left and the Guide's own clock, and "Search is not available yet." under the tab bar on Search. Movies and Series show their own sections.

#### Scenario: Opening the Guide
- **GIVEN** a channel is playing
- **WHEN** the user opens the Guide
- **THEN** the picture keeps playing in the small box, the clock shows top right and the stand-in line holds the highlight

#### Scenario: Opening Search
- **GIVEN** the tab bar shows
- **WHEN** the user selects Search
- **THEN** "Search is not available yet." shows under the bar and holds the highlight, and the picture is hidden

#### Scenario: Opening Movies
- **GIVEN** the tab bar shows and the user has an Xtream source
- **WHEN** the user selects Movies
- **THEN** the Movies section shows under the bar instead of a stand-in line, the highlight moves into it, and the picture is hidden
