## MODIFIED Requirements

### Requirement: The tabs, in order
The system SHALL show the system tab bar holding, from left to right, Live, Guide, Movies, Series, Search and Settings, with exactly one tab marked as the current one. Movies and Series SHALL appear whenever the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet, and for a playlist with movies or episodes as the M3U playlist capability describes.

#### Scenario: Sources with movies
- **GIVEN** the user has at least one Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds Live, Guide, Movies, Series, Search and Settings, in that order, with exactly one tab marked current

#### Scenario: No Xtream source
- **GIVEN** the user has no Xtream source and no playlist whose last load had movies or episodes
- **WHEN** the tab bar shows
- **THEN** neither Movies nor Series appears

#### Scenario: Two or more profiles
- **GIVEN** the profiles Dad and Kids, with Kids current
- **WHEN** Settings opens
- **THEN** a profile button with Kids's color and initial sits at the top of Settings
- **AND** with one profile there is no profile button

#### Scenario: Bar over the Guide
- **GIVEN** the Guide is open
- **WHEN** the tab bar shows over it
- **THEN** the Guide's own clock stays in its header, since the bar holds no clock

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the tab bar shows
- **THEN** it is read as the system tab bar, one tab per item

### Requirement: Open Settings
The system SHALL open Settings as the last tab without touching the video when the user selects it.

#### Scenario: Settings button
- **GIVEN** the tab bar shows
- **WHEN** the user selects Settings
- **THEN** Settings opens, listing the sources and the way to add one, and the video is not touched

#### Scenario: Closing Settings
- **GIVEN** Settings is open
- **WHEN** the user presses Menu
- **THEN** the highlight moves to Settings in the tab bar

### Requirement: Deviations from the design rules
The loading screen SHALL mark a finished source with a check on an accent circle, as its board draws it. This departs from the one-accent design rule.

#### Scenario: Focus in a tab's content
- **GIVEN** Movies is open and the highlight is in its content
- **WHEN** the tab bar shows
- **THEN** the system bar marks Movies as the current tab in its own style, with no fill the app draws

#### Scenario: A finished source on the loading screen
- **GIVEN** the loading screen shows a source that finished
- **WHEN** the user looks at its row
- **THEN** it has a check on an accent circle, where a loading source has a turning ring and a failed one has nothing

### Requirement: The tab bar sits in the same place on every tab
The system SHALL show the system tab bar at the same place along the top on every tab. Over the Guide the bar SHALL leave the small picture uncovered.

#### Scenario: Over the picture and over Movies
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses Menu, and later opens Movies
- **THEN** the bar is at the same place both times

#### Scenario: With a profile button
- **GIVEN** the profiles Dad and Kids
- **WHEN** the tab bar shows
- **THEN** it holds the tabs alone, and the profile button sits at the top of Settings

#### Scenario: Over the Guide
- **GIVEN** the Guide is open with a channel in the small picture
- **WHEN** the user presses Menu and the bar shows over the guide
- **THEN** the small picture starts below the bar
