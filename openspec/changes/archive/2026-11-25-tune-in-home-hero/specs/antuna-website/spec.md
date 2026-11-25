## ADDED Requirements

### Requirement: The home page tunes in
When the home page opens, the system SHALL draw the wordmark large above the headline with the Hello motion, and show an Apple TV in a dark frame that tunes in from about a second of soft static while the wordmark's tips send out teal rings. An iPad and an iPhone SHALL stand in front of the TV showing the same screen, on a soft radial glow. The headline, the platforms and the App Store link SHALL still come before the TV.

#### Scenario: A first visit on a laptop
- **WHEN** someone opens the home page on a laptop
- **THEN** the wordmark draws itself letter by letter, the last a lands, its play triangle opens and its antennae rise with teal tips, all within 3.2 s
- **AND** the TV shows soft static for about a second, then Live TV on Apple TV snaps in as two teal rings spread from the tips
- **AND** the iPad and the iPhone in front of the TV show Live TV too

#### Scenario: Scripts turned off
- **GIVEN** a browser with scripts turned off
- **WHEN** someone opens the home page
- **THEN** the wordmark and the TV tune in as above, and then the hero stands still on Live TV

#### Scenario: A phone
- **WHEN** someone opens the home page on an iPhone
- **THEN** the headline, the platforms and the App Store link come first, then the TV across the width of the screen with the iPad and the iPhone below it, overlapping its bottom edge, and nothing scrolls sideways

#### Scenario: Moving the pointer
- **GIVEN** a laptop with a mouse or trackpad
- **WHEN** the visitor moves the pointer across the page or scrolls past the hero
- **THEN** the iPad and the iPhone shift a few pixels against the TV, the iPhone most, so they look nearer

#### Scenario: Light mode
- **GIVEN** a device in light mode
- **WHEN** someone opens the home page
- **THEN** the wordmark is dark with darker teal tips, the glow is a pale blue, and the TV and devices keep their dark frames

### Requirement: The TV zaps through the app
Every four seconds the TV, the iPad and the iPhone SHALL switch together to the next of four channels, with a short zap and the channel's number on the TV. A button under the TV SHALL pause and resume them. The channels and the drift SHALL stop while the hero is off screen or the tab is hidden, and a channel's screenshots SHALL load only when that channel is next.

#### Scenario: Watching the hero
- **WHEN** the visitor stays at the top of the home page
- **THEN** four seconds after the picture snaps in, the TV zaps to the guide, its corner shows 2, and the iPad and iPhone show the guide
- **AND** Movies and a movie playing follow, four seconds apart, and then Live TV again with 1 in the corner

#### Scenario: Pausing
- **WHEN** the visitor presses Pause channels under the TV
- **THEN** the channel on screen stays, the button reads Play channels, and pressing it again resumes the zapping four seconds later

#### Scenario: Scrolling away
- **WHEN** the visitor scrolls until the hero is out of view
- **THEN** the TV stops changing channels, and it waits four seconds after the hero comes back before the next zap

#### Scenario: The first visit's downloads
- **WHEN** someone opens the home page
- **THEN** the browser downloads one screenshot for each of the TV, the iPad and the iPhone, and the next channel's only after the picture has snapped in

#### Scenario: Another tab
- **WHEN** the visitor switches to another tab and back
- **THEN** no channels changed while the page was hidden

#### Scenario: A slow connection
- **GIVEN** the next channel's screenshots have not finished loading
- **WHEN** its turn comes
- **THEN** the TV stays on the current channel until they have, and never shows an empty screen

#### Scenario: A screen reader
- **WHEN** a screen reader reads the hero
- **THEN** it reads the headline, the lead, the App Store link, a description of each device's current screen and the pause button, and it does not announce each zap

### Requirement: The hero holds still with Reduce Motion
When the device asks for reduced motion, the hero SHALL show the still wordmark fading in over 0.4 s and the TV, iPad and iPhone on Live TV, with no static, rings, zapping, drift or pause button, and SHALL load no other channel's screenshots. With motion on, nothing in the hero SHALL flash more than three times in any one second.

#### Scenario: Reduce Motion on
- **GIVEN** Reduce Motion is on
- **WHEN** someone opens the home page
- **THEN** the wordmark fades in already drawn, the TV already shows Live TV, and nothing in the hero moves after that

#### Scenario: Turning Reduce Motion on while watching
- **GIVEN** the TV is zapping
- **WHEN** the visitor turns Reduce Motion on
- **THEN** the zapping and the drift stop on the channel on screen

#### Scenario: The static and the zap
- **WHEN** the TV tunes in or zaps
- **THEN** the static is a dim, slowly drifting grain with no bright frames, and each zap darkens and brightens the screen once, at most once every four seconds
