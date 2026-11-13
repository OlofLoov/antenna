## MODIFIED Requirements

### Requirement: Picking a group shows its channels
The system SHALL show exactly the highlighted group's channels in the middle column, under a heading with the group's name and how it is sorted. Moving right from a group SHALL land on the row last highlighted in its list, else on the playing channel when the group holds it, else on its first channel, and moving left from a channel SHALL land on the group it belongs to, with no stop on another row on the way. This SHALL hold with tens of thousands of channels in hundreds of groups.

#### Scenario: Moving through groups
- **GIVEN** the highlight is in the group column
- **WHEN** the user moves to another group
- **THEN** the middle column shows exactly that group's channels
- **AND** the heading shows the group's name and "Your order" for Favorites, or by number for the rest

#### Scenario: The same channel in two sources
- **GIVEN** two sources carry a channel with the same name
- **WHEN** the group is shown
- **THEN** both channels are listed, in source order

#### Scenario: Into the channels
- **GIVEN** the highlight moved onto a group from another group
- **WHEN** the user moves right
- **THEN** the highlight lands on the playing channel when the group holds it, else on the group's first channel

#### Scenario: Back into the same list
- **GIVEN** the user moved left from a channel to its group
- **WHEN** the user moves right again
- **THEN** the highlight lands on the channel they left

#### Scenario: Back to the groups
- **GIVEN** the user moved from a group into its channels and scrolled down the list
- **WHEN** the user moves left
- **THEN** the highlight lands on that group, wherever it is in the group column, and the middle column keeps its channels

#### Scenario: A group far down the list
- **GIVEN** the overlay opens on a group far below the first screen of the group column
- **WHEN** the user moves left from the channels
- **THEN** the highlight lands on that group

#### Scenario: A large catalogue
- **GIVEN** the user has tens of thousands of channels in hundreds of groups
- **WHEN** they move quickly through the groups and into a group's channels
- **THEN** the middle column follows each move without stalling
- **AND** a logo already shown once shows again at once, without its initials first
