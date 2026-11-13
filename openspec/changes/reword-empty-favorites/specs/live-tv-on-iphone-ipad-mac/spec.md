## MODIFIED Requirements

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
