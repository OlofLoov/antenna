# Spec Delta

## MODIFIED Requirements

### Requirement: Back to the last channel on launch
The system SHALL play the channel last watched on this Apple TV full screen at launch once its source has loaded. If it no longer exists, or its source has not loaded within 10 seconds, the first channel of the first source to load SHALL play instead. A channel whose internal id still contains its stream link SHALL not be remembered as the last channel.

#### Scenario: Last channel available
- **GIVEN** the user watched a channel on this Apple TV before
- **WHEN** they open Antenna and its source has loaded
- **THEN** that channel plays full screen

#### Scenario: Last channel gone or late
- **GIVEN** the last channel no longer exists, or its source has not loaded within 10 seconds
- **WHEN** the user opens Antenna
- **THEN** the first channel of the first source to load plays instead

#### Scenario: Later sources and coming back
- **GIVEN** a channel is already playing
- **WHEN** another source finishes loading, or the app returns from the background
- **THEN** the channel does not change

#### Scenario: Last watched an M3U channel with a stream link in its id
- **GIVEN** the last channel watched on this Apple TV came from an M3U playlist whose ids still contain the stream link
- **WHEN** the user opens Antenna
- **THEN** that channel is not remembered, the first channel of the first source to load plays instead, and no error is shown
