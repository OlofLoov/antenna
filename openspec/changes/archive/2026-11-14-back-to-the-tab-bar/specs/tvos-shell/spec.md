## ADDED Requirements

### Requirement: Back from a tab goes to the tab bar
The system SHALL move the highlight to the open tab in the bar, keeping the tab open, when the user presses Back anywhere on the top level of Guide, Movies, Series or Search, or swipes up from the topmost item on Movies, Series or Search. Movies, Series and Search SHALL scroll back to their top as the highlight reaches the bar. A screen opened from a tab SHALL close on Back first.

#### Scenario: Back from a lower row
- **GIVEN** Movies is open with the highlight on a poster four rows down
- **WHEN** the user presses Back
- **THEN** the rows scroll back to the top with the banner showing and the highlight moves to Movies in the tab bar
- **AND** a swipe down lands on the banner's Play button

#### Scenario: Back at the banner
- **GIVEN** Movies, Series or Search is open with the highlight on its topmost item
- **WHEN** the user presses Back, or swipes up
- **THEN** the highlight moves to that tab in the bar and the tab stays open

#### Scenario: Back on the Guide
- **GIVEN** the Guide is open with the highlight in the grid
- **WHEN** the user presses Back
- **THEN** the bar appears over the guide with the highlight on Guide, and the guide keeps the programme that was highlighted

#### Scenario: Back from a genre grid
- **GIVEN** a genre grid opened from the Movies rows
- **WHEN** the user presses Back
- **THEN** the grid closes and the rows show with the highlight back on the banner, and the bar does not take the highlight

### Requirement: Back from the tab bar goes to the Home Screen
The system SHALL leave Back to Apple TV when the highlight is in the tab bar, including on the profile and Settings buttons, so it opens the Apple TV Home Screen whichever tab is open. The app SHALL come back to the same tab when the user opens it again.

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

### Requirement: Back always leads out of the app
The system SHALL reach the Apple TV Home Screen when the user presses Back again and again from any screen in the shell: each layer or screen opened from a tab closes, then the bar takes the highlight, then the app leaves. No screen SHALL keep Back for itself, because a TV's own remote often has Back and arrows but no TV button.

#### Scenario: Repeated Back from Live
- **GIVEN** a channel is playing full screen with the channel overlay open
- **WHEN** the user presses Back three times
- **THEN** the first press closes the overlay, the second shows the tab bar, and the third opens the Apple TV Home Screen

#### Scenario: Repeated Back from a genre grid
- **GIVEN** a genre grid opened from the Movies rows
- **WHEN** the user presses Back three times
- **THEN** the grid closes, then the highlight moves to Movies in the bar, then the Apple TV Home Screen opens

## MODIFIED Requirements

### Requirement: Back to full screen from the tab bar
The system SHALL hide the tab bar and carry on with the same stream full screen when the user swipes down or selects Live from the bar over the dimmed picture. Selecting Live SHALL load a failed stream again. Back from the bar goes to the Home Screen instead.

#### Scenario: Menu, swipe down or Live
- **GIVEN** the tab bar shows over the dimmed picture
- **WHEN** the user swipes down, or selects Live
- **THEN** the tab bar goes away and the same stream carries on full screen
- **AND** pressing Menu there instead opens the Apple TV Home Screen

#### Scenario: Swipe down over Movies, Series or Search
- **GIVEN** Movies, Series or Search is open with the highlight in the bar
- **WHEN** the user swipes down
- **THEN** the bar stays and the highlight moves into the tab's content

#### Scenario: Failed stream
- **GIVEN** the stream had failed
- **WHEN** the user selects Live
- **THEN** the stream is loaded again

## REMOVED Requirements

### Requirement: Menu from the top of a tab reaches the tab bar
**Reason**: Back reaches the bar from anywhere on a tab's top level, not only its top, and the tab scrolls back to its top.
**Migration**: "Back from a tab goes to the tab bar" describes it.

### Requirement: Menu from the tab bar goes back to Live
**Reason**: Apple's Human Interface Guidelines make the Home Screen the parent of an app's top level, and the tab bar is that top level. Back from the bar went to Live, and Back on Live went to the bar, so Back never left the app.
**Migration**: "Back from the tab bar goes to the Home Screen" describes Back in the bar. Selecting Live or swiping down still returns to the picture, and a video paused behind Movies, Series or Search resumes when Live is selected.
