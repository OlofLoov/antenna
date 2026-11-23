## ADDED Requirements

### Requirement: Reopen on the title watched last
The system SHALL open the page of the movie or series the current profile watched last on this device when the app launches and that watch was a movie or an episode: in Movies or Series on iPhone, iPad and Mac, and after the "Who's watching?" screen on Apple TV. The page SHALL show a series on the season of the episode watched last, offer Resume as the page does when opened by hand, and start nothing. Back SHALL go to the section's rows.

#### Scenario: An episode stopped part-way on iPhone
- **GIVEN** the user stopped Harbor Watch Season 1 Episode 1 part-way on an iPhone and watched nothing after it
- **WHEN** they open Antenna on that iPhone
- **THEN** Series opens with Harbor Watch's page on Season 1, Play reads "Resume S1 E1" with its progress bar, and nothing plays

#### Scenario: A movie on Apple TV
- **GIVEN** Dad stopped a movie part-way on this Apple TV and watched nothing after it
- **WHEN** Dad is chosen at launch
- **THEN** Movies opens with the movie's page, Resume has focus with its progress bar, and no channel plays full screen

#### Scenario: Back from the page
- **GIVEN** the app opened on a title's page at launch
- **WHEN** the user goes back with Menu, the back button, an edge swipe or Escape
- **THEN** the section shows its rows, as after closing a page opened from the banner

#### Scenario: A finished episode
- **GIVEN** the episode watched last was played to the end and the next one is in the following season
- **WHEN** the app opens on the series' page
- **THEN** the season of the finished episode shows, and Play names the next episode as it does when the user comes back from playback

#### Scenario: Another profile
- **GIVEN** Dad last watched a movie on this Apple TV and Kids last watched a channel
- **WHEN** Kids is chosen at launch
- **THEN** Kids' channel plays full screen and Dad's movie page does not open

### Requirement: A title that cannot open gives way
The system SHALL open no title page at launch, and launch as it would without one, when the title is gone, its source fails, its section has not listed it within 10 seconds, or the user opened something else first. A launch screen other than Live, onboarding's Browse movies and a Top Shelf link SHALL each win over the title.

#### Scenario: The title is gone
- **GIVEN** the title watched last is no longer in its source, or its source failed, is offline or is waiting for its login
- **WHEN** the user opens Antenna
- **THEN** no page opens; iPhone, iPad and Mac show the section, and Apple TV plays the last channel, or the first channel of the first source to load

#### Scenario: A slow source
- **GIVEN** the section has not listed the title 10 seconds after launch
- **WHEN** the title's source finishes later
- **THEN** no page opens, and on Apple TV the last channel has started as it does without a title

#### Scenario: The user moves on first
- **GIVEN** the app is waiting for the section to list the title
- **WHEN** the user opens another tab or another page before it arrives
- **THEN** the title's page does not open

#### Scenario: Another launch screen
- **GIVEN** the launch screen in Preferences is the Guide or Movies, or onboarding's Browse movies or a Top Shelf link opened the app
- **WHEN** the app launches
- **THEN** that screen or link wins and no title page opens

### Requirement: What was watched last
The system SHALL keep, for each profile on each device, whether a live channel or a movie or episode was watched last: a channel once it counts as watched after ten seconds, a movie or episode once it starts playing. It SHALL keep only which source, title and episode, never a stream link or login, SHALL never sync it, and SHALL forget it when its source is deleted on this device or another one.

#### Scenario: A movie, then a channel
- **GIVEN** the user played a movie and then watched a channel
- **WHEN** the channel has played for ten seconds and the user opens Antenna again later
- **THEN** the launch is the one for a channel; before those ten seconds it is the one for the movie

#### Scenario: Things that do not count
- **GIVEN** a trailer, a multi-view tile, the Guide's small picture, or a channel loaded behind a title page at launch
- **WHEN** it plays or loads
- **THEN** what was watched last does not change

#### Scenario: An episode from Up next
- **GIVEN** an episode started from the title page and the next one started from Up next
- **WHEN** the user opens Antenna again
- **THEN** the series page shows the season of the episode that started last

#### Scenario: Nothing kept or damaged
- **GIVEN** nothing kept yet, or a kept value that cannot be read
- **WHEN** the user opens Antenna
- **THEN** it launches as for a channel, without an error

#### Scenario: The source is deleted
- **GIVEN** a profile last watched a title from a source
- **WHEN** that source is deleted, here or on another device
- **THEN** the title is forgotten and the next launch is the one for a channel

## MODIFIED Requirements

### Requirement: Reopen on the same tab and group
The system SHALL reopen iPhone, iPad and Mac on the tab and Live group the user last had open, unless the last watch was a movie or an episode, which opens that title's section and page instead.

#### Scenario: Reopen the app
- **GIVEN** the user last had a tab and a channel group open on iPhone, iPad or Mac, and last watched a channel or nothing
- **WHEN** they open Antenna again
- **THEN** the same tab is shown, and Live shows the same group

#### Scenario: Last watched a title
- **GIVEN** the user last had Live open but last watched a movie from Search
- **WHEN** they open Antenna again
- **THEN** Movies opens with the movie's page, and Live still shows the same group when they go to it

#### Scenario: A tab that is not restored
- **GIVEN** the user was last on Search or Settings, or on Movies or Series with no source that has them
- **WHEN** they open Antenna again
- **THEN** Antenna opens on Live

#### Scenario: The group is gone or still loading
- **GIVEN** the restored group no longer exists, or its source is still loading
- **WHEN** Live opens
- **THEN** All channels shows, and a group that arrives later is selected unless the user picked one meanwhile

#### Scenario: The group disappears while on screen
- **GIVEN** Live on screen with a group selected
- **WHEN** that group disappears
- **THEN** All channels is shown and the playing channel carries on
