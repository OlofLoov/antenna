# control-hints Specification

## Purpose
Shows Apple TV viewers what the Siri Remote does on the screen they are on, so actions without a button on screen, such as holding select for Favorites or swiping left for the last channel, are found without being told.

## Requirements

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

#### Scenario: The end of an episode
- **GIVEN** an episode playing on Apple TV with the Next episode button showing
- **WHEN** the legend shows
- **THEN** it lists swipe down for the next episode in place of swipe left or right to scrub
- **AND** with focus on the button it lists Click to play the next episode and Back to keep watching

#### Scenario: Up next
- **GIVEN** the Up next card showing with focus on Play now
- **WHEN** the legend shows
- **THEN** it lists Click to play now, click left or right to skip 10 seconds, play/pause to pause or play, and Back to cancel
- **AND** for "Still watching?" it lists Click to keep watching and Back to cancel

### Requirement: Hints fade and come back on a new screen
The system SHALL show the legend when the highlight reaches a new screen and fade it six seconds later. The info bar coming and going over the picture, and moving between the overlay's groups and channels, SHALL count as the same screen. A screen SHALL show its legend at most three times per launch, except on the first playback after a launch and on each move between Live, Movies and Series, which SHALL always show it. With Reduce Motion on, the legend SHALL appear and go without animation.

#### Scenario: Opening the guide
- **WHEN** the viewer opens the Guide
- **THEN** the guide's legend shows and fades six seconds later while the guide stays open

#### Scenario: Zapping
- **GIVEN** the legend on Live full screen has faded
- **WHEN** the viewer swipes down to the next channel and the info bar shows
- **THEN** the legend does not come back

#### Scenario: Back from the overlay
- **GIVEN** the viewer picked a channel from the overlay
- **WHEN** the picture is full screen again
- **THEN** the Live legend shows again, until it has shown three times since launch

#### Scenario: The first thing played
- **GIVEN** the app just launched and the viewer browsed Movies and a title page
- **WHEN** they play a movie
- **THEN** the player's legend shows and fades six seconds later

#### Scenario: Switching to another section
- **GIVEN** the Movies legend has shown three times since launch
- **WHEN** the viewer goes up to the tab bar and opens Series, then Movies again
- **THEN** the Series legend shows, then the Movies legend shows again, each fading six seconds later

#### Scenario: Back in the same section
- **GIVEN** the Movies legend has shown three times since launch
- **WHEN** the viewer opens a title page, plays the movie and goes back to the Movies rows
- **THEN** the Movies legend does not show again

#### Scenario: From the guide to Live
- **GIVEN** the Live legend has shown three times since launch
- **WHEN** the viewer picks a channel in the Guide
- **THEN** the Live legend does not show again, because the guide is part of Live

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

### Requirement: Turn remote hints off
The system SHALL offer "Show remote hints" in Settings on Apple TV, on until the viewer switches it off. The choice SHALL stay on that Apple TV and SHALL not sync to other devices.

#### Scenario: Switching hints off
- **GIVEN** the legend is showing in Settings
- **WHEN** the viewer switches "Show remote hints" off
- **THEN** the legend goes at once and does not show on any screen after Settings closes

#### Scenario: Switching hints on again
- **WHEN** the viewer switches it back on
- **THEN** the legend for Settings shows straight away

#### Scenario: A second Apple TV
- **GIVEN** hints are off on the living-room Apple TV
- **WHEN** the viewer opens the app on the bedroom Apple TV with the same Apple Account
- **THEN** hints are on there
