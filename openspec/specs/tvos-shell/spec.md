# tvos-shell Specification

## Purpose
The frame every other Apple TV screen sits in. Opening the app goes straight to the channel last watched, full screen; Back dims the picture and shows a tab bar along the top, a swipe down goes back to the picture, and Back again goes to the Apple TV Home Screen. It serves the living-room viewer who wants "to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable", and the viewer who wants "the app to come back to the channel I was watching".

## Requirements

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

#### Scenario: Last watched an M3U channel
- **GIVEN** the last channel watched on this Apple TV came from an M3U playlist
- **WHEN** the user opens Antenna and the playlist has loaded
- **THEN** that channel plays full screen, and the stored last channel holds no stream link

#### Scenario: Last watched an M3U channel with a stream link in its id
- **GIVEN** a last channel stored by an earlier version whose id contains a stream link
- **WHEN** the user opens Antenna
- **THEN** that channel is not remembered, the first channel of the first source to load plays instead, and no error is shown

#### Scenario: Unreadable last channel
- **GIVEN** the stored last channel cannot be read
- **WHEN** the user opens Antenna
- **THEN** it counts as nothing remembered

### Requirement: Menu shows the tab bar over the picture
The system SHALL dim the picture and show the tab bar with Live highlighted when the user presses Menu over a full-screen channel with nothing else on screen, keeping the video playing, or failed.

#### Scenario: Menu over full screen
- **GIVEN** a channel is playing full screen with no overlay, info bar or channel-number box showing
- **WHEN** the user presses Menu
- **THEN** the picture dims and keeps playing (or stays failed), and the tab bar shows with Live highlighted

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the user presses Menu over full screen
- **THEN** the dimming and the tab bar appear without animation

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

### Requirement: A loading screen at launch
The system SHALL show a loading screen on Live while no channel plays and at least one source is still loading, and before the sources are read at launch. It SHALL list each source by name with "Loading channels", its channel count, "Offline", "Could not load channels" or "Waiting for its login to sync from iCloud". Menu SHALL still reach the tab bar and Settings.

#### Scenario: Nothing loaded yet
- **GIVEN** the user has sources and none has finished loading
- **WHEN** they open Antenna
- **THEN** a loading screen lists each source by name with how far it has got, and Menu reaches the tab bar and Settings

#### Scenario: One source done, one still loading
- **GIVEN** one source finished with no channels and another is still loading
- **WHEN** Live is shown
- **THEN** the loading screen stays, the finished source reads "0 channels" and the other "Loading channels"

#### Scenario: Before the sources are read
- **GIVEN** the app has just launched and has not read the stored sources yet
- **WHEN** Live is shown
- **THEN** the loading screen shows, never the empty screen

#### Scenario: Late password
- **GIVEN** a source whose password or record arrives after launch
- **WHEN** the app returns to the foreground or the user presses Try again
- **THEN** a source waiting for its password loads once the password is on this Apple TV, and the loading screen never appears while a channel plays

### Requirement: An empty screen with Retry
The system SHALL show a "No channels yet" screen naming each source that added nothing and why ("no channels", "offline", "could not load its channels" or "waiting for its login to sync from iCloud"), once no source is loading and no channel plays, with Open Settings, focused first, and Try again. Try again SHALL load those sources again behind the loading screen and give the last channel another 10 seconds.

#### Scenario: Nothing to play
- **GIVEN** every source has finished, failed or is waiting for its password, and none has any channels
- **WHEN** Live is shown
- **THEN** "No channels yet" names each source and why, with Open Settings focused and Try again beside it
- **AND** Open Settings opens Sources and Settings, Try again loads the sources again and shows the loading screen, and Menu shows the tab bar

#### Scenario: Offline at launch
- **GIVEN** the device is offline at launch
- **WHEN** every source fails
- **THEN** the empty screen shows each source as offline, with Open Settings and Try again as the ways on

#### Scenario: Offline compared with other failures
- **GIVEN** one source whose request fails because there is no connection or the connection dropped, and one that fails for any other reason
- **WHEN** both have finished
- **THEN** the first reads "offline" and the second "could not load its channels"

#### Scenario: No sources at all
- **GIVEN** the user has no sources
- **WHEN** Live is shown
- **THEN** "No channels yet" shows with no source lines, and Try again does nothing

### Requirement: Open Settings
The system SHALL open Settings over the current screen without touching the video when the user selects the Settings button.

#### Scenario: Settings button
- **GIVEN** the tab bar shows
- **WHEN** the user selects the Settings button
- **THEN** Settings opens full screen over what was there, listing the sources and the way to add one, and the video is not touched

#### Scenario: Closing Settings
- **GIVEN** Settings is open
- **WHEN** the user presses Menu
- **THEN** Settings closes and the highlight is back on the Settings button

### Requirement: Moving along the bar does not switch tabs
The system SHALL keep the current tab while the highlight moves along the bar, until the user selects a tab.

#### Scenario: Highlight on Search
- **GIVEN** the tab bar shows over the dimmed picture with Live highlighted
- **WHEN** the user moves the highlight to Search without pressing select
- **THEN** Live stays the current tab and the picture stays dimmed behind the bar

### Requirement: Other screens can send the user somewhere
The system SHALL let other screens send the user to Search, to the Guide at a given programme, or to Live after tuning, closing the channel overlay first.

#### Scenario: Requests from other screens
- **GIVEN** any tab or the channel overlay is showing
- **WHEN** another screen asks for Search, for the Guide at a given programme, or for Live after tuning
- **THEN** the overlay closes, that tab opens with the Guide told which programme to show, and Live is full screen with no tab bar

### Requirement: Sources change while the app runs
The system SHALL load a source that is added or edited while the shell runs and drop one that is removed. The channel playing SHALL keep playing when its source is removed, unless every source is gone; then the video SHALL stop and Live SHALL show the empty screen. A source listed twice counts once.

#### Scenario: Every source removed
- **GIVEN** a channel is playing
- **WHEN** every source is removed, on this Apple TV or through sync
- **THEN** the video stops and Live shows "No channels yet"

#### Scenario: The playing channel's source removed
- **GIVEN** a channel is playing and another source remains
- **WHEN** the playing channel's source is removed
- **THEN** the channel keeps playing and its source drops off the loading and empty screens

### Requirement: Channel list over the picture
The system SHALL open the channel overlay over a dark scrim when the user presses select on the full-screen picture, highlighting the playing channel in the group the user last tuned from as the channel overlay describes. Selecting a row SHALL tune that channel and go back to full screen, and Menu SHALL close the list without changing channel.

#### Scenario: Changing channel
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses select, moves down one row and presses select
- **THEN** the list closes and the channel below the playing one plays full screen with no tab bar

#### Scenario: The channel already playing
- **GIVEN** the list is open
- **WHEN** the user selects the channel that is already playing
- **THEN** the list closes and the stream is not loaded again

### Requirement: Deviations from the design rules
The tab bar SHALL fill the open tab white while the highlight is in that tab's content, so the open tab stays visible, and SHALL put the tabs on the opaque tab bar color, because the dimmed picture shows through the scrim. The loading screen SHALL mark a finished source with a check on an accent circle, as its board draws it. These depart from the focus and one-accent design rules.

#### Scenario: Focus in a tab's content
- **GIVEN** Movies is open and the highlight is in its content
- **WHEN** the tab bar shows
- **THEN** the Movies tab is filled white with dark text, and once the highlight moves to another tab Movies falls back to a light gray fill

#### Scenario: A finished source on the loading screen
- **GIVEN** the loading screen shows a source that finished
- **WHEN** the user looks at its row
- **THEN** it has a check on an accent circle, where a loading source has a turning ring and a failed one has nothing

### Requirement: A file source waiting for iCloud
The system SHALL show an imported file source whose contents have not yet arrived on Apple TV as waiting for iCloud, where a source without its login shows as waiting for its login, and load its channels without a relaunch once they arrive.

#### Scenario: Contents arrive later
- **GIVEN** a file source synced to Apple TV without its contents yet
- **WHEN** the contents arrive through iCloud
- **THEN** the source stops showing as waiting for iCloud and its channels appear without a relaunch

### Requirement: Play or resume from a shelf link
The system SHALL tune a channel or resume a title named by a Top Shelf link, and hold a link that arrives before the shell is ready until the item's source loads within the launch deadline, replacing the last-channel tune with one load in total.

#### Scenario: A link at launch
- **GIVEN** Antenna is not running and its last channel is 7
- **WHEN** the user selects the shelf tile for channel 104
- **THEN** channel 104 plays once its source loads, and channel 7 is never loaded

#### Scenario: A link while running
- **GIVEN** Antenna is running on any screen
- **WHEN** a shelf link for a channel arrives
- **THEN** the channel plays as it would after going to live TV

#### Scenario: A link that does not resolve
- **GIVEN** a shelf link whose channel's source does not load within the launch deadline, or whose channel no longer exists
- **WHEN** the link arrives
- **THEN** the link is dropped and Antenna launches or stays as it would without it

### Requirement: The tab bar stays hidden on a title page
The system SHALL hide the Apple TV tab bar and clock while a movie or series page is open, and swiping up from the page's top SHALL not reach the tab bar.

#### Scenario: Open a title page
- **GIVEN** the Movies tab on Apple TV
- **WHEN** the user opens a movie's page and swipes up from its topmost button
- **THEN** the tab bar and clock stay hidden and the page stays open

### Requirement: The shell hosts multi-view
The system SHALL show multi-view inside the Apple TV shell, and when multi-view ends it SHALL keep the surviving tile's player as the shell's playing channel rather than starting a new one.

#### Scenario: Leave multi-view inside the shell
- **GIVEN** multi-view open in the Apple TV shell with tile 2 highlighted
- **WHEN** the user presses Menu
- **THEN** tile 2's channel plays full screen without a reload and the tab bar stays hidden

### Requirement: The shell waits for the unlock
The system SHALL open the Apple TV shell, and tune any channel at launch, only once the app is unlocked, and SHALL show the paywall in its place until then.

#### Scenario: Launch without a purchase
- **GIVEN** an Apple TV with no purchase on its Apple Account and a source already synced
- **WHEN** the app launches
- **THEN** the paywall shows, the shell does not open and no channel is tuned

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

### Requirement: The tab bar sits in the same place on every tab
The system SHALL center the tabs on the screen's horizontal center, with the profile and Settings buttons to the right of the tabs, and SHALL show the bar at the same height along the top on Live, Guide, Movies, Series and Search. Over the Guide the bar SHALL leave the small picture uncovered.

#### Scenario: Over the picture and over Movies
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses Back, and later opens Movies
- **THEN** the tabs sit on the screen's center line both times, at the same height

#### Scenario: With a profile button
- **GIVEN** the profiles Dad and Kids
- **WHEN** the tab bar shows
- **THEN** the tabs stay on the center line and the profile and Settings buttons sit to their right

#### Scenario: Over the Guide
- **GIVEN** the Guide is open with a channel in the small picture
- **WHEN** the user presses Back and the bar shows over the guide
- **THEN** the bar is at the same height as on every other tab, and the small picture starts below it
