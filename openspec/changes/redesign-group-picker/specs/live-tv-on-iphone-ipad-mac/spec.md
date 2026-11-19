# Spec Delta

## MODIFIED Requirements

### Requirement: Picture pinned at the top on iPhone
The system SHALL show on iPhone, and on iPad in a narrow Split View, the picture across the top with the now-playing line, the group button and the channel list below and the tab bar at the bottom, and switching layouts SHALL NOT interrupt the channel.

#### Scenario: The Live tab on iPhone
- **GIVEN** an iPhone, or an iPad in a narrow Split View
- **WHEN** the user opens the Live tab
- **THEN** the picture spans the width at the top, with the now-playing line, the group button and the channel list below it and the tab bar at the bottom
- **AND** the group button spans the width and shows the open group's name, its channel count and a chevron

#### Scenario: Switching between narrow and wide
- **GIVEN** a channel is playing
- **WHEN** the layout switches between narrow and wide
- **THEN** the channel is not interrupted

#### Scenario: Large text
- **GIVEN** the user has a large text size
- **WHEN** Live is shown on iPhone
- **THEN** the rows grow and the picture keeps its shape

### Requirement: Pick a group
The system SHALL list the picked group's channels in channel-list order from the top, keep the playing channel playing, and clear the filter, and on iPad and Mac SHALL head the list with the group's name and channel count. On iPhone the group button SHALL open a Groups sheet listing Favorites, Recents and New when they show, and All channels, then every other group in the order group management sets, each with its channel count and a checkmark on the open group. Empty Favorites SHALL say how a channel becomes a favorite on that device.

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

## ADDED Requirements

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
