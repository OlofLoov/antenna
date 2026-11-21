## MODIFIED Requirements

### Requirement: The channel pauses behind Movies, Series and Search
The system SHALL pause the channel as soon as Movies, Series, Search or Settings opens on iPhone, iPad or Mac, and SHALL stop the stream after 30 seconds there. Going back to Live or the Guide SHALL play a paused channel on, and SHALL tune a stopped one again at live. A channel in Picture in Picture or on AirPlay SHALL keep playing.

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
- **WHEN** the user opens the Guide, or Settings from the sidebar or the Go menu on iPad or Mac
- **THEN** the Guide plays the channel on, as before
- **AND** Settings pauses it at once, so no sound plays behind Settings, and going back to Live plays it on, or tunes it again at live after 30 seconds

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

### Requirement: Settings from the profile button
The system SHALL show a profile button at the top right of Live, the Guide, Movies and Series on iPhone and in a narrow iPad window, and SHALL open Settings from it as a sheet over the open tab. With two or more profiles the button SHALL show the current profile and open a menu with Switch profile and Settings. No channel SHALL play behind the sheet: it pauses the channel as the Settings section does, and closing the sheet SHALL treat the tab under it as opened again.

#### Scenario: Settings with one profile
- **GIVEN** one profile
- **WHEN** the user taps the profile button, a person glyph, on any of Live, the Guide, Movies or Series
- **THEN** Sources & Settings opens as a sheet over that tab, and Close goes back to the tab as it was

#### Scenario: Settings over Live
- **GIVEN** a channel is playing on Live
- **WHEN** the user opens Settings from the profile button
- **THEN** the channel pauses at once and no sound plays behind the sheet
- **AND** closing the sheet within 30 seconds plays the channel on without loading it again

#### Scenario: Settings left open
- **GIVEN** Settings has been open over Live or the Guide for 30 seconds
- **WHEN** the user closes it
- **THEN** the stream was stopped meanwhile, and the channel tunes again at live

#### Scenario: Settings over Movies
- **GIVEN** the channel is paused behind Movies
- **WHEN** the user opens Settings and closes it again
- **THEN** the channel stays paused, and the 30 seconds keep counting from when Movies opened

#### Scenario: Picture in Picture or AirPlay behind Settings
- **GIVEN** a channel plays in the Picture in Picture window or on an AirPlay device
- **WHEN** the user opens Settings
- **THEN** the channel keeps playing there and is not stopped after 30 seconds

#### Scenario: Settings does not change the tab the app opens on
- **GIVEN** the Guide is open
- **WHEN** the user opens Settings and leaves the app
- **THEN** the next launch opens on the Guide

#### Scenario: Settings with two or more profiles
- **GIVEN** the profiles Dad and Kids, with Kids current
- **WHEN** the user taps the profile button, a circle in Kids's color with its initial
- **THEN** a menu headed Kids offers Switch profile and Settings

#### Scenario: Nothing to watch yet
- **GIVEN** Live or the Guide shows a whole-screen message, such as no sources, a failed source or no connection
- **WHEN** the user looks for Settings
- **THEN** the profile button sits in the top right corner over the message

#### Scenario: A link to Settings
- **GIVEN** the empty or error state's Open Settings, or a reminder's Watch while Settings is open
- **WHEN** the user taps it
- **THEN** Open Settings opens the Settings sheet, and Watch closes the sheet and plays the channel in Live

#### Scenario: Right-to-left
- **GIVEN** the app in Arabic
- **WHEN** Live shows
- **THEN** the profile button sits at the left end of the group row

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the profile button is focused
- **THEN** it reads "Settings" with one profile, and "Profile, Kids" with Kids current among two or more
