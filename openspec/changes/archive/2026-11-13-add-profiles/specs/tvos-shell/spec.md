## MODIFIED Requirements

### Requirement: The tabs, in order
The system SHALL show a tab bar holding, from left to right, the Antenna mark, Live, Guide, Movies, Series, Search, the profile button when there are two or more profiles, the Settings button and the clock, with exactly one tab marked as the current one. Movies and Series SHALL appear whenever the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet, and for a playlist with movies or episodes as the M3U playlist capability describes.

#### Scenario: Sources with movies
- **GIVEN** the user has at least one Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds the mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, in that order, with exactly one tab marked current

#### Scenario: No Xtream source
- **GIVEN** the user has no Xtream source and no playlist whose last load had movies or episodes
- **WHEN** the tab bar shows
- **THEN** neither Movies nor Series appears

#### Scenario: Two or more profiles
- **GIVEN** the profiles Dad and Kids, with Kids current
- **WHEN** the tab bar shows
- **THEN** a profile button with Kids's color and initial sits between Search and the Settings button
- **AND** with one profile there is no profile button

#### Scenario: Bar over the Guide
- **GIVEN** the Guide is open
- **WHEN** the tab bar shows over it
- **THEN** the bar leaves the clock's place empty, because the Guide shows its own clock

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the tab bar shows
- **THEN** it is read as a group of tabs, the profile button as "Profile, Kids", and the clock and the mark as plain text

### Requirement: Back to the last channel on launch
The system SHALL play the current profile's last channel on this Apple TV full screen at launch, after the "Who's watching?" screen when there is one, once its source has loaded. If it no longer exists, its source failed, or its source has not loaded within 10 seconds, the first channel of the first source to finish with channels SHALL play instead. The last channel is kept per profile on this Apple TV only, never synced.

#### Scenario: Last channel available
- **GIVEN** the current profile watched a channel on this Apple TV before
- **WHEN** they open Antenna and its source has loaded
- **THEN** that channel plays full screen

#### Scenario: Another profile's last channel
- **GIVEN** Dad last watched News 24 on this Apple TV and Kids has watched nothing here
- **WHEN** Kids is chosen at launch
- **THEN** the first channel of the first source to load plays, not News 24

#### Scenario: Last channel gone or late
- **GIVEN** the last channel no longer exists, or its source has not loaded within 10 seconds
- **WHEN** the user opens Antenna
- **THEN** the first channel of the first source to load plays instead

#### Scenario: Later sources and coming back
- **GIVEN** a channel is already playing
- **WHEN** another source finishes loading, or the app returns from the background
- **THEN** the channel does not change and is not loaded again

#### Scenario: A source with no channels
- **GIVEN** nothing remembered, and a source that finishes first with no channels
- **WHEN** a second source finishes with channels
- **THEN** the second source's first channel plays

#### Scenario: Remembered source later than 10 seconds
- **GIVEN** a remembered channel whose source finishes after 10 seconds, and no source with channels before it
- **WHEN** that source finishes
- **THEN** its first channel plays, not the remembered one

#### Scenario: What is remembered
- **GIVEN** a channel the user tunes
- **WHEN** its stream loads
- **THEN** it becomes the current profile's last channel; a stream that fails to load leaves the last channel as it was

#### Scenario: Last watched an M3U channel with a stream link in its id
- **GIVEN** the last channel watched on this Apple TV came from an M3U playlist, whose ids hold the stream link
- **WHEN** the user opens Antenna
- **THEN** that channel was not remembered, and the first channel of the first source to finish with channels plays instead

#### Scenario: Unreadable last channel
- **GIVEN** the stored last channel cannot be read
- **WHEN** the user opens Antenna
- **THEN** it counts as nothing remembered
