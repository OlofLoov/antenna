# Spec Delta

## MODIFIED Requirements

### Requirement: The tabs, in order
The system SHALL show a tab bar holding, from left to right, the Antenna mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, with exactly one tab marked as the current one. Movies and Series SHALL appear whenever the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet, and for a playlist with movies or episodes as the M3U playlist capability describes.

#### Scenario: Sources with movies
- **GIVEN** the user has at least one Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds the mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, in that order, with exactly one tab marked current

#### Scenario: No Xtream source
- **GIVEN** the user has no Xtream source and no playlist whose last load had movies or episodes
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

## REMOVED Requirements

### Requirement: Stand-in screens
**Reason**: No tab shows a stand-in line any more. Guide shows the guide grid (`tv-guide-grid`), Search shows search (`search`), and Movies and Series show their own sections from this change.
**Migration**: Each tab's own capability describes what it shows: `tv-guide-grid`, `search` and `movies-and-series-browsing`.
