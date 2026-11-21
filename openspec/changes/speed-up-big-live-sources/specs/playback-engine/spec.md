## MODIFIED Requirements

### Requirement: Channel switching is fast
The system SHALL switch between raw broadcast channels on an Apple TV 4K (3rd generation) over Ethernet within 1.0 second for half the switches and 1.5 seconds for nine in ten, and between HLS channels on Apple's player within 2.0 seconds for half. An HLS address SHALL open on Apple's player without a request of the app's own first.

#### Scenario: Measured switches
- **GIVEN** 50 channel changes between raw broadcast streams with a keyframe every second, over wired Ethernet on an Apple TV 4K (3rd generation), and 50 between HLS streams with 2-second segments
- **WHEN** the time from asking for a channel to its first frame is measured
- **THEN** on the FFmpeg path half the switches take at most 1.0 second and nine in ten at most 1.5 seconds
- **AND** on Apple's player half take at most 2.0 seconds
- **AND** iPhone, iPad and Mac are measured for comparison only

#### Scenario: An HLS address
- **GIVEN** a channel whose address ends in .m3u8
- **WHEN** it is tuned
- **THEN** Apple's player opens it with no request from the app before it
- **AND** when the player fails, the app checks what the address sends and reports the same failure as before, such as for a web page or raw video at an HLS address
