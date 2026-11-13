# tv-guide-grid Specification

## Purpose
Shows someone on Apple TV what is on across the channels of their current group, now and over the coming days, while the channel they were watching keeps playing in a corner, and lets them tune from it.

## Requirements

### Requirement: The channel keeps playing in a small picture
The system SHALL keep the playing or paused stream going in a small picture with the channel's number and name when the user opens the Guide tab, resuming a paused stream and never restarting it.

#### Scenario: Opening the guide while watching
- **GIVEN** a channel is playing, or was paused when the user left full screen
- **WHEN** the user opens the Guide tab
- **THEN** the same stream plays in the small picture with the channel's number and name
- **AND** it resumes if it was paused, without restarting

#### Scenario: The stream is loading or failed
- **GIVEN** the stream is loading or has failed
- **WHEN** the guide shows
- **THEN** the small picture shows the background color with the caption
- **AND** Watch tunes again

#### Scenario: Nothing tuned yet
- **GIVEN** no channel has been tuned since launch
- **WHEN** the user opens the guide
- **THEN** the small picture is empty and Watch tunes

### Requirement: One row per channel in the current group
The system SHALL show one row for each channel in the current group, in channel-list order and no others, each with its number, logo or initials and name, and SHALL mark the playing channel.

#### Scenario: A group of 42 channels
- **GIVEN** the current group has 42 channels
- **WHEN** the user scrolls the grid from top to bottom
- **THEN** there is one row for each of the 42 channels in the channel list's order and no others
- **AND** each row has its number, logo (or initials) and name
- **AND** the playing channel is marked as playing

#### Scenario: A source without its password
- **GIVEN** a source's password has not reached this device
- **WHEN** the guide shows
- **THEN** its channels are absent

#### Scenario: A very large list
- **GIVEN** All channels holds 20 000 channels with seven days of guide
- **WHEN** the user opens the guide and scrolls
- **THEN** it opens quickly and scrolls smoothly

### Requirement: The grid opens around now and keeps time
The system SHALL open the grid with the last hour and a half and the current time in view, mark now with a line that moves as time passes, and SHALL NOT draw the line when now is scrolled out of view.

#### Scenario: Opening at 21:34
- **GIVEN** it is 21:34
- **WHEN** the user opens the guide
- **THEN** the grid opens with the last hour and a half and the current time in view
- **AND** a line marks now

#### Scenario: Time passes
- **GIVEN** the guide is open
- **WHEN** time passes
- **THEN** the now line moves
- **AND** the grid never scrolls by itself to follow the time

#### Scenario: Now out of view
- **GIVEN** the user has scrolled now out of view
- **WHEN** the grid is drawn
- **THEN** the now line is not drawn

#### Scenario: Daylight saving change
- **GIVEN** the visible time spans a daylight saving change
- **WHEN** the header is drawn
- **THEN** it shows the repeated or missing hour

### Requirement: Programmes are drawn to scale
The system SHALL draw each programme as a block as wide as it is long, with no overlaps, past programmes dimmed, and any time with no programme as an empty block the user can highlight.

#### Scenario: A row for the visible time
- **GIVEN** a channel's programmes for the visible time
- **WHEN** the row is drawn
- **THEN** each programme's block is as wide as it is long and blocks never overlap
- **AND** past programmes are dimmed
- **AND** any time with no programme is an empty block the user can highlight

#### Scenario: A programme ends while open
- **GIVEN** the guide is open
- **WHEN** a programme ends
- **THEN** its block turns past and the next becomes now, and the panel follows

#### Scenario: A programme that started earlier
- **GIVEN** a programme started before the visible window
- **WHEN** its row is drawn
- **THEN** its block is clipped to the window and marked as started earlier

#### Scenario: VoiceOver reads a block
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a block
- **THEN** it is read as channel, title, times, and whether it is past, now or future

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the grid scrolls
- **THEN** it moves without sliding

### Requirement: It opens on what is on now
The system SHALL highlight what is on now on the playing channel's row when the guide opens without a Search target, or the first row when that channel is not in the group.

#### Scenario: Playing channel in the group
- **GIVEN** the user opens the guide without coming from Search
- **WHEN** it appears
- **THEN** the highlight is on what is on now on the playing channel's row

#### Scenario: Playing channel not in the group
- **GIVEN** the playing channel is not in the current group
- **WHEN** the guide appears
- **THEN** the highlight is on the first row

### Requirement: The panel describes the highlighted programme
The system SHALL show in the panel when the highlighted programme is on, its channel, title, times and length, category and description when known, picture quality for the playing channel, progress when on now, a Watch button, and Remind me right of Watch for a programme that has not started, and nothing else.

#### Scenario: A highlighted programme
- **GIVEN** a programme is highlighted
- **WHEN** the user looks at the panel
- **THEN** it shows whether it is on now or which day and time it starts, the channel, the title, the times and length
- **AND** the category and description when the guide has them
- **AND** the picture quality for the playing channel, and how far in it is when on now
- **AND** a Watch button, with Remind me right of it when the programme has not started, and nothing else

#### Scenario: A programme with no title
- **GIVEN** the highlighted programme has no title
- **WHEN** the panel shows
- **THEN** the title reads "Untitled"

### Requirement: Select on a programme that is on now
The system SHALL play the channel full screen with the info bar when the user selects a programme that is on now, and SHALL close the guide without restarting a channel that is already playing, unless its stream had failed.

#### Scenario: Another channel
- **GIVEN** a programme that is on now is highlighted on a channel that is not playing
- **WHEN** the user presses select
- **THEN** that channel plays full screen with the info bar

#### Scenario: The channel already playing
- **GIVEN** a programme that is on now is highlighted on the playing channel
- **WHEN** the user presses select
- **THEN** the guide closes and the stream carries on, or is loaded again if it had failed

### Requirement: Select on anything else goes to Watch
The system SHALL move the highlight to Watch without changing channel when the user selects a past or future programme or an empty block, and Watch SHALL then tune as for a programme on now.

#### Scenario: A future programme
- **GIVEN** a past or future programme, or an empty block, is highlighted
- **WHEN** the user presses select
- **THEN** the highlight moves to Watch without changing channel

#### Scenario: Choosing Watch
- **GIVEN** the highlight is on Watch for a channel
- **WHEN** the user presses select
- **THEN** it tunes as select does on a programme that is on now

#### Scenario: Menu from the panel and the grid
- **GIVEN** the highlight is on Watch or in the grid
- **WHEN** the user presses Menu
- **THEN** from Watch the highlight goes back to the grid, and from the grid the tab bar shows

### Requirement: Pick a day
The system SHALL list today and each later day the guide covers along the top, move the grid to the same time of day on a picked date, and keep the chosen day in step when the user scrolls past midnight.

#### Scenario: Picking a later day
- **GIVEN** the guide covers today and the next seven days
- **WHEN** the user picks a day from the list along the top
- **THEN** the grid moves to the same time of day on that date
- **AND** the list shows today and each later day the guide covers

#### Scenario: Scrolling past midnight
- **GIVEN** the user is scrolling the grid
- **WHEN** they pass midnight
- **THEN** the chosen day follows along

#### Scenario: A guide with no dates
- **GIVEN** the guide has no dates at all
- **WHEN** the guide shows
- **THEN** the grid covers today only with a single Today entry

#### Scenario: Calendar days across daylight saving
- **GIVEN** the guide spans a daylight saving change
- **WHEN** the day list shows
- **THEN** it follows calendar days in the user's time zone

### Requirement: Channels without a guide say so
The system SHALL draw a channel whose guide is loading, has nothing for the visible time, or failed with nothing saved as one block with the matching wording, which the user can highlight and select like any other block.

#### Scenario: Loading, empty or unavailable
- **GIVEN** a channel whose guide is still loading, has nothing for the visible time, or failed to load with nothing saved from before
- **WHEN** its row is drawn
- **THEN** the row is one block that reads "Loading guide…", "No programme information" or "Guide unavailable"
- **AND** the user can highlight and select it like any other block

#### Scenario: A failed refresh with an older guide
- **GIVEN** a source's guide refresh failed and it has a guide from before
- **WHEN** its rows are drawn
- **THEN** they show the guide it had before

### Requirement: An empty group
The system SHALL say there are no channels in the current group when it is empty, keep the day list and time header, and put the highlight on today in the day list.

#### Scenario: No channels in the group
- **GIVEN** the current group has no channels
- **WHEN** the user opens the guide
- **THEN** the grid reads "No channels in" and the group's name
- **AND** the day list and time header still show
- **AND** the highlight is on today in the day list

### Requirement: Open at a programme found in Search
The system SHALL open the guide at a programme picked in Search, with the half hour around its start in view, its channel's row in view and the programme highlighted, switching the current group to All channels when the channel is not in it.

#### Scenario: A programme from Search
- **GIVEN** the user picked a programme on a channel in Search
- **WHEN** the guide opens
- **THEN** the grid shows the half hour around the programme's start on its day
- **AND** that channel's row is in view with the programme highlighted

#### Scenario: Channel outside the current group
- **GIVEN** the picked programme's channel is not in the current group
- **WHEN** the guide opens
- **THEN** the current group becomes All channels
