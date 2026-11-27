## ADDED Requirements

### Requirement: Films keep memory steady
The system SHALL keep the memory it uses for a film or episode on the FFmpeg path about the same from start to end, however much faster than the film's bit rate the server sends, so the app is never closed by the system for using too much memory.

#### Scenario: A 4K episode from a fast server
- **GIVEN** a 4K episode in Matroska from a server that sends many times faster than it plays
- **WHEN** it plays for ten minutes or more
- **THEN** the app's memory stays where it was a minute after the episode started
- **AND** the episode plays on without the app closing

#### Scenario: A film paused for a long time
- **GIVEN** a film playing on the FFmpeg path
- **WHEN** it is paused for several minutes and then played
- **THEN** it goes on from where it was paused, even when the server closed the connection meanwhile

#### Scenario: A film that cannot be read ahead
- **GIVEN** a film played from its connection, as when the device has almost no free space
- **WHEN** the server sends faster than it plays
- **THEN** the app holds a few tens of megabytes of it at most, and the film plays on

### Requirement: Films read ahead to disk
The system SHALL read a film or episode on the FFmpeg path a few minutes ahead of where it plays, into storage on the device rather than memory, so a server that slows for a while does not stop the picture. A skip within what is read ahead SHALL need nothing from the server. What is read ahead SHALL be deleted when the film stops.

#### Scenario: A server that slows down
- **GIVEN** a film playing with minutes read ahead
- **WHEN** the server sends slower than the film plays for a minute
- **THEN** the picture plays on without buffering

#### Scenario: A skip back
- **GIVEN** a film that has played for a while
- **WHEN** the user skips back a little or forward within what is read ahead
- **THEN** it plays from there without a new request to the server

#### Scenario: A skip far ahead
- **GIVEN** a film playing with minutes read ahead
- **WHEN** the user skips past what is read ahead
- **THEN** it plays from there and reads ahead again from that place

#### Scenario: Little free space
- **GIVEN** a device with little free storage
- **WHEN** a film plays
- **THEN** it reads ahead less, leaving the device at least a gigabyte free, or plays from its connection when there is no room at all

#### Scenario: The film stops
- **GIVEN** a film reading ahead
- **WHEN** the user stops it, plays something else or the app starts again
- **THEN** what was read ahead is deleted
