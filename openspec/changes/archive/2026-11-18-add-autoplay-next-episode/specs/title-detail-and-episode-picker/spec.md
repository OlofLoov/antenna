## MODIFIED Requirements

### Requirement: Play an episode and come back
The system SHALL play a chosen episode from where the user stopped, save its progress as it plays, and return to the page with the episode that played last in view and everything up to date, both when the user leaves playback and when the episode ends with no next episode to play.

#### Scenario: Watch an episode
- **GIVEN** the episode list
- **WHEN** the user selects an episode, or presses Play for the up-next one
- **THEN** it plays from where they stopped and its progress is saved as it plays
- **AND** when it ends or they leave playback they are back on the page with that episode's season showing, the episode in view, and its bar, the UP NEXT mark and the Play button up to date

#### Scenario: Several episodes in a row
- **GIVEN** the user played an episode from the page and the next ones started from Up next
- **WHEN** they leave playback, or the last one ends with no next episode
- **THEN** they are back on the page with the season of the episode that played last showing and that episode in view
