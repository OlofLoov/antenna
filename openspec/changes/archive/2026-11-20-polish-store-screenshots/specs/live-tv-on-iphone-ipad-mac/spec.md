## MODIFIED Requirements

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
