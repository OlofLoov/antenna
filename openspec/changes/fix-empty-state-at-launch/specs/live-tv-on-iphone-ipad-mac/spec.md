## ADDED Requirements

### Requirement: No empty state before the channels are listed
The system SHALL keep showing each source's loading row on Live and in the Guide until the channels that loaded are in the list. "No channels yet", an empty group or "No channels match." SHALL show only once the loads that could fill them have finished.

#### Scenario: A large playlist at launch
- **GIVEN** a source with thousands of channels
- **WHEN** the user opens Antuna and the source finishes loading
- **THEN** the loading rows stay, the source reading its channel count, until the channels show in the list
- **AND** no empty message shows in between

#### Scenario: The Guide at launch
- **GIVEN** the app opens on the Guide
- **WHEN** the sources finish loading
- **THEN** the Guide shows the loading rows until the channels show, never "No channels in All channels"

#### Scenario: Nothing loaded
- **GIVEN** every source finished with no channels, failed or waits for its login
- **WHEN** the user opens Live
- **THEN** the message for that case shows at once
