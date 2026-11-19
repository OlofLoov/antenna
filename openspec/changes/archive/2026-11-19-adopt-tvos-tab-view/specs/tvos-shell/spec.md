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

### Requirement: Back to full screen from the tab bar
The system SHALL hide the tab bar and carry on with the same stream full screen when the user swipes down or selects Live from the bar over the dimmed picture. Selecting Live SHALL load a failed stream again. Back from the bar goes to the Home Screen instead.

#### Scenario: Menu, swipe down or Live
- **GIVEN** the tab bar shows over the dimmed picture
- **WHEN** the user swipes down, or selects Live
- **THEN** the tab bar goes away and the same stream carries on full screen
- **AND** pressing Menu there instead opens the Apple TV Home Screen

#### Scenario: Swipe down over Movies, Series or Search
- **GIVEN** Movies, Series or Search is open with the highlight in the bar
- **WHEN** the user swipes down, or selects the open tab
- **THEN** the highlight moves into the tab's content and the system bar slides away
- **AND** on Search it lands on the keyboard

#### Scenario: Failed stream
- **GIVEN** the stream had failed
- **WHEN** the user selects Live
- **THEN** the stream is loaded again

### Requirement: Back from a tab goes to the tab bar
The system SHALL move the highlight to the open tab in the bar, keeping the tab open, when the user presses Back anywhere on the top level of Guide, Movies, Series, Search or Settings. Movies, Series and Search SHALL scroll back to their top as the highlight reaches the bar. A screen opened from a tab SHALL close on Back first. Swiping up from a page's top does not reach the system bar; Back does.

#### Scenario: Back from a lower row
- **GIVEN** Movies is open with the highlight on a poster four rows down
- **WHEN** the user presses Back
- **THEN** the rows scroll back to the top with the banner showing and the highlight moves to Movies in the tab bar
- **AND** a swipe down lands on the banner's Play button

#### Scenario: Back at the banner
- **GIVEN** Movies, Series or Search is open with the highlight on its topmost item
- **WHEN** the user presses Back
- **THEN** the highlight moves to that tab in the bar and the tab stays open

#### Scenario: Swipe up at the banner
- **GIVEN** Movies is open with the highlight on the banner's Play button
- **WHEN** the user swipes up
- **THEN** the highlight stays on Play and the bar stays hidden

#### Scenario: Back on the Guide
- **GIVEN** the Guide is open with the highlight in the grid
- **WHEN** the user presses Back
- **THEN** the bar appears over the guide with the highlight on Guide, and the guide keeps the programme that was highlighted

#### Scenario: Back from a genre grid
- **GIVEN** a genre grid opened from the Movies rows
- **WHEN** the user presses Back
- **THEN** the grid closes and the rows show with the highlight back on the banner, and the bar does not take the highlight

### Requirement: Back from the tab bar goes to the Home Screen
The system SHALL leave Back to Apple TV when the highlight is in the tab bar, on any tab including Settings, so it opens the Apple TV Home Screen whichever tab is open. The app SHALL come back to the same tab when the user opens it again.

#### Scenario: Back from the bar over Live
- **GIVEN** a channel is playing and the tab bar shows over the dimmed picture with Live highlighted
- **WHEN** the user presses Back
- **THEN** the Apple TV Home Screen opens

#### Scenario: Back from the bar over Movies
- **GIVEN** Movies is open with the highlight on Movies in the bar
- **WHEN** the user presses Back
- **THEN** the Apple TV Home Screen opens, and reopening the app shows Movies as it was

#### Scenario: Back from the bar over the Guide
- **GIVEN** the bar shows over the Guide with the highlight in it
- **WHEN** the user presses Back
- **THEN** the Apple TV Home Screen opens

## ADDED Requirements

### Requirement: The page follows the highlight in the tab bar
The system SHALL show the page of the tab the highlight rests on in the system tab bar, as the system bar does, and SHALL treat it as the open tab: passing over Movies, Series or Search pauses the video and coming back to Live or the Guide resumes it.

#### Scenario: Moving to Search
- **GIVEN** the tab bar shows over the dimmed picture with Live highlighted
- **WHEN** the user moves the highlight to Search without pressing select
- **THEN** Search shows under the bar as the open tab and the video pauses

#### Scenario: Back to Live along the bar
- **GIVEN** the highlight moved from Live to Search along the bar
- **WHEN** the user moves it back to Live
- **THEN** the same stream plays on, dimmed behind the bar, without loading again

## REMOVED Requirements

### Requirement: Moving along the bar does not switch tabs
**Reason**: The system tab bar on Apple TV opens a tab as the highlight lands on it, and the app cannot hold the page back.
**Migration**: "The page follows the highlight in the tab bar" describes what moving along the bar does now.
