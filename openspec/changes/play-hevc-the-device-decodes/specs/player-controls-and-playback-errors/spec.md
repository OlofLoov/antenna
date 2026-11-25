## ADDED Requirements

### Requirement: Format not supported names the profile
The system SHALL name the codec in "Format not supported" with its chroma format and bit depth when they are what the device cannot decode, so the viewer can tell the provider what to change.

#### Scenario: HEVC 4:2:2
- **GIVEN** a film in 10-bit HEVC 4:2:2 on a device without a decoder for it
- **WHEN** the error shows
- **THEN** it reads "This stream uses HEVC 4:2:2 10-bit, which this device cannot play." followed by the usual advice

#### Scenario: Plain HEVC
- **GIVEN** a stream the engine reports only as HEVC
- **WHEN** the error shows
- **THEN** it reads "This stream uses HEVC, which this device cannot play." as before
