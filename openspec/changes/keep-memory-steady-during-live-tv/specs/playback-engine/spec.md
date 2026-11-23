## ADDED Requirements

### Requirement: Live playback keeps memory steady
The system SHALL keep the memory it uses for a live channel on the FFmpeg path about the same for as long as the channel plays, whatever its bit rate and whether it is interlaced or paused behind live, so the app is never closed by the system for using too much memory.

#### Scenario: A channel left on for hours
- **GIVEN** a live channel playing from the local buffer on Apple TV
- **WHEN** it plays for hours without a channel change
- **THEN** the app's memory stays where it was a minute after the channel started
- **AND** the channel plays on without the app closing

#### Scenario: A channel played straight from the connection
- **GIVEN** a live channel that is not recorded, as in a multi-view tile or on a device short of storage
- **WHEN** it plays for hours
- **THEN** the app's memory stays where it was a minute after the channel started

#### Scenario: An interlaced channel
- **GIVEN** a live channel in 1080i or 576i, deinterlaced on the GPU
- **WHEN** it plays for hours
- **THEN** the app's memory stays where it was a minute after the channel started
