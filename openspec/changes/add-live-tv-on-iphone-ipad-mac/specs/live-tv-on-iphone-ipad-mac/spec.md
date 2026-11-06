# Spec Delta

## Purpose

The Live TV screen for people who watch on an iPhone, iPad or Mac. They scroll and narrow their channels by group or by typing, and a channel plays in place while they keep browsing, with favorites as a group in the same list.

## ADDED Requirements

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

### Requirement: Pick a group
The system SHALL list the picked group's channels in channel-list order, keep the playing channel playing, and clear the filter, and on iPad and Mac SHALL head the list with the group's name and channel count.

#### Scenario: Picking Sport
- **GIVEN** a group "Sport" with 42 channels
- **WHEN** the user picks it in the sidebar or taps its chip
- **THEN** the list shows those 42 channels in the catalogue's order
- **AND** the channel already playing keeps playing and the filter is cleared
- **AND** on iPad and Mac the list's header reads "Sport" and "42 channels"

#### Scenario: Empty Favorites
- **GIVEN** the user has no favorites
- **WHEN** they pick Favorites
- **THEN** the list says "No favorites yet. Tap the star on a channel to add it."

#### Scenario: Tens of thousands of channels
- **GIVEN** the user has tens of thousands of channels
- **WHEN** they open a large group and scroll
- **THEN** the list opens and scrolls without stalling

#### Scenario: VoiceOver reads a row
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a channel row
- **THEN** it is read as name, number, programme and time left, and every control has a label

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

### Requirement: Player controls when you want them
The system SHALL show pause, programme progress, the time of day, a LIVE badge and full screen when the user taps, clicks or hovers over the picture, plus Picture in Picture on iPhone and iPad, and SHALL hide them after a few seconds without input unless paused.

#### Scenario: Showing the controls
- **GIVEN** a channel is playing in place
- **WHEN** the user taps or clicks the picture, or moves the pointer over it
- **THEN** pause, the programme's progress, the time of day, a LIVE badge and full screen appear
- **AND** on iPhone and iPad a Picture in Picture button appears, greyed out when the player cannot do it

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
The system SHALL list the channels that loaded under a banner naming each failed source with Retry and dismiss, SHALL replace the list with a message and Retry when no source loaded channels, and SHALL never show a source's own error text.

#### Scenario: Some sources failed
- **GIVEN** at least one source failed to load, has no channels, or has no login on this device yet
- **WHEN** the user opens Live
- **THEN** the channels that did load are listed under a banner naming each failed source, with Retry and a dismiss button
- **AND** Retry reloads only those sources while the channel keeps playing

#### Scenario: Nothing loaded
- **GIVEN** no source loaded any channels
- **WHEN** the user opens Live
- **THEN** a message with Retry takes the list's place
- **AND** the source's own error text is never shown

#### Scenario: Loading, offline, empty or waiting
- **GIVEN** sources are loading, the device is offline, sources loaded with no channels, or a login has not arrived from iCloud
- **WHEN** the user opens Live
- **THEN** the list shows each source loading in turn, says the device is offline, shows "No channels yet" with Retry, or names the source as waiting for its login
