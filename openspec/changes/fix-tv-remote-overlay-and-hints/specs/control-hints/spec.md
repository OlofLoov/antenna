## MODIFIED Requirements

### Requirement: Hints stay out of the way
The system SHALL draw the legend in one place on every screen that shows it: top right inside the TV safe area, under the row the clock takes, so it covers neither the clock, the info bar nor the movie player's bar. The legend SHALL never take focus or block a press, SHALL use the platform's caption text style, and VoiceOver SHALL read it as one sentence.

#### Scenario: The same place everywhere
- **GIVEN** remote hints are on
- **WHEN** the legend shows over full-screen video, the info bar, the channel overlay, the tab bar, the guide, Movies, Series, a title page, the movie player or Settings
- **THEN** its top right corner sits 80 points from the right edge and 124 from the top on each of them

#### Scenario: The info bar
- **GIVEN** the info bar along the bottom of the picture
- **WHEN** the legend shows
- **THEN** it sits in the top right corner, clear of the bar

#### Scenario: Focus
- **GIVEN** the legend is showing
- **WHEN** the viewer swipes or clicks
- **THEN** the press acts on the screen as if the legend were not there

#### Scenario: VoiceOver
- **WHEN** VoiceOver reads the legend on a title page
- **THEN** it hears "Remote: Click, Play or choose. Back, Back."
