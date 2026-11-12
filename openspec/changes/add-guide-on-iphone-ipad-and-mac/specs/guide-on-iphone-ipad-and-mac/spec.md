# Spec Delta

## Purpose

Gives people who plan their viewing on an iPhone, iPad or Mac a real TV guide, a time grid or per-channel rows, where they move through the coming days, read about a programme and start watching, while whatever was playing keeps playing out of sight.

## ADDED Requirements

### Requirement: A time grid on iPad and Mac
The system SHALL show the Guide on iPad and Mac in the wide layout as a grid of the current group's channels against half-hour columns, with a line at the current time and fixed channel names and time labels.

#### Scenario: Open the Guide at 21:34
- **GIVEN** an iPad or Mac window in the wide layout at 21:34
- **WHEN** the user opens the Guide
- **THEN** a toolbar sits above a grid of the group's channels against half-hour columns starting at 21:00, with a line at 21:34
- **AND** the channel names and time labels stay put while the programmes scroll under them
- **AND** the sidebar folds away in narrower windows as Live does, and no channel list or picture is shown

#### Scenario: Time passes
- **GIVEN** the grid open
- **WHEN** a programme ends
- **THEN** within a few seconds the now line moves, the ended programme turns to past and the next one gains NOW, and the grid never scrolls by itself

#### Scenario: The window changes size
- **GIVEN** the Guide open with a group, a day and open details
- **WHEN** the user rotates an iPad or resizes Split View
- **THEN** grid and list swap as the width needs, keeping the group, the day and the open details, with a popover becoming a sheet and back

#### Scenario: Scroll through time on Mac
- **WHEN** the user swipes sideways on a Mac trackpad or holds Shift with the mouse wheel
- **THEN** the grid moves through time

#### Scenario: Large text and gaps
- **GIVEN** a large text size and a gap between two programmes
- **WHEN** the grid shows
- **THEN** rows grow taller while columns keep their width, and the gap shows as empty space

#### Scenario: A very large catalogue
- **GIVEN** tens of thousands of channels with seven days of guide
- **WHEN** the user opens the Guide and scrolls, in the grid or the iPhone rows
- **THEN** it opens and scrolls without stalling

### Requirement: One row per channel on iPhone
The system SHALL show the Guide on iPhone and in a narrow iPad Split View as one row per channel, each scrolling sideways through that channel's programmes from the one on now.

#### Scenario: Open the Guide on iPhone
- **GIVEN** an iPhone, or an iPad in a narrow Split View
- **WHEN** the user opens the Guide
- **THEN** group chips and day chips sit above a list with one row per channel, each showing that channel's programmes as cards from the one on now, with start time and title
- **AND** the card on now is marked NOW with a progress bar
- **AND** each row scrolls sideways on its own

#### Scenario: A gap on iPhone
- **GIVEN** a gap between two programmes on a channel
- **WHEN** its row shows
- **THEN** the gap is a card with just the times

### Requirement: The same group as Live
The system SHALL show the same current group in the Guide as in Live, so changing it in one changes it in the other.

#### Scenario: Switch groups in the Guide
- **GIVEN** the current group in Live is Sport with 42 channels
- **WHEN** the user opens the Guide, then picks News, then goes back to Live
- **THEN** the Guide first shows Sport's 42 channels in catalogue order with the playing channel marked, then News's channels
- **AND** Live shows News with the same channel still playing

### Requirement: Zoom
The system SHALL let the user zoom the grid on iPad and Mac through four fixed scales, keeping the time in view in place, and SHALL remember the scale on this device.

#### Scenario: Zoom in and out
- **GIVEN** the grid at its default scale on iPad or Mac
- **WHEN** the user taps zoom in or out, presses Command-Plus or Command-Minus, or pinches on an iPad
- **THEN** the grid steps through four fixed scales, keeping the time under the now line, or under the pinch, in place
- **AND** the buttons are disabled at either end
- **AND** the chosen scale is still there after a relaunch on this device

#### Scenario: Pinch on a Mac trackpad
- **WHEN** the user pinches on a Mac trackpad
- **THEN** nothing happens, and zoom on Mac uses the buttons and keys

### Requirement: Move through the days
The system SHALL let the user move through the days the guide covers by day chip, by scrolling past midnight and by Now, and SHALL not scroll before the guide's first half-hour or past its last programme.

#### Scenario: Day chips, midnight and Now
- **GIVEN** the guide covers today and the next seven days
- **WHEN** the user picks a day chip, drags past midnight on iPad or Mac, or taps Now
- **THEN** a day chip jumps to the same time of day on that day, dragging past midnight selects the new day's chip, and Now returns to today around the current time with the playing channel in view
- **AND** the user cannot scroll before the guide's first half-hour or past its last programme, and earlier days are not listed

#### Scenario: The day the clocks change
- **GIVEN** a day on which the clocks change
- **WHEN** the user jumps to that day
- **THEN** the header shows the repeated or missing hour, and a jump to a time that does not exist that day lands on the next minute that does

#### Scenario: A short guide
- **GIVEN** a guide covering less than a day, or no guide at all
- **WHEN** the Guide opens
- **THEN** the day chips list Today only

#### Scenario: The clock or time zone changes
- **GIVEN** the Guide open with details showing
- **WHEN** the clock or time zone changes
- **THEN** the now line and day chips move, and the details stay open

### Requirement: Read about a programme
The system SHALL open a programme's details from the grid or a row, showing when and where it airs, its title, times, length, progress if on now, its description, a Watch button and, for a programme that has not started, Remind me after Watch.

#### Scenario: Open a programme's details
- **GIVEN** a programme in the grid or a row
- **WHEN** the user taps or clicks it, or on a keyboard moves to it with the arrow keys and presses Return
- **THEN** its details open, a popover on iPad and Mac and a sheet on iPhone, with when and where it airs, the title, times and length, how far it has run if on now, its description, and Watch
- **AND** Remind me after Watch when the programme has not started
- **AND** the usual dismiss gestures and Escape close it

#### Scenario: VoiceOver
- **GIVEN** VoiceOver on
- **WHEN** the user moves to a programme and opens it
- **THEN** VoiceOver reads the channel, title, times and whether it is past, now or later, and announces the details when they open

### Requirement: Start watching from the guide
The system SHALL open Live with the chosen channel in the same group when the user taps Watch or a channel's name, starting, resuming or keeping the channel's playback as its state needs.

#### Scenario: Watch a channel
- **GIVEN** a programme's details, or a channel's name in the grid or a row's header
- **WHEN** the user taps Watch or the channel's name
- **THEN** Live opens with that channel playing in the same group
- **AND** a channel not yet playing, or one that failed, starts, a paused one resumes, and one already playing carries on uninterrupted

#### Scenario: Watch a later programme
- **GIVEN** the details of a programme later today or on another day
- **WHEN** the user taps Watch
- **THEN** Live plays the channel now and shows the programme as coming up later, as Search does

### Requirement: Channels with gaps or no guide
The system SHALL say in a channel's row when its guide is loading, missing or failed, and SHALL show a banner with Retry for a source whose guide failed.

#### Scenario: Missing and failed guides
- **GIVEN** channels whose guide is loading, missing or failed
- **WHEN** the user looks at the guide
- **THEN** their rows read "Loading guide…", "No programme information" or "Guide unavailable" in place of programmes
- **AND** a source whose guide failed gets a banner "Could not load the guide for <source>" with Retry and dismiss

#### Scenario: A login still to sync
- **GIVEN** a source whose login has not synced
- **WHEN** the Guide shows
- **THEN** a banner reads "<source>: waiting for its login to sync from iCloud" until the login arrives

#### Scenario: Offline or a failed refresh
- **WHEN** the device is offline or a guide refresh fails
- **THEN** the guide keeps the programmes it already has, and rows with nothing yet read "Guide unavailable"

#### Scenario: The guide loads while open
- **GIVEN** the Guide open
- **WHEN** a guide finishes loading or refreshes
- **THEN** its rows fill in place without moving the scroll position

### Requirement: Nothing to show yet
The system SHALL replace the grid or list with Live's loading rows or error message while sources load or have all failed, and with a "No channels" message for an empty group.

#### Scenario: Loading, failed or empty
- **GIVEN** sources still loading, every source failed, or a group with no channels
- **WHEN** the user opens the Guide
- **THEN** the grid or list is replaced by the same loading rows or error message with Retry as Live, or by "No channels in <group>" with the toolbar or chips still working
- **AND** while loading or failed, the toolbar and chips are hidden

### Requirement: Open at a programme
The system SHALL open the guide at a programme another screen asks for, selecting its day, scrolling to it and opening its details, and SHALL open at now when the programme cannot be found.

#### Scenario: Open from Search
- **GIVEN** the user picks a later programme in Search
- **WHEN** the guide opens at it
- **THEN** it switches to All channels if that channel is not in the current group, clears the filter, selects the programme's day, scrolls to the programme and opens its details

#### Scenario: The programme cannot be found
- **GIVEN** a programme that cannot be found, or whose guide is still loading
- **WHEN** the guide opens at it
- **THEN** the guide opens at now with nothing selected and does not try again later

### Requirement: Filter channels by typing
The system SHALL narrow the iPad and Mac guide to the group's channels whose name matches or whose number starts with the typed digits, after each letter typed.

#### Scenario: Type in the filter
- **GIVEN** a group of 42 channels on iPad or Mac
- **WHEN** the user types in the filter field, or presses Command-F and types
- **THEN** after each letter only the group's channels whose name matches, or whose number starts with the digits typed, remain, matched as in Search, with the header count following

#### Scenario: Clear the filter
- **GIVEN** a filtered guide
- **WHEN** the user clears the field, picks another group, or opens the guide at a programme
- **THEN** the whole group comes back

#### Scenario: No filter on iPhone
- **WHEN** the user opens the Guide on iPhone
- **THEN** there is no filter field

### Requirement: Playback carries on out of sight
The system SHALL leave Live's playback untouched while the Guide is open, and SHALL show what is playing with a way back to Live.

#### Scenario: Open the Guide while watching
- **GIVEN** a channel playing or paused in Live
- **WHEN** the user opens the Guide and later goes back to Live
- **THEN** the guide does not pause, stop, resume or change the channel
- **AND** the toolbar (iPad, Mac) or a bar above the tab bar (iPhone) shows the channel, a live dot while it plays, and how far the programme has run, plus the programme title and time left on iPhone
- **AND** tapping it returns to Live

#### Scenario: Nothing playing
- **GIVEN** nothing playing in Live
- **WHEN** the user opens the Guide
- **THEN** no now-playing toolbar item or bar is shown

