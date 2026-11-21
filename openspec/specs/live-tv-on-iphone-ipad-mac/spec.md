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
The system SHALL show on iPhone, and on iPad in a narrow Split View, the picture across the top with the now-playing line, the group button and the channel list below and the tab bar at the bottom, and switching layouts SHALL NOT interrupt the channel.

#### Scenario: The Live tab on iPhone
- **GIVEN** an iPhone, or an iPad in a narrow Split View
- **WHEN** the user opens the Live tab
- **THEN** the picture spans the width at the top, with the now-playing line, the group button and the channel list below it and the tab bar at the bottom
- **AND** the group button runs from the leading edge to the profile button at the row's trailing end, and shows the open group's name, its channel count and a chevron

#### Scenario: Switching between narrow and wide
- **GIVEN** a channel is playing
- **WHEN** the layout switches between narrow and wide
- **THEN** the channel is not interrupted

#### Scenario: Large text
- **GIVEN** the user has a large text size
- **WHEN** Live is shown on iPhone
- **THEN** the rows grow and the picture keeps its shape

#### Scenario: The group button sits under the line
- **GIVEN** an iPhone, with or without a channel playing
- **WHEN** Live is shown
- **THEN** the group button sits right under the now-playing line, or under the picture area when nothing plays, and the channel list starts right under the button

### Requirement: Pick a group
The system SHALL list the picked group's channels in order from the top, keep the playing channel playing and clear the filter. On iPad and Mac the list SHALL be headed by the group's name and count; on iPhone the group button SHALL open a Groups sheet with the built-in groups first, then every other group with its count and a checkmark on the open one. Empty Favorites SHALL say how to add a favorite.

#### Scenario: Picking Sport
- **GIVEN** a group "Sport" with 42 channels
- **WHEN** the user picks it in the sidebar, or in the Groups sheet on iPhone
- **THEN** the list shows those 42 channels in the catalogue's order, scrolled to the first
- **AND** the channel already playing keeps playing and the filter is cleared
- **AND** on iPad and Mac the list's header reads "Sport" and "42 channels"
- **AND** on iPhone the sheet closes and the group button reads "Sport" and 42

#### Scenario: Opening the Groups sheet
- **GIVEN** an iPhone with Live or the Guide open on Sport
- **WHEN** the user taps the group button
- **THEN** a sheet titled "Groups" opens at half height with a search field, the built-in groups first and then every other group with its count
- **AND** Sport has a checkmark
- **AND** dragging the sheet up shows more groups, and dragging it down or tapping Close leaves Sport open

#### Scenario: Hidden and locked groups in the sheet
- **GIVEN** the user hid one group and locked another, and the locks are closed
- **WHEN** they open the Groups sheet
- **THEN** the hidden group is not listed
- **AND** the locked group is listed after the others with a lock and no count, and picking it closes the sheet and asks for the passcode

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
The system SHALL scroll Live's channel list, the Guide's channels, Movies, Series and Search back to their top when the user taps the tab that is already open in the tab bar on iPhone or in a narrow iPad window. On Movies and Series, a movie or series page open from the tab's rows SHALL close on the same tap. The channel playing SHALL not change.

#### Scenario: Movies scrolled down
- **GIVEN** Movies is open on iPhone and scrolled down past the banner
- **WHEN** the user taps Movies in the tab bar
- **THEN** the rows scroll back to the top with the banner showing

#### Scenario: Live's list scrolled down
- **GIVEN** Live is open on iPhone with a channel playing and the list scrolled down
- **WHEN** the user taps Live in the tab bar
- **THEN** the list scrolls back to its first channel and the channel keeps playing

#### Scenario: A page open on Movies
- **GIVEN** a movie's page opened from the Movies rows on iPhone, or a series page opened from the Series rows
- **WHEN** the user taps Movies, or Series, in the tab bar
- **THEN** the page closes and the rows show from the top

#### Scenario: Another tab
- **GIVEN** Live is open on iPhone
- **WHEN** the user taps Movies
- **THEN** Movies opens where it was left, without scrolling

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

### Requirement: Find a group among many
The system SHALL let the user narrow the groups by typing part of a name, in the Groups sheet on iPhone and in a search field above the sidebar's groups on iPad and Mac, matching the way the channel filter does: case and accents ignored, every typed word somewhere in the group's name. Matching groups SHALL keep their order and counts. Hundreds of groups SHALL open and scroll without stalling.

#### Scenario: Typing part of a provider's name
- **GIVEN** a provider with groups "SE | SPORT", "UK ▸ SPORTS HD" and "SE | NEWS"
- **WHEN** the user types "sport" in the Groups sheet or the sidebar's search field
- **THEN** "SE | SPORT" and "UK ▸ SPORTS HD" are listed in that order with their counts, and "SE | NEWS" is not

#### Scenario: Built-in groups and search
- **GIVEN** the app is in Swedish
- **WHEN** the user types "favor"
- **THEN** Favoriter is listed, matched by the name the app shows in Swedish

#### Scenario: Nothing matches
- **WHEN** the user types a name no group has
- **THEN** the sheet or the sidebar says no groups match, and clearing the field lists every group again

#### Scenario: Hundreds of groups
- **GIVEN** a provider with 200 groups
- **WHEN** the user opens the Groups sheet, scrolls to the end and searches for one of them
- **THEN** the list scrolls without stalling and the search finds that group

#### Scenario: VoiceOver on the group button
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to the group button
- **THEN** it is read as the group's name and its number of channels, and says it opens the list of groups

### Requirement: The iPhone tab bar
The system SHALL show on iPhone, and on iPad in a narrow window, a tab bar holding Live, Guide, Movies and Series, with Search as the system's round search button at its trailing end and no Settings tab. Movies and Series SHALL each show only when the sources offer them, and each SHALL keep its own place.

#### Scenario: Sources with movies and series
- **GIVEN** an iPhone with an Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds Live, Guide, Movies and Series in that order, then the search button at its trailing end
- **AND** there is no Settings tab and no Movies | Series switch

#### Scenario: A playlist with movies only
- **GIVEN** an iPhone whose only source is a playlist whose last load had movies and no episodes
- **WHEN** the tab bar shows
- **THEN** it holds Movies and no Series tab

#### Scenario: Each tab keeps its place
- **GIVEN** Movies is open with the Drama genre picked and the rows scrolled down
- **WHEN** the user opens Series and comes back to Movies
- **THEN** Series shows its own rows from its banner, and Movies shows Drama where the user left it

#### Scenario: Search from the tab bar
- **GIVEN** Movies is open
- **WHEN** the user taps the search button
- **THEN** Search opens with the field ready for typing, and Cancel goes back to Movies

#### Scenario: Right-to-left
- **GIVEN** the app in Arabic
- **WHEN** the tab bar shows
- **THEN** Live is the rightmost tab and the search button sits at the left end

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

### Requirement: One window on the Mac
The system SHALL keep at most one Antenna window open on a Mac. File > New Window SHALL open a window only when none is open and SHALL be dimmed while one is. A file, link or Handoff that arrives SHALL go to the open window. On iPad the app SHALL keep one window.

#### Scenario: New Window with a window open
- **GIVEN** Antenna is open in a window on a Mac
- **WHEN** the user presses Command-N or opens the File menu
- **THEN** no second window opens, and New Window is dimmed

#### Scenario: New Window after closing the window
- **GIVEN** the user closed Antenna's window and the app is still running
- **WHEN** the user chooses File > New Window
- **THEN** one window opens

#### Scenario: A playlist file opened from Finder
- **GIVEN** Antenna is open in a window on a Mac
- **WHEN** the user opens a playlist file with Antenna
- **THEN** the import sheet shows in that window and no other window opens

#### Scenario: iPad
- **GIVEN** Antenna on an iPad
- **WHEN** the user tries to open a second Antenna window from the dock or the app switcher
- **THEN** Antenna keeps its one window

### Requirement: A very large source stays responsive
The system SHALL keep the channel list still and the main thread free of work that grows with the channel count when nothing it shows has changed, on iPhone, iPad, Mac and Apple TV.

#### Scenario: A refresh with the same channels
- **GIVEN** a source with 100 000 channels
- **WHEN** it refreshes and brings back the same channels
- **THEN** the channel list and the guide are not rebuilt

#### Scenario: A channel counts as watched
- **GIVEN** the open group holds 50 000 channels
- **WHEN** a channel has played for ten seconds and joins Recents
- **THEN** the open group's list is not worked out again, unless the open group is Recents

#### Scenario: Logos scrolled past
- **GIVEN** a fast scroll through a large group in the Live list, the Guide or the Apple TV overlay
- **WHEN** rows leave the screen before their logos arrive
- **THEN** downloads that no row waits for stop, and the logos on screen do not queue behind them

#### Scenario: Guide progress
- **GIVEN** a large guide downloading for a source with 50 000 channels
- **WHEN** the download reports progress
- **THEN** channels are not matched to guide entries by name again until the guide or the channels change
