## MODIFIED Requirements

### Requirement: Each screen lists its own actions
The system SHALL list the actions of the part of the screen that has the highlight, and SHALL follow the user's preferences where they change what a control does.

#### Scenario: Groups and channels in the overlay
- **GIVEN** the channel overlay is open with the highlight on a channel
- **WHEN** the viewer moves left into the groups
- **THEN** the legend changes from Click to watch, hold for Favorites, swipe left or right for groups or details and Back to close, to swipe up or down to choose a group, Click to show its channels and Back to close

#### Scenario: Swipe shows the info bar
- **GIVEN** "Swipe up or down while watching" is set to show the info bar
- **WHEN** the legend shows on Live full screen
- **THEN** swipe up or down reads "Info bar", not "Change channel"

#### Scenario: Movies and series
- **WHEN** the legend shows on the Movies rows or the Series rows
- **THEN** Click reads "Open" and hold reads "My list"

#### Scenario: Scrubbing a movie
- **GIVEN** a movie playing with the legend showing click left or right to skip 10 seconds and swipe left or right to scrub
- **WHEN** the viewer slides on the touch surface to a new place
- **THEN** the legend lists swipe left or right to move the new place, click to play from here and Back to cancel

#### Scenario: Where Back goes
- **GIVEN** the legend shows on Live full screen, the Guide, or the Movies or Series rows
- **WHEN** the viewer reads its Back line
- **THEN** it reads "Tab bar"
- **AND** with the highlight in the tab bar it reads "Home Screen"

#### Scenario: The end of an episode
- **GIVEN** an episode playing on Apple TV with the Next episode button showing
- **WHEN** the legend shows
- **THEN** it lists swipe down for the next episode in place of swipe left or right to scrub
- **AND** with focus on the button it lists Click to play the next episode and Back to keep watching

#### Scenario: Audio and subtitles in the movie player
- **GIVEN** a movie playing on Apple TV with no Next episode button
- **WHEN** the legend shows
- **THEN** it lists swipe down for audio and subtitles, and no hold
- **AND** with focus on the bar's Audio and Subtitles button it lists Click for audio and subtitles and Back to keep watching

#### Scenario: Up next
- **GIVEN** the Up next card showing with focus on Play now
- **WHEN** the legend shows
- **THEN** it lists Click to play now, click left or right to skip 10 seconds, play/pause to pause or play, and Back to cancel
- **AND** for "Still watching?" it lists Click to keep watching and Back to cancel
