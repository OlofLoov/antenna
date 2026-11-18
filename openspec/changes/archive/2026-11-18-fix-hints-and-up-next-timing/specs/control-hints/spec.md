## MODIFIED Requirements

### Requirement: Hints fade and come back on a new screen
The system SHALL show the legend when the highlight reaches a new screen and fade it six seconds later. The info bar coming and going over the picture, and moving between the overlay's groups and channels, SHALL count as the same screen. A screen SHALL show its legend at most three times per launch, except on the first playback after a launch and on each move between Live, Movies and Series, which SHALL always show it. With Reduce Motion on, the legend SHALL appear and go without animation.

#### Scenario: Opening the guide
- **WHEN** the viewer opens the Guide
- **THEN** the guide's legend shows and fades six seconds later while the guide stays open

#### Scenario: Zapping
- **GIVEN** the legend on Live full screen has faded
- **WHEN** the viewer swipes down to the next channel and the info bar shows
- **THEN** the legend does not come back

#### Scenario: Back from the overlay
- **GIVEN** the viewer picked a channel from the overlay
- **WHEN** the picture is full screen again
- **THEN** the Live legend shows again, until it has shown three times since launch

#### Scenario: The first thing played
- **GIVEN** the app just launched and the viewer browsed Movies and a title page
- **WHEN** they play a movie
- **THEN** the player's legend shows and fades six seconds later

#### Scenario: Switching to another section
- **GIVEN** the Movies legend has shown three times since launch
- **WHEN** the viewer goes up to the tab bar and opens Series, then Movies again
- **THEN** the Series legend shows, then the Movies legend shows again, each fading six seconds later

#### Scenario: Back in the same section
- **GIVEN** the Movies legend has shown three times since launch
- **WHEN** the viewer opens a title page, plays the movie and goes back to the Movies rows
- **THEN** the Movies legend does not show again

#### Scenario: From the guide to Live
- **GIVEN** the Live legend has shown three times since launch
- **WHEN** the viewer picks a channel in the Guide
- **THEN** the Live legend does not show again, because the guide is part of Live
