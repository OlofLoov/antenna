## MODIFIED Requirements

### Requirement: Up next on the Siri Remote
The system SHALL let the viewer reach the Next episode button and the Up next card on Apple TV by swiping or clicking down, before the bar's Audio and Subtitles button, while clicks left and right skip 10 seconds, play/pause pauses and a slide shows the bar. When the card shows, it SHALL take focus on Play now. Back with focus on the button or the card SHALL put focus back on the picture and, on the card, cancel it. Back with focus on the picture SHALL still close the episode.

#### Scenario: Reaching the button
- **GIVEN** an episode in its last minute on Apple TV with the Next episode button showing
- **WHEN** the viewer swipes down
- **THEN** the button takes focus and grows, and select plays the next episode
- **AND** Back puts focus back on the picture and the button stays

#### Scenario: Past the button to audio and subtitles
- **GIVEN** the Next episode button has focus
- **WHEN** the viewer swipes down again
- **THEN** the bar shows and its Audio and Subtitles button takes focus
- **AND** swiping up from it goes back to the Next episode button

#### Scenario: The card takes focus
- **GIVEN** an episode playing on Apple TV
- **WHEN** the Up next card shows
- **THEN** Play now has focus, select plays the next episode, and clicking left or right still skips 10 seconds
- **AND** Back cancels the card and the episode plays on
