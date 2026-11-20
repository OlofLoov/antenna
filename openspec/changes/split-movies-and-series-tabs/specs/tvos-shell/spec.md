## MODIFIED Requirements

### Requirement: The tabs, in order
The system SHALL show the system tab bar holding, from left to right, Live, Guide, Movies, Series, Search and Settings, with exactly one tab marked as the current one and Search drawn as the system's search tab, a magnifying glass. Movies and Series SHALL appear whenever the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet, and for a playlist with movies or episodes as the M3U playlist capability describes.

#### Scenario: Sources with movies
- **GIVEN** the user has at least one Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds Live, Guide, Movies, Series, Search and Settings, in that order, with exactly one tab marked current

#### Scenario: Search is the search tab
- **GIVEN** the tab bar shows
- **WHEN** the user looks at the tab after Series
- **THEN** it is drawn as a magnifying glass, and selecting it opens Search ready to type

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
- **THEN** it is read as the system tab bar, one tab per item, and the search tab reads "Search"
