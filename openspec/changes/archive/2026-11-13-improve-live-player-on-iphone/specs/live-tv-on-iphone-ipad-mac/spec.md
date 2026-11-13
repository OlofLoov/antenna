# Spec Delta

## Purpose

The Live TV screen for people who watch on an iPhone, iPad or Mac. They scroll and narrow their channels by group or by typing, and a channel plays in place while they keep browsing, with favorites as a group in the same list.

## ADDED Requirements

### Requirement: Sideways on iPhone fills the screen
The system SHALL show the playing channel full screen, with no tab bar and no channel line below the picture, whenever an iPhone is held sideways on Live with a channel playing, however it got there, and SHALL return to the list when the phone turns upright.

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
