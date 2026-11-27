## ADDED Requirements

### Requirement: A channel goes to AirPlay as HLS
The system SHALL play an Xtream live channel as MPEG-TS through the FFmpeg path until an AirPlay device is picked, then, when its source offers HLS, through Apple's player from its HLS link. When AirPlay ends, the channel SHALL play as MPEG-TS on the device again, with a new rewind buffer.

#### Scenario: Watching on the device
- **GIVEN** an Xtream channel whose source offers HLS, playing on iPhone, iPad, Mac or Apple TV with no AirPlay device picked
- **WHEN** the user pauses, rewinds and goes back to live
- **THEN** it plays as MPEG-TS through the FFmpeg path and pause and rewind work as for any recorded stream

#### Scenario: Picking a TV
- **GIVEN** that channel playing on an iPhone, iPad or Mac
- **WHEN** the user opens the AirPlay list
- **THEN** the channel keeps playing as MPEG-TS on the device
- **AND** when the user picks an Apple TV or AirPlay TV, the channel plays there through Apple's player from its HLS link

#### Scenario: Changing channel on AirPlay
- **GIVEN** a channel playing on an AirPlay TV
- **WHEN** the user changes to another Xtream channel whose source offers HLS, or to one that has no HLS link
- **THEN** the first plays on the TV as HLS and the second plays as MPEG-TS on the device

#### Scenario: AirPlay ends
- **GIVEN** a channel playing on an AirPlay TV
- **WHEN** the user picks the device itself in the AirPlay list, or the TV ends AirPlay
- **THEN** the channel plays as MPEG-TS on the device and its rewind buffer starts again from that moment

#### Scenario: A speaker with no screen
- **GIVEN** an Xtream channel playing on an iPhone or iPad
- **WHEN** the user picks an AirPlay speaker
- **THEN** within about 8 seconds the channel plays as MPEG-TS again, its sound on the speaker, and it stays so until the route changes

### Requirement: A source whose HLS failed cannot AirPlay
The system SHALL, when a channel's HLS link fails to start on its way to AirPlay, keep playing the channel as MPEG-TS on the device with no error and say "AirPlay not available for this stream". It SHALL remember on the device, for 7 days, that the source cannot go to AirPlay, so the AirPlay button says so on press meanwhile. It SHALL keep only the source and the date, never a link or a login. Being offline, a login not on this device and no free decoder SHALL fail as they are.

#### Scenario: The panel refuses HLS
- **GIVEN** an Xtream channel whose source offers HLS but whose panel answers 403, 404 or a web page for the HLS link, or sends no picture or sound within the start timeout
- **WHEN** the user picks an AirPlay TV
- **THEN** the channel plays on as MPEG-TS on the device with no error shown, and a short notice says "AirPlay not available for this stream"

#### Scenario: The next press
- **GIVEN** a source whose HLS failed on this device less than 7 days ago
- **WHEN** the user presses AirPlay on one of its channels
- **THEN** the AirPlay list does not open and the notice says "AirPlay not available for this stream"
- **AND** after 7 days the list opens again

#### Scenario: Other sources and devices
- **GIVEN** one source remembered on an iPhone
- **WHEN** the user presses AirPlay on another source's channel, or on the same source on an iPad
- **THEN** the AirPlay list opens

#### Scenario: What is kept
- **GIVEN** a source remembered on the device
- **WHEN** the device's settings are read
- **THEN** they hold the source's id and a date, and no address, server, username or password
