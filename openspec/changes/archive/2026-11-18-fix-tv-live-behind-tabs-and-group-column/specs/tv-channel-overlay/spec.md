## ADDED Requirements

### Requirement: The group column keeps its place
The system SHALL scroll the group column only as the highlight moves through it, or to bring the shown group into view when the overlay opens or the shown group changes from outside the column. Moving left from the channels SHALL land on the shown group in one step, without stopping on another group first, and the group column SHALL not move while the shown group is on screen.

#### Scenario: Back from far down a list
- **GIVEN** the user moved from a group into its channels and scrolled 30 rows down the list
- **WHEN** the user moves left
- **THEN** the highlight lands on that group and every group row stays where it was

#### Scenario: Out and back again
- **GIVEN** the highlight is on a group in the group column
- **WHEN** the user moves right into its channels and left again, more than once
- **THEN** the group column does not move

#### Scenario: Opening on a group far down the list
- **GIVEN** the overlay opens on a group below the first screen of the group column
- **WHEN** it appears
- **THEN** the group column already shows that group, with no scrolling animation
