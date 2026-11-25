## ADDED Requirements

### Requirement: HEVC plays wherever the device decodes it
The system SHALL play an HEVC film or channel whenever the device's video decoder can decode its picture, on whichever path can read it, and SHALL fail it as "can't decode" only when the device has no decoder for its profile. A file Apple's player cannot decode SHALL move to the FFmpeg path with no error shown; an HLS stream SHALL NOT.

#### Scenario: An hev1 film with its parameter sets in the samples
- **GIVEN** an MP4 or Matroska film in HEVC whose configuration record lists no parameter sets, which arrive in the samples instead
- **WHEN** the user plays it
- **THEN** it plays with picture and sound

#### Scenario: Apple's player finds no decoder for a file
- **GIVEN** an MP4 film for which Apple's player reports that it found no decoder
- **WHEN** the user plays it
- **THEN** it moves to the FFmpeg path with no error shown, and plays there when the device can decode it

#### Scenario: HEVC beyond 4:2:0 in a file
- **GIVEN** an MP4 film in HEVC 4:2:2 or 4:4:4, or 12-bit
- **WHEN** the user plays it
- **THEN** it moves to the FFmpeg path at once, without waiting for Apple's player to give up
- **AND** it plays when the device's decoder handles that profile

#### Scenario: A profile the device cannot decode
- **GIVEN** a film or channel whose HEVC or H.264 profile the device has no decoder for, such as HEVC 4:2:2 on a device without one
- **WHEN** it plays
- **THEN** it fails as "can't decode" with the codec and profile named, and the screen offers the usual choices

#### Scenario: A broken configuration record
- **GIVEN** a film whose HEVC configuration record is cut short and whose samples carry no parameter sets
- **WHEN** the user plays it
- **THEN** it fails as "Stream could not be read", not as "can't decode"

#### Scenario: HLS stays with Apple's player
- **GIVEN** an HLS stream whose picture Apple's player cannot decode
- **WHEN** it plays
- **THEN** it fails as "can't decode" with the codec named and is not moved to the FFmpeg path
