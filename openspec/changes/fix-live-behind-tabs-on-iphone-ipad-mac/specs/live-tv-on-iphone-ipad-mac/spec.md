## ADDED Requirements

### Requirement: The channel pauses behind Movies, Series and Search
The system SHALL pause the channel as soon as Movies, Series or Search opens on iPhone, iPad or Mac, and SHALL stop the stream after 30 seconds there. Going back to Live or the Guide SHALL play a paused channel on, and SHALL tune a stopped one again at live. A channel in Picture in Picture or on AirPlay SHALL keep playing.

#### Scenario: Opening Movies
- **GIVEN** a channel is playing on Live
- **WHEN** the user opens Movies, Series or Search
- **THEN** the channel pauses at once and no sound plays behind the tab

#### Scenario: Back before 30 seconds
- **GIVEN** Movies, Series or Search has been open less than 30 seconds
- **WHEN** the user goes back to Live or the Guide
- **THEN** the channel plays on from where it paused, without loading again

#### Scenario: Thirty seconds behind a tab
- **GIVEN** Movies, Series or Search has been open for 30 seconds
- **WHEN** the user goes back to Live or the Guide
- **THEN** the stream was stopped while they browsed, and the channel tunes again at live

#### Scenario: Moving between tabs
- **GIVEN** Movies was opened from Live less than 30 seconds ago
- **WHEN** the user moves on to Series, Search or Settings
- **THEN** the channel stays paused and the 30 seconds keep counting from when Movies opened

#### Scenario: Guide and Settings
- **GIVEN** a channel is playing on Live
- **WHEN** the user opens the Guide or Settings
- **THEN** the channel plays on, as before

#### Scenario: Picture in Picture
- **GIVEN** a channel plays in the Picture in Picture window
- **WHEN** the user opens Movies, Series or Search
- **THEN** the channel keeps playing in the window and is not stopped after 30 seconds

#### Scenario: Back from Picture in Picture on Movies
- **GIVEN** a channel plays in the Picture in Picture window while Movies is open
- **WHEN** the user brings the picture back into the app
- **THEN** the channel pauses, as if Movies had just opened

#### Scenario: AirPlay
- **GIVEN** a channel plays on an AirPlay device
- **WHEN** the user opens Movies, Series or Search
- **THEN** the channel keeps playing on that device

#### Scenario: A channel still loading
- **GIVEN** a channel is still loading when the user opens Movies, Series or Search
- **WHEN** it finishes loading
- **THEN** it stays paused until the user goes back to Live or the Guide

#### Scenario: Paused by the user
- **GIVEN** the user paused the channel, or it failed
- **WHEN** they open Movies and later go back to Live
- **THEN** the channel is neither stopped nor played, and stays as they left it

#### Scenario: Multi-view on iPad or Mac
- **GIVEN** multi-view is open with several tiles
- **WHEN** the user opens Movies, Series or Search from the sidebar or the Go menu
- **THEN** multi-view ends, every other tile stops, and the selected tile's channel pauses
- **AND** going back to Live shows that channel on its own

#### Scenario: Full screen on iPad or Mac
- **GIVEN** the picture fills the window
- **WHEN** the user opens Movies, Series or Search from the Go menu
- **THEN** the window leaves full screen, shows that section, and the channel pauses

#### Scenario: Leaving the app behind Movies
- **GIVEN** the channel is paused or stopped behind Movies, Series or Search
- **WHEN** the user leaves the app and comes back
- **THEN** nothing plays in the background or on return until the user goes back to Live or the Guide
