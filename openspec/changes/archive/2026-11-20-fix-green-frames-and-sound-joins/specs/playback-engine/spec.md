## ADDED Requirements

### Requirement: Undecodable pictures are not shown
The system SHALL show only pictures the device can decode in full on the FFmpeg path: pictures that depend on pictures it never read are left out, and the picture goes on from the next picture that is whole.

#### Scenario: Starting or skipping into a 4K film
- **GIVEN** an HEVC film encoded with open GOPs, as UHD films often are
- **WHEN** it starts, resumes or skips to a point between two keyframes
- **THEN** the first picture shown is the keyframe, with no green or broken picture before or after it

#### Scenario: A Dolby Vision film
- **GIVEN** an HEVC film that carries a Dolby Vision enhancement layer and its metadata in the same track
- **WHEN** it plays on the FFmpeg path
- **THEN** its base layer plays as HDR10 or SDR, with no green blocks

#### Scenario: A channel that loses data
- **GIVEN** a raw broadcast stream that loses packets on the way
- **WHEN** a picture arrives with data missing
- **THEN** the last whole picture stays on screen until the next keyframe, and the channel plays on from there with no green or smeared blocks

#### Scenario: The decoder stops
- **GIVEN** a channel or film playing on the FFmpeg path
- **WHEN** the device's video decoder fails on a picture, or needs restarting after the app comes back from the background
- **THEN** the picture goes on from the next keyframe, with no broken picture in between

### Requirement: Film sound plays without clicks
The system SHALL play the sound of a film or channel as one unbroken stream when its times are within a few milliseconds of each other, and SHALL name every speaker of 5.1, 6.1 and 7.1 sound as the stream does.

#### Scenario: TrueHD or DTS in a Matroska film
- **GIVEN** a Matroska film with Dolby TrueHD or DTS sound, whose container times are rounded to the millisecond
- **WHEN** it plays
- **THEN** the sound plays with no clicks, crackle or gaps, and stays in step with the picture

#### Scenario: 7.1 sound on a receiver
- **GIVEN** a film with 7.1 TrueHD sound
- **WHEN** it plays on an Apple TV connected to a 7.1 receiver
- **THEN** the side and back channels come out of the side and back speakers
