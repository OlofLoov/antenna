# live-tv-on-iphone-ipad-mac Specification

## Purpose
The Live TV screen for people who watch on an iPhone, iPad or Mac. They scroll and narrow their channels by group or by typing, and a channel plays in place while they keep browsing, with favorites as a group in the same list.

## Requirements

### Requirement: Sideways on iPhone fills the screen
The system SHALL show the playing channel full screen, with no tab bar and no channel line below the picture, whenever an iPhone is held sideways on Live with a channel playing, however it got there, and SHALL return to the list when the phone turns upright. A movie or episode that ends while Live is the open tab SHALL count as coming back to Live: the channel it stopped plays again, full screen when the phone is sideways.

#### Scenario: Turn sideways, then pick a channel
- **GIVEN** Live is open on an iPhone held sideways with no channel playing
- **WHEN** the user picks a channel
- **THEN** the picture fills the screen and the tab bar is gone

#### Scenario: Launch sideways
- **GIVEN** the last channel plays again at launch
- **WHEN** the app opens on Live with the iPhone held sideways
- **THEN** the picture fills the screen as soon as the channel plays

#### Scenario: Back to Live sideways
- **GIVEN** a channel plays and the iPhone is held sideways on another tab
- **WHEN** the user opens Live, or comes back to Live after a movie or episode
- **THEN** the picture fills the screen

#### Scenario: A movie from Siri over Live
- **GIVEN** a channel fills the screen on an iPhone held sideways
- **WHEN** Siri or a shortcut plays a movie and the user closes it, still holding the phone sideways
- **THEN** the channel plays again and the picture fills the screen

#### Scenario: Turn upright
- **GIVEN** the picture fills the screen because the iPhone is sideways
- **WHEN** the user turns the iPhone upright
- **THEN** the list, the tab bar and the channel line come back and the channel plays on without restarting

#### Scenario: Exit full screen while sideways
- **GIVEN** the picture fills the screen on an iPhone held sideways
- **WHEN** the user taps Exit full screen
- **THEN** the list shows sideways and the channel plays on
- **AND** picking or changing channel, or turning the phone upright and sideways again, fills the screen again

### Requirement: Every iPhone keeps the phone layout
The system SHALL show the tab bar layout on every iPhone in either orientation, including the larger models that report a wide screen when sideways, and SHALL keep choosing between the tab bar and the sidebar by window width on iPad and Mac.

#### Scenario: A large iPhone turned sideways
- **GIVEN** Live is open on an iPhone Plus or Pro Max
- **WHEN** the user turns it sideways
- **THEN** the phone layout stays, never the iPad sidebar, and a playing channel fills the screen

#### Scenario: iPad
- **GIVEN** Live is open on an iPad
- **WHEN** the window is wide
- **THEN** the sidebar layout shows as before

### Requirement: The full-screen channel line fades with the controls
The system SHALL show the playing channel's name and current programme at the top of the full-screen picture only while the player controls show, fading in and out with them.

#### Scenario: Controls hide
- **GIVEN** the picture fills the screen with the controls and channel line showing
- **WHEN** the controls hide after a few seconds without input
- **THEN** the channel line hides with them and only the picture is left

#### Scenario: Tap to bring them back
- **GIVEN** the picture fills the screen with nothing over it
- **WHEN** the user taps the picture
- **THEN** the controls and the channel line come back together

#### Scenario: A channel that fails
- **GIVEN** the picture fills the screen
- **WHEN** the channel fails
- **THEN** the error names the channel and stays until the user acts on it

### Requirement: Swipe on the picture to change channel
The system SHALL play the next channel in the open group when the user swipes up on the picture and the one before when they swipe down, wrapping at either end, on iPhone, iPad and Mac, also in full screen.

#### Scenario: Swipe up and down
- **GIVEN** a channel from the open group plays
- **WHEN** the user swipes up on the picture
- **THEN** the channel after it in the group plays, and after the last channel the first one plays
- **AND** swiping down plays the channel before it

#### Scenario: A channel outside the open group
- **GIVEN** the playing channel is not in the open group, as after picking it in Search
- **WHEN** the user swipes up or down on the picture
- **THEN** the next or previous channel in All channels plays

#### Scenario: Full screen stays
- **GIVEN** the picture fills the screen
- **WHEN** the user swipes to another channel
- **THEN** the new channel plays full screen

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on and the picture is selected
- **WHEN** the user picks the Channel up or Channel down action
- **THEN** the next or previous channel plays as with a swipe

### Requirement: Go back to the previous channel
The system SHALL offer a Previous channel button in the player controls that plays the channel watched before the current one, and pressing it again SHALL go back again, so the user can flip between two channels.

#### Scenario: Flip between two channels
- **GIVEN** the user watched one channel and then picked another
- **WHEN** they press Previous channel
- **THEN** the first channel plays
- **AND** pressing Previous channel again plays the second one

#### Scenario: After a relaunch
- **GIVEN** the app opened with the last channel playing again
- **WHEN** the user presses Previous channel
- **THEN** the most recent other channel in Recents plays

#### Scenario: No other channel
- **GIVEN** no other channel was watched and Recents holds no other channel
- **WHEN** the controls show
- **THEN** Previous channel is dimmed and does nothing

### Requirement: Double-tap to skip
The system SHALL skip 15 seconds back when the user double-taps the left half of the picture and 15 seconds forward on the right half while the channel can rewind, and SHALL show a short note instead when it cannot move.

#### Scenario: Skip back and forward
- **GIVEN** a channel that can rewind plays two minutes behind live
- **WHEN** the user double-taps the left half of the picture
- **THEN** the picture moves 15 seconds back
- **AND** a double-tap on the right half moves it 15 seconds forward

#### Scenario: Nothing to skip
- **GIVEN** a channel that cannot rewind, or one already at live for a skip forward
- **WHEN** the user double-taps the picture
- **THEN** the picture does not move and a short note says rewind is not available, or that it is already live

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on and the picture is selected
- **WHEN** the channel can rewind
- **THEN** Back 15 seconds and Forward 15 seconds are offered as actions on the picture

### Requirement: Sidebar, list and picture side by side
The system SHALL place the sidebar, the channel list and the picture side by side on an iPad or Mac window wide enough for the regular layout, fold the sidebar and then the list behind buttons as the window narrows, and SHALL NOT stack the list above or below the picture.

#### Scenario: A wide window
- **GIVEN** an iPad or Mac window wide enough for the regular layout
- **WHEN** the user opens Live
- **THEN** the sidebar with the app's sections and channel groups, the channel list and the picture sit side by side

#### Scenario: A narrower window
- **GIVEN** the window narrows on iPad or Mac
- **WHEN** Live is shown
- **THEN** the sidebar folds behind a button first, then the list
- **AND** the list is never stacked above or below the picture

#### Scenario: Nothing picked yet
- **GIVEN** no channel has been picked
- **WHEN** the user looks at the picture area
- **THEN** it says "Select a channel"

### Requirement: Picture pinned at the top on iPhone
The system SHALL show on iPhone, and on iPad in a narrow Split View, the picture across the top with the now-playing line, group chips and channel list below and the tab bar at the bottom, and switching layouts SHALL NOT interrupt the channel.

#### Scenario: The Live tab on iPhone
- **GIVEN** an iPhone, or an iPad in a narrow Split View
- **WHEN** the user opens the Live tab
- **THEN** the picture spans the width at the top, with the now-playing line, the group chips and the channel list below it and the tab bar at the bottom

#### Scenario: Switching between narrow and wide
- **GIVEN** a channel is playing
- **WHEN** the layout switches between narrow and wide
- **THEN** the channel is not interrupted

#### Scenario: Large text
- **GIVEN** the user has a large text size
- **WHEN** Live is shown on iPhone
- **THEN** the rows grow and the picture keeps its shape

#### Scenario: The chips sit under the line
- **GIVEN** an iPhone, with or without a channel playing
- **WHEN** Live is shown
- **THEN** the group chips sit right under the now-playing line, or under the picture area when nothing plays, and the channel list starts right under the chips, with no empty band above or below them

### Requirement: Pick a group
The system SHALL list the picked group's channels in channel-list order, keep the playing channel playing, and clear the filter, and on iPad and Mac SHALL head the list with the group's name and channel count. Empty Favorites SHALL say how a channel becomes a favorite on that device.

#### Scenario: Picking Sport
- **GIVEN** a group "Sport" with 42 channels
- **WHEN** the user picks it in the sidebar or taps its chip
- **THEN** the list shows those 42 channels in the catalogue's order
- **AND** the channel already playing keeps playing and the filter is cleared
- **AND** on iPad and Mac the list's header reads "Sport" and "42 channels"

#### Scenario: Empty Favorites
- **GIVEN** the user has no favorites
- **WHEN** they pick Favorites on an iPhone or iPad
- **THEN** the list says "No favorites yet. Touch and hold a channel, or swipe it right, to add it."

#### Scenario: Empty Favorites on a Mac
- **GIVEN** the user has no favorites
- **WHEN** they pick Favorites on a Mac
- **THEN** the list says "No favorites yet. Right-click a channel to add it."

#### Scenario: Tens of thousands of channels
- **GIVEN** the user has tens of thousands of channels
- **WHEN** they open a large group and scroll
- **THEN** the list opens and scrolls without stalling

#### Scenario: VoiceOver reads a row
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a channel row
- **THEN** it is read as name, number, programme and time left, and every control has a label

#### Scenario: A long group name
- **GIVEN** a group whose name and channel count do not fit on one line of the list's header, such as "Todos los canales" and "5 canales" in Spanish
- **WHEN** the list shows that group on iPad or Mac
- **THEN** the count moves under the name, and the name gets the header's full width

### Requirement: Watch without leaving the list
The system SHALL play a picked channel in place, highlight its row, keep the list on screen and usable, show that channel in the details, and SHALL NOT restart a channel that is already playing.

#### Scenario: Picking a channel
- **GIVEN** the channel list
- **WHEN** the user picks a channel
- **THEN** it plays in place and its row is highlighted
- **AND** the list stays on screen and usable, and the details show that channel

#### Scenario: Picking the playing channel
- **GIVEN** a channel is playing
- **WHEN** the user picks the same channel
- **THEN** it does not restart

### Requirement: Type to narrow the list
The system SHALL narrow the open group on iPad and Mac after every keystroke to channels whose name matches, or whose number starts with the typed digits, using Search's matching rules, and SHALL bring back the whole group when the field is cleared.

#### Scenario: Typing in the filter
- **GIVEN** a group is open on iPad or Mac
- **WHEN** the user types in the filter field
- **THEN** after every keystroke the list shows only the group's channels whose name matches, or whose number starts with the digits typed, matched the same way Search matches

#### Scenario: Clearing the filter
- **GIVEN** the filter holds text
- **WHEN** the user clears it
- **THEN** the whole group comes back

### Requirement: See what is on now and next
The system SHALL show for the playing channel the programme on now with its times and how far it has run, and what comes next: up to three programmes on iPad and Mac, one on iPhone.

#### Scenario: A programme on now
- **GIVEN** a channel is playing and the guide knows its current programme
- **WHEN** the user looks at the details on iPad and Mac, or the now-playing line on iPhone
- **THEN** they see the programme on now with its times and how far it has run
- **AND** what comes next, up to three programmes on iPad and Mac and one on iPhone

#### Scenario: Nothing in the guide
- **GIVEN** the guide has nothing for the playing channel
- **WHEN** the details or the now-playing line show
- **THEN** they read "No programme information"

#### Scenario: A programme ends
- **GIVEN** a programme ends while Live is open
- **WHEN** a few seconds pass
- **THEN** the details, the now-playing line and the list show the next programme

#### Scenario: A long title in a narrow panel
- **GIVEN** the details panel is too narrow for the programme title and its times on one line
- **WHEN** the panel shows the programme on now
- **THEN** the times move under the title, the title shows on up to two lines, and the times show whole

#### Scenario: Twelve-hour times
- **GIVEN** a region that writes times with AM and PM, such as "6:00 PM" or "7:30 p. m."
- **WHEN** the details list what comes next
- **THEN** each time stays on one line and the titles line up after the widest time

### Requirement: Player controls when you want them
The system SHALL show pause, programme progress, the time of day, a LIVE badge and full screen when the user taps, clicks or hovers over the picture, plus Picture in Picture on iPhone and iPad, and SHALL hide them after a few seconds without input unless paused.

#### Scenario: Showing the controls
- **GIVEN** a channel is playing in place
- **WHEN** the user taps or clicks the picture, or moves the pointer over it
- **THEN** pause, the programme's progress, the time of day, a LIVE badge and full screen appear
- **AND** on iPhone and iPad a Picture in Picture button appears, grayed out when the player cannot do it

#### Scenario: Controls go away
- **GIVEN** the controls are showing and the channel is playing
- **WHEN** a few seconds pass without input
- **THEN** the controls go away

#### Scenario: Paused
- **GIVEN** the channel is paused
- **WHEN** a few seconds pass without input
- **THEN** the controls stay

### Requirement: Star a channel
The system SHALL fill the star, add the channel to the Favorites group in favorite order and raise the Favorites count by one when the user taps the star on a channel that is not a favorite, and a second tap SHALL undo all three.

#### Scenario: Starring
- **GIVEN** a channel that is not a favorite
- **WHEN** the user taps the star next to it
- **THEN** the star fills, the channel appears in the Favorites group in favorite order, and the Favorites count in the sidebar goes up by one

#### Scenario: Unstarring
- **GIVEN** a channel the user just starred
- **WHEN** they tap the star again
- **THEN** the star empties, the channel leaves Favorites and the count goes down by one

#### Scenario: A change on another device
- **GIVEN** Live is open
- **WHEN** a favorite is added or removed on another device
- **THEN** the star and the Favorites group update without reopening Live

### Requirement: Keyboard shortcuts
The system SHALL move a focus ring between channels with the arrow keys without switching channel, play the focused channel on Return, pause and resume on Space outside a text field, jump to the filter on Command-F, and leave full screen on Escape.

#### Scenario: Keys with the list focused
- **GIVEN** a Mac, or an iPad with a keyboard
- **WHEN** the user presses keys while the list is focused
- **THEN** the up and down arrows move a focus ring between channels without switching channel
- **AND** Return plays the focused channel
- **AND** Space pauses and resumes outside a text field
- **AND** Command-F jumps to the filter, and Escape leaves full screen

#### Scenario: Holding an arrow key
- **GIVEN** the list is focused
- **WHEN** the user holds an arrow key
- **THEN** the focus scrolls through the list without switching channel

### Requirement: Full screen
The system SHALL fill the window, or the iPhone screen, with the picture and its controls on the full-screen button or when an iPhone turns sideways, and leaving full screen SHALL return to the list without restarting the channel.

#### Scenario: Entering and leaving full screen
- **GIVEN** a channel is playing in place
- **WHEN** the user taps the full-screen button, or turns an iPhone sideways
- **THEN** the picture fills the window, on iPhone the screen, with its controls
- **AND** leaving full screen returns to the list without restarting the channel

#### Scenario: The Mac window's own button
- **GIVEN** Live is open on a Mac
- **WHEN** the user uses the window's own full-screen button
- **THEN** the window goes full screen independently of the picture's full-screen button

### Requirement: A login that syncs later
The system SHALL load a source by itself once its login reaches this device from iCloud, within seconds or the next time the user returns to the app, and SHALL remove the waiting note.

#### Scenario: The login arrives
- **GIVEN** a source shown as waiting for its login to arrive from iCloud
- **WHEN** the login reaches this device
- **THEN** the source loads by itself, within seconds or the next time the user returns to the app
- **AND** the waiting note goes away

### Requirement: Sources that fail, are empty or wait for a login
The system SHALL list the channels that loaded under a banner naming each failed source with Try again and dismiss, SHALL replace the list with one message on the shared empty and error layout when no source loaded channels, with Try again, and Open Settings first unless the device is offline, and SHALL never show a source's own error text.

#### Scenario: Some sources failed
- **GIVEN** at least one source failed to load, has no channels, or has no login on this device yet
- **WHEN** the user opens Live
- **THEN** the channels that did load are listed under a banner naming each failed source, with Try again and a dismiss button
- **AND** Try again reloads only those sources while the channel keeps playing

#### Scenario: Nothing loaded
- **GIVEN** no source loaded any channels
- **WHEN** the user opens Live
- **THEN** a message with Open Settings and Try again takes the list's place
- **AND** the picture area shows no placeholder of its own while the message shows
- **AND** the source's own error text is never shown

#### Scenario: Loading, offline, empty or waiting
- **GIVEN** sources are loading, the device is offline, sources loaded with no channels, or a login has not arrived from iCloud
- **WHEN** the user opens Live
- **THEN** the list shows each source loading in turn, says the device is offline, shows "No channels yet" with Open Settings and Try again, or names the source as waiting for its login

### Requirement: Tap the open tab to go back to the top
The system SHALL scroll Live's channel list, the Guide's channels, Movies and Search back to their top when the user taps the tab that is already open in the tab bar on iPhone or in a narrow iPad window. On Movies, a movie or series page open from the rows SHALL close on the same tap. The channel playing SHALL not change.

#### Scenario: Movies scrolled down
- **GIVEN** Movies is open on iPhone and scrolled down past the banner
- **WHEN** the user taps Movies in the tab bar
- **THEN** the rows scroll back to the top with the banner showing

#### Scenario: Live's list scrolled down
- **GIVEN** Live is open on iPhone with a channel playing and the list scrolled down
- **WHEN** the user taps Live in the tab bar
- **THEN** the list scrolls back to its first channel and the channel keeps playing

#### Scenario: A page open on Movies
- **GIVEN** a movie's page opened from the Movies rows on iPhone
- **WHEN** the user taps Movies in the tab bar
- **THEN** the page closes and the rows show from the top

#### Scenario: Another tab
- **GIVEN** Live is open on iPhone
- **WHEN** the user taps Movies
- **THEN** Movies opens where it was left, without scrolling

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
