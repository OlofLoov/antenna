## MODIFIED Requirements

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

#### Scenario: A short group
- **GIVEN** a group with fewer channels than the grid has room for
- **WHEN** the Guide shows it on iPad or Mac
- **THEN** the first row starts right under the time labels and the space left over is below the last row

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

#### Scenario: The chips take one row
- **GIVEN** an iPhone
- **WHEN** the user opens the Guide
- **THEN** the group chips sit at the top, one row tall, with the day chips right under them
