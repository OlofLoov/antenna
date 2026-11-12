# Spec Delta

## Purpose

Lets someone watching live TV on Apple TV see what else is on, tune, and manage favorites from a list laid over the picture, without the video stopping.

## ADDED Requirements

### Requirement: The picture keeps playing
The system SHALL open the overlay when the user presses select during playback, and the video SHALL carry on without pausing or restarting.

#### Scenario: Select opens the overlay over live video
- **GIVEN** a channel is playing
- **WHEN** the user presses select
- **THEN** the overlay opens and the video carries on without pausing or restarting

#### Scenario: Opened while a stream is loading or has failed
- **GIVEN** a stream is loading or has failed
- **WHEN** the user presses select
- **THEN** the overlay opens over whatever the player shows

#### Scenario: Play and pause with the overlay open
- **GIVEN** the overlay is open
- **WHEN** the user presses play/pause
- **THEN** the video pauses or resumes and the overlay stays

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the overlay opens
- **THEN** it appears without sliding

#### Scenario: A very large channel list
- **GIVEN** All channels holds 20 000 channels
- **WHEN** the user presses select
- **THEN** the overlay still opens quickly

### Requirement: It opens where the user left off
The system SHALL open the overlay on the group the user last tuned from, with the playing channel highlighted, falling back to that group's first channel or to All channels when the playing channel is not there.

#### Scenario: The playing channel is in the last group
- **GIVEN** a channel is playing and the user last tuned from a group that holds it
- **WHEN** the overlay opens
- **THEN** that group is chosen and the playing channel is highlighted

#### Scenario: The playing channel is not in the last group
- **GIVEN** the user last tuned from a group that does not hold the playing channel
- **WHEN** the overlay opens
- **THEN** that group is chosen and its first channel is highlighted

#### Scenario: The playing channel is gone
- **GIVEN** the playing channel is no longer in the channel list
- **WHEN** the overlay opens
- **THEN** All channels is chosen with its first channel highlighted

### Requirement: Every group, with its size
The system SHALL list Favorites, All channels and every group in channel-list order in the left column, each with how many channels it holds, and SHALL end the column with a way into Search.

#### Scenario: Groups and counts
- **GIVEN** the user has channels in groups and some favorites
- **WHEN** the overlay opens
- **THEN** the left column lists Favorites, All channels and every group in the channel list's order, each with how many channels it holds
- **AND** the column ends with a way into Search

#### Scenario: The same group name in two sources
- **GIVEN** two sources each have a group with the same name
- **WHEN** the overlay opens
- **THEN** both groups are listed, in source order

#### Scenario: A source without its password
- **GIVEN** a source's password is missing on this device
- **WHEN** the overlay opens
- **THEN** that source adds no channels and no groups

#### Scenario: Channels or favorites change while open
- **GIVEN** the overlay is open
- **WHEN** channels or favorites change
- **THEN** lists and counts update in place
- **AND** the highlight stays on the same channel if it still exists, else on the group's first channel
- **AND** if the group itself is gone, All channels is chosen

### Requirement: Picking a group shows its channels
The system SHALL show exactly the highlighted group's channels in the middle column, under a heading with the group's name and how it is sorted.

#### Scenario: Moving through groups
- **GIVEN** the highlight is in the group column
- **WHEN** the user moves to another group
- **THEN** the middle column shows exactly that group's channels
- **AND** the heading shows the group's name and "Your order" for Favorites, or by number for the rest

#### Scenario: The same channel in two sources
- **GIVEN** two sources carry a channel with the same name
- **WHEN** the group is shown
- **THEN** both channels are listed, in source order

### Requirement: Each channel shows what is on
The system SHALL show for each channel row its number, logo or initials, name, the programme on now with how far in it is, and a catch-up mark when catch-up is available, and SHALL say when the guide has nothing or is still loading.

#### Scenario: A channel with a current programme
- **GIVEN** the overlay is open
- **WHEN** the user looks at the channel list
- **THEN** each channel shows its number, logo (or its initials when there is no logo), name, the programme on now with how far in it is, and a mark when catch-up is available

#### Scenario: No guide or guide loading
- **GIVEN** a channel has nothing in the guide, or its guide is still loading
- **WHEN** the user looks at its row
- **THEN** the row says there is nothing in the guide, or that the guide is loading

#### Scenario: A programme ends while open
- **GIVEN** the overlay is open
- **WHEN** a programme ends
- **THEN** its row moves on to the next programme

#### Scenario: A very long name
- **GIVEN** a channel has a very long name
- **WHEN** its row shows
- **THEN** the name is cut short with an ellipsis

#### Scenario: VoiceOver reads a row
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a channel row
- **THEN** it is read once as number, name, programme and time left

### Requirement: Now and next for the highlighted channel
The system SHALL show in the right panel the highlighted channel's logo, name, number and catch-up days, the current programme with its times, time left, progress and description, and up to three programmes that follow, each a row the remote can reach that sets or removes a reminder.

#### Scenario: A channel with guide data
- **GIVEN** a channel is highlighted
- **WHEN** the user looks at the panel on the right
- **THEN** it shows the channel's logo, name, number and how many days of catch-up it has
- **AND** the current programme with its times, time left, progress and description
- **AND** up to three programmes that follow

#### Scenario: Remind me on a programme that follows
- **GIVEN** the panel lists programmes that follow
- **WHEN** the user moves to one of them
- **THEN** its row offers Remind me, or reads "Reminder set" when it has one, and select turns the reminder on or off without leaving the overlay

#### Scenario: Nothing on now
- **GIVEN** the guide has nothing for now on the highlighted channel
- **WHEN** the panel shows
- **THEN** the panel says so in place of the current programme

#### Scenario: A programme ends while the panel shows it
- **GIVEN** the panel shows a current programme
- **WHEN** it ends
- **THEN** the panel moves on to the next one

### Requirement: Select changes channel
The system SHALL tune to the highlighted channel when the user selects it or chooses Watch, close the overlay, show the info bar, and make channel up and down move through that channel's group.

#### Scenario: Tuning to another channel
- **GIVEN** a channel other than the playing one is highlighted
- **WHEN** the user presses select or chooses Watch
- **THEN** that channel starts playing and the overlay closes
- **AND** the info bar appears
- **AND** channel up and down now move through that channel's group

### Requirement: Select on the playing channel does not restart it
The system SHALL close the overlay without restarting the stream when the user selects the playing channel, resume a paused stream, and load a failed or never-started stream again.

#### Scenario: The playing channel is selected
- **GIVEN** the playing channel is highlighted
- **WHEN** the user presses select or chooses Watch
- **THEN** the overlay closes and the stream carries on without restarting

#### Scenario: Paused or failed
- **GIVEN** the playing channel is paused, failed or never started
- **WHEN** the user selects it in the overlay
- **THEN** a paused stream resumes, and one that failed or never started is loaded again

### Requirement: Menu closes without changing anything
The system SHALL close the overlay on Menu, keep the same channel playing and the same channel up and down group, and SHALL NOT also take the user out of the player.

#### Scenario: Menu with the overlay open
- **GIVEN** the overlay is open
- **WHEN** the user presses Menu
- **THEN** the overlay closes and the same channel keeps playing
- **AND** channel up and down keep their group
- **AND** the press does not also take the user out of the player

#### Scenario: The overlay never closes by itself
- **GIVEN** the overlay is open
- **WHEN** the user does nothing
- **THEN** the overlay stays open

### Requirement: Add or remove a favorite
The system SHALL toggle the highlighted channel's favorite state from the favorite button, label the button with what the next press will do, and change the Favorites count by one.

#### Scenario: Toggling a favorite
- **GIVEN** the favorite button is highlighted for a channel
- **WHEN** the user presses select
- **THEN** the channel is added to favorites if it was not one, or removed if it was
- **AND** the button's label says what the next press will do
- **AND** the Favorites count goes up or down by one

#### Scenario: Removing a favorite while viewing Favorites
- **GIVEN** the user is looking at Favorites
- **WHEN** they remove a favorite
- **THEN** it leaves the list and the highlight moves to a neighbor, or to the group when none is left

### Requirement: Empty groups tell the user what to do
The system SHALL explain in the channel column how to add a favorite or a source when Favorites or All channels is empty, keep the panel empty, and keep the highlight out of the empty column.

#### Scenario: No favorites or no channels
- **GIVEN** the user has no favorites, or no channels at all
- **WHEN** Favorites or All channels is shown
- **THEN** the channel column explains how to add a favorite or a source
- **AND** the panel stays empty
- **AND** the highlight cannot move into the empty column

### Requirement: A way into Search
The system SHALL close the overlay and open the Search tab ready to type when the user selects the Search entry, with the video carrying on, and Menu in Search SHALL NOT reopen the overlay.

#### Scenario: Selecting Search
- **GIVEN** the Search entry is highlighted
- **WHEN** the user presses select
- **THEN** the overlay closes and the Search tab opens ready to type
- **AND** the video carries on as it was
- **AND** Menu in Search does not reopen the overlay
