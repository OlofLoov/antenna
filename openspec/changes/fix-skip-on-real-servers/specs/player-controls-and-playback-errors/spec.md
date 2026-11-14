## MODIFIED Requirements

### Requirement: Move around in a movie or episode
The system SHALL show the elapsed and remaining time of a playing movie or episode on a progress bar, SHALL skip back or forward 10 seconds, and SHALL move to any point the user drags or slides to, on every platform, never before the start or past the end.

#### Scenario: Skipping on iPhone and iPad
- **GIVEN** a movie playing on iPhone or iPad with the controls showing
- **WHEN** the user taps back 10 or forward 10
- **THEN** the movie moves 10 seconds that way and the times update

#### Scenario: Double tap on iPhone and iPad
- **GIVEN** a movie playing on iPhone or iPad
- **WHEN** the user double taps the left or right half of the picture
- **THEN** the movie skips back or forward 10 seconds

#### Scenario: Dragging the scrubber
- **GIVEN** the controls show on iPhone, iPad or Mac
- **WHEN** the user drags the scrubber
- **THEN** the elapsed time follows the finger or pointer while the picture stays put
- **AND** on release the movie plays from there, or stays paused there if it was paused

#### Scenario: Keys on a Mac
- **GIVEN** a movie playing on a Mac
- **WHEN** the user presses the left or right arrow key, or Space
- **THEN** the movie skips back or forward 10 seconds, or plays and pauses

#### Scenario: Clicking on Apple TV
- **GIVEN** a movie playing on Apple TV
- **WHEN** the user clicks left or right on the remote
- **THEN** the movie skips back or forward 10 seconds and the bar shows the new time

#### Scenario: Sliding while paused on Apple TV
- **GIVEN** a movie paused on Apple TV
- **WHEN** the user slides a finger left or right on the touch surface
- **THEN** a target time moves along the bar, shown above it, while the picture stays where it paused
- **AND** clicking left or right moves the target by 10 seconds
- **AND** select or play/pause plays from the target

#### Scenario: Putting the target back on Apple TV
- **GIVEN** the user moved the target time while paused on Apple TV
- **WHEN** they press Menu
- **THEN** the target goes away and the movie stays paused where it was
- **AND** the next Menu closes the movie

#### Scenario: Select on Apple TV
- **GIVEN** a movie playing on Apple TV with no target time
- **WHEN** the user clicks select
- **THEN** the movie pauses, and the next click plays it
- **AND** holding select still opens the audio and subtitles panel without pausing

#### Scenario: The ends of the title
- **GIVEN** a movie 5 seconds from its start or its end
- **WHEN** the user skips back or forward 10 seconds
- **THEN** it moves to the start, or to the end, which finishes it

#### Scenario: Back from the end
- **GIVEN** a movie that played to its end
- **WHEN** the user skips back or scrubs to an earlier point
- **THEN** it plays from there, not from the start

#### Scenario: A server that cannot skip
- **GIVEN** a movie whose server cannot jump to a point
- **WHEN** the controls show
- **THEN** the player says "This stream can't skip" with them, before the user presses anything
- **AND** skipping or scrubbing leaves the movie playing where it is and says it again for a few seconds

#### Scenario: Before the length is known
- **GIVEN** a title whose length the stream does not give
- **WHEN** the controls show
- **THEN** they show the elapsed time with no bar and no remaining time, and skipping back and forward still works

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on, on iPhone, iPad or Mac
- **WHEN** the user focuses the scrubber
- **THEN** it reads the elapsed time and the length, and swiping up or down skips forward or back 10 seconds
