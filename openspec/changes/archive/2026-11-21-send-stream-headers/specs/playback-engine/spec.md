## ADDED Requirements

### Requirement: Streams are asked for with their headers
The system SHALL send a stream's headers from its playlist, and its source's User-Agent when one is set, on every request for the stream on both players, the first look at the stream, seeks and reconnects included. A channel's own headers SHALL win over its source's.

#### Scenario: A panel that allows one player
- **GIVEN** a channel whose playlist asks for User-Agent "VLC/3.0.20", on a server that refuses any other
- **WHEN** the user plays it, on Apple's player or the FFmpeg path
- **THEN** every request for the stream carries that User-Agent and the channel plays

#### Scenario: A source's User-Agent
- **GIVEN** a source with the User-Agent "Box/1" and a channel on its server with no headers of its own
- **WHEN** the user plays the channel, or its catch-up
- **THEN** the requests carry "Box/1"

#### Scenario: The channel's own header wins
- **GIVEN** that source and a channel whose playlist asks for User-Agent "VLC/3.0.20"
- **WHEN** the user plays it
- **THEN** the requests carry "VLC/3.0.20"
