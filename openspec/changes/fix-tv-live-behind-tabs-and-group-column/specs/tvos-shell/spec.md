## MODIFIED Requirements

### Requirement: The video pauses behind Movies, Series and Search
The system SHALL pause the video as soon as Movies, Series or Search opens from Live or Guide, so no sound plays behind them. After 30 seconds there it SHALL stop the stream, which frees the provider's connection. Going back to Live or Guide SHALL resume a paused video from where it was, and SHALL tune a stopped one again at live. A video the user paused themselves stays paused and is not stopped.

#### Scenario: Opening a tab
- **GIVEN** a channel is playing on Live or in the Guide
- **WHEN** the user opens Movies, Series or Search
- **THEN** the video pauses at once and no sound plays behind the tab

#### Scenario: Back before 30 seconds
- **GIVEN** Movies, Series or Search has been open less than 30 seconds
- **WHEN** the user goes back to Live or Guide
- **THEN** the video plays on from where it paused, without loading the channel again

#### Scenario: Thirty seconds behind a tab
- **GIVEN** Movies, Series or Search has been open for 30 seconds
- **WHEN** the user goes back to Live or Guide
- **THEN** the stream was stopped while they browsed, and the channel tunes again at live

#### Scenario: Moving between Movies, Series and Search
- **GIVEN** Movies was opened from Live less than 30 seconds ago
- **WHEN** the user moves on to Search or Series
- **THEN** the 30 seconds keep counting from when Movies opened

#### Scenario: A channel still loading
- **GIVEN** a channel is still loading when the user opens Movies, Series or Search
- **WHEN** it finishes loading
- **THEN** it stays paused until the user goes back to Live or Guide

#### Scenario: Video already stopped
- **GIVEN** the video is paused by the user, failed or idle when Movies, Series or Search opens
- **WHEN** the user later goes back to Live or Guide
- **THEN** the shell neither pauses, stops nor resumes it

#### Scenario: Back from the background while paused
- **GIVEN** the shell paused or stopped the video behind Movies, Series or Search
- **WHEN** the app returns from the background
- **THEN** nothing plays until the user goes back to Live or Guide
