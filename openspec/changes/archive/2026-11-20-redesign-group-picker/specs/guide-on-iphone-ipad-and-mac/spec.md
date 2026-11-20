# Spec Delta

## MODIFIED Requirements

### Requirement: One row per channel on iPhone
The system SHALL show the Guide on iPhone and in a narrow iPad Split View as one row per channel, each scrolling sideways through that channel's programmes from the one on now, under the same group button and Groups sheet as Live.

#### Scenario: Open the Guide on iPhone
- **GIVEN** an iPhone, or an iPad in a narrow Split View
- **WHEN** the user opens the Guide
- **THEN** the group button and the day chips sit above a list with one row per channel, each showing that channel's programmes as cards from the one on now, with start time and title
- **AND** the card on now is marked NOW with a progress bar
- **AND** each row scrolls sideways on its own

#### Scenario: Another group on iPhone
- **GIVEN** the Guide open on iPhone, scrolled down
- **WHEN** the user picks another group in the Groups sheet
- **THEN** the sheet closes and the rows show that group's channels from the first

#### Scenario: A gap on iPhone
- **GIVEN** a gap between two programmes on a channel
- **WHEN** its row shows
- **THEN** the gap is a card with just the times

### Requirement: Nothing to show yet
The system SHALL replace the grid or list with Live's loading rows or error message while sources load or have all failed, and with a "No channels" message for an empty group.

#### Scenario: Loading, failed or empty
- **GIVEN** sources still loading, every source failed, or a group with no channels
- **WHEN** the user opens the Guide
- **THEN** the grid or list is replaced by the same loading rows or error message with Try again as Live, or by "No channels in <group>" with the toolbar, or the group button and day chips, still working
- **AND** while loading or failed, the toolbar, the group button and the day chips are hidden
