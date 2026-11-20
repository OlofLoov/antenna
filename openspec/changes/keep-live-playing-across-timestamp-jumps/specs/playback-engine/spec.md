## ADDED Requirements

### Requirement: Live keeps playing across a timestamp jump
The system SHALL keep a live broadcast on the FFmpeg path playing when the stream's clock jumps forward or back or wraps around, with picture and sound in step and no pause longer than the wait for the next whole picture.

#### Scenario: An ad break or a feed switch
- **GIVEN** a live channel playing
- **WHEN** the provider switches to another feed and the stream's clock jumps forward or back by seconds or hours
- **THEN** the picture and sound carry on from the new feed without freezing, going silent or dropping the channel
- **AND** the sound stays in step with the picture

#### Scenario: The new feed starts between keyframes
- **GIVEN** a live channel playing
- **WHEN** the clock jumps and the new feed does not start on a keyframe
- **THEN** the last whole picture stays on screen until the new feed's first keyframe, with no green or broken picture

#### Scenario: A channel left on for more than a day
- **GIVEN** a broadcast stream whose clock wraps back to zero every 26.5 hours
- **WHEN** the clock wraps while the channel plays
- **THEN** the channel plays on with no pause or jump

### Requirement: Sound that starts late is played
The system SHALL play the sound of a live broadcast on the FFmpeg path when it starts after the picture, and SHALL go on to another sound of the channel when the one that plays stops while the other goes on.

#### Scenario: Sound that appears after the picture
- **GIVEN** a live channel that starts with picture only
- **WHEN** a sound track appears in the stream
- **THEN** it plays within a moment, in step with the picture
- **AND** the audio list and the sound format on screen show it

#### Scenario: The program moves its sound
- **GIVEN** a live channel playing with sound
- **WHEN** the broadcast moves the program's sound to another track and the old one stops
- **THEN** the sound goes on from the new track within two seconds, chosen by the user's languages as at the start
- **AND** the audio list shows the new track as the one that plays

### Requirement: Audio description is not the default sound
The system SHALL pass over sound marked as audio description when it chooses the sound a stream starts with, as long as the stream has other sound. The described track stays in the audio list.

#### Scenario: A channel with a described track first
- **GIVEN** a channel whose first sound track is English audio description and whose second is the main English sound
- **WHEN** it starts
- **THEN** the main English sound plays
- **AND** the audio list has both tracks

#### Scenario: Only described sound
- **GIVEN** a stream whose only sound is audio description
- **WHEN** it starts
- **THEN** that sound plays
