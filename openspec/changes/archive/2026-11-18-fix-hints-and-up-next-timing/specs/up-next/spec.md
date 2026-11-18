## MODIFIED Requirements

### Requirement: Next episode near the end
The system SHALL show a Next episode button over the bottom right corner of a playing episode from 60 seconds before its end, when the episode is at least 5 minutes long and has a next episode. The button SHALL not pause or cover the middle of the picture, and pressing it SHALL play the next episode in the same player.

#### Scenario: The last minute
- **GIVEN** a 45-minute episode playing with a next episode
- **WHEN** it reaches 44:00
- **THEN** a Next episode button shows in the bottom right corner while the episode keeps playing
- **AND** pressing it plays the next episode in the same player, without going back to the series page

#### Scenario: The last 30 seconds
- **GIVEN** the Next episode button showing from a minute before the end
- **WHEN** the episode reaches its last 30 seconds
- **THEN** the button stays where it is until the Up next card replaces it 15 seconds before the end

#### Scenario: Earlier in the episode
- **GIVEN** an episode playing more than 60 seconds before its end
- **WHEN** the viewer looks at the picture
- **THEN** no Next episode button shows

#### Scenario: The controls show
- **GIVEN** the Next episode button showing on iPhone, iPad or Mac
- **WHEN** the viewer taps and the controls show
- **THEN** the button moves up clear of the scrubber and stays pressable

### Requirement: Up next counts down
The system SHALL replace the button with an Up next card from 15 seconds before the end, with the next episode's picture, code and title, a countdown from 10 while the episode plays, Play now and Cancel, and SHALL play the next episode in the same player at zero or on Play now. An episode shorter than 5 minutes, or with no length from the stream, SHALL show the card when it ends.

#### Scenario: The countdown runs out
- **GIVEN** a 45-minute episode playing with a next episode
- **WHEN** it reaches 44:45
- **THEN** the Up next card shows "S2 E5 · The Long Night" and "Next episode in 10", counting down once a second
- **AND** at zero the next episode starts in the same player, from where the viewer stopped in it or from the start

#### Scenario: Play now
- **GIVEN** the Up next card showing
- **WHEN** the viewer presses Play now
- **THEN** the next episode starts at once

#### Scenario: Paused
- **GIVEN** the Up next card counting down
- **WHEN** the viewer pauses
- **THEN** the count stops and goes on from the same number when they play again

#### Scenario: No picture from the provider
- **GIVEN** a next episode the provider sent no picture for
- **WHEN** the card shows
- **THEN** a tile with the episode's number takes the picture's place, as in the episode list

#### Scenario: The episode ends during the count
- **GIVEN** the card counting down
- **WHEN** the episode ends before the count reaches zero
- **THEN** the next episode starts at once

#### Scenario: A short episode or no length
- **GIVEN** a 3-minute episode, or an episode whose stream gives no length
- **WHEN** it plays and then ends
- **THEN** no button or card shows while it plays
- **AND** when it ends, the card shows over the last frame with "Next episode in 10" and the next episode starts at zero

#### Scenario: Moving back
- **GIVEN** the Next episode button or the Up next card showing
- **WHEN** the viewer skips or scrubs back to more than 60 seconds before the end
- **THEN** both go away, and the count starts again from 10 if the episode reaches the last 15 seconds again

#### Scenario: VoiceOver
- **GIVEN** VoiceOver on
- **WHEN** the card shows
- **THEN** it reads "Up next, Season 2 Episode 5, The Long Night, next episode in 10 seconds", then Play now and Cancel

### Requirement: Progress follows the next episode
The system SHALL mark the episode that was playing as watched when the next one starts, from the button, the card or the countdown, and SHALL save the next episode's place as it plays, so Continue watching, the series page's UP NEXT mark and its Play button move on. Going back to the series page SHALL show the season of the episode that played last with that episode in view.

#### Scenario: Back on the page after two episodes
- **GIVEN** the viewer played Season 1 Episode 8 from the page and the countdown started Season 2 Episode 1
- **WHEN** they leave Season 2 Episode 1 part-way
- **THEN** the series page shows Season 2 with Episode 1 in view, its bar and "Resume S2 E1"
- **AND** Season 1 Episode 8 shows Watched, even when the viewer pressed Next episode 60 seconds before its end
- **AND** Continue watching shows Season 2 Episode 1

### Requirement: Up next on the Siri Remote
The system SHALL let the viewer reach the Next episode button and the Up next card on Apple TV by swiping or clicking down, while clicks left and right keep skipping 10 seconds, play/pause keeps pausing and a slide keeps showing the bar. When the card shows, it SHALL take focus on Play now. Back with focus on the button or the card SHALL put focus back on the picture and, on the card, cancel it. Back with focus on the picture SHALL still close the episode.

#### Scenario: Reaching the button
- **GIVEN** an episode in its last minute on Apple TV with the Next episode button showing
- **WHEN** the viewer swipes down
- **THEN** the button takes focus and grows, and select plays the next episode
- **AND** Back puts focus back on the picture and the button stays

#### Scenario: The card takes focus
- **GIVEN** an episode playing on Apple TV
- **WHEN** the Up next card shows
- **THEN** Play now has focus, select plays the next episode, and clicking left or right still skips 10 seconds
- **AND** Back cancels the card and the episode plays on
