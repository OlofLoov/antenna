## MODIFIED Requirements

### Requirement: Remote hints show what the buttons do
The system SHALL show a remote hints legend on Apple TV with the Siri Remote's symbol and, for each control that does something on the current screen, its glyph, its name and its action in a few words, two to five lines in all. It SHALL cover Live full screen, the info bar, the channel overlay, the guide, the tab bar, the Movies and Series rows, a title page, the movie and episode player, and Settings. iPhone, iPad and Mac SHALL show no legend.

#### Scenario: Live full screen
- **GIVEN** a channel playing full screen on Apple TV with nothing over it
- **WHEN** the legend shows
- **THEN** it lists Click for the channel list, swipe up or down to change channel, swipe left or right for the last channel or Recents, hold for info, audio and subtitles, and Back for the tab bar

#### Scenario: A screen without hints
- **GIVEN** the viewer is on Search on Apple TV
- **WHEN** they look for the legend
- **THEN** none shows

#### Scenario: iPhone
- **WHEN** the viewer watches a channel on iPhone, iPad or Mac
- **THEN** no remote hints show

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
- **WHEN** the legend shows on the Movies rows
- **THEN** Click reads "Play" and hold reads "More info and My list"
- **AND** on the Series rows Click reads "Open" and hold reads "My list"

#### Scenario: Scrubbing a movie
- **GIVEN** a movie playing with the legend showing click left or right to skip 10 seconds and swipe left or right to scrub
- **WHEN** the viewer slides on the touch surface to a new place
- **THEN** the legend lists swipe left or right to move the new place, click to play from here and Back to cancel

#### Scenario: Where Back goes
- **GIVEN** the legend shows on Live full screen, the Guide, or the Movies or Series rows
- **WHEN** the viewer reads its Back line
- **THEN** it reads "Tab bar"
- **AND** with the highlight in the tab bar it reads "Home Screen"
