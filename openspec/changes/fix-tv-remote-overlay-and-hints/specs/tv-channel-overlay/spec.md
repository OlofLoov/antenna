## ADDED Requirements

### Requirement: The columns keep the safe edge
The system SHALL start the group column at the left edge of the TV safe area, 80 points from the screen's edge, with the channel list right after it, whether the highlight moves through the groups, the channels or the panel, and whether the panel on the right shows a channel or nothing.

#### Scenario: Switching groups
- **GIVEN** the overlay is open with the highlight on a channel
- **WHEN** the user moves left into the groups and up or down to another group
- **THEN** the group column and the channel list stay exactly where they were while the user changed channels

#### Scenario: An empty group
- **GIVEN** the highlight is on a group with no channels, so the panel is empty
- **WHEN** the overlay draws
- **THEN** the group column still starts 80 points from the left edge
