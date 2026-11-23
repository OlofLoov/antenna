## MODIFIED Requirements

### Requirement: Back to the last channel on launch
The system SHALL play the current profile's last channel on this Apple TV full screen at launch, after the "Who's watching?" screen when there is one: at once when it was saved for launch, otherwise once its source has loaded. If it no longer exists, its source failed, or its source has not loaded within 10 seconds, the first channel of the first source to finish with channels SHALL play instead. The last channel is kept per profile on this Apple TV only, never synced. When the profile's last watch on this Apple TV was a movie or an episode, the system SHALL open the title's page instead, with the channel loaded paused behind it, unless the title cannot open.

#### Scenario: Last channel available
- **GIVEN** the current profile watched a channel on this Apple TV, with no movie or episode after it
- **WHEN** they open Antenna and its source has loaded
- **THEN** that channel plays full screen

#### Scenario: Saved for launch
- **GIVEN** the current profile's last channel was saved for launch and its source's list takes 20 seconds to load
- **WHEN** they open Antenna
- **THEN** that channel starts full screen before the list loads, and the 10 seconds do not apply to it

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
- **GIVEN** a remembered channel whose source finishes after 10 seconds, no source with channels before it, and the channel was not saved for launch
- **WHEN** that source finishes
- **THEN** its first channel plays, not the remembered one

#### Scenario: What is remembered
- **GIVEN** a channel the user tunes
- **WHEN** its stream loads
- **THEN** it becomes the current profile's last channel; a stream that fails to load leaves the last channel as it was

#### Scenario: Last watched an M3U channel
- **GIVEN** the last channel watched on this Apple TV came from an M3U playlist
- **WHEN** the user opens Antenna
- **THEN** that channel plays full screen, the stored last channel holds no stream link, and what was saved for launch holds no username or password

#### Scenario: Last watched an M3U channel with a stream link in its id
- **GIVEN** a last channel stored by an earlier version whose id contains a stream link
- **WHEN** the user opens Antenna
- **THEN** that channel is not remembered, the first channel of the first source to load plays instead, and no error is shown

#### Scenario: Unreadable last channel
- **GIVEN** the stored last channel cannot be read
- **WHEN** the user opens Antenna
- **THEN** it counts as nothing remembered

#### Scenario: Last watched a movie or an episode
- **GIVEN** the current profile's last watch on this Apple TV was a movie or an episode that its section lists within 10 seconds
- **WHEN** they open Antenna
- **THEN** the title's page opens with Resume focused, the last channel loads paused behind it, and it plays when the user goes to Live

#### Scenario: The title cannot open
- **GIVEN** the current profile's last watch was a movie or an episode that is gone, whose source failed, or that is not listed within 10 seconds
- **WHEN** they open Antenna
- **THEN** the last channel plays full screen as when the last watch was a channel, or the first channel of the first source to load
