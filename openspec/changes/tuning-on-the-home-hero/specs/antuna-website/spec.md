## MODIFIED Requirements

### Requirement: The home page tunes in
When the home page opens, the system SHALL draw the wordmark large above the headline, and show an Apple TV in a dark frame that searches for a signal in soft static while the wordmark plays Tuning. The picture SHALL snap in as the wordmark plays Got it, and the wordmark SHALL then stand still. An iPad and an iPhone SHALL stand in front of the TV showing the same screen, on a soft radial glow. The headline, the platforms and the App Store link SHALL still come before the TV.

#### Scenario: A first visit on a laptop
- **WHEN** someone opens the home page on a laptop
- **THEN** the wordmark draws itself letter by letter, the last a lands, its play triangle opens and its antennae rise with teal tips
- **AND** the TV shows soft static while the antennae lean one way and the other, the tips send out faint teal rings, the triangle moves forward to be an eye that looks the way they lean and blinks, and the mouth opens and closes slowly
- **AND** about four seconds after the page opens, Live TV on Apple TV snaps in as the tail flicks, the tips hop and the eye squints and slides back to be the play triangle
- **AND** the iPad and the iPhone in front of the TV show Live TV too

#### Scenario: After the picture
- **WHEN** the picture has snapped in
- **THEN** the wordmark stands still with the play triangle in the middle and no eye, and stays still while the TV zaps

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
- **THEN** the wordmark is dark with darker teal tips, its triangle, eye and mouth show the page's ground, the glow is a pale blue, and the TV and devices keep their dark frames

#### Scenario: Safari
- **WHEN** someone opens the home page in Safari
- **THEN** the triangle, the eye and the mouth move as they do in other browsers

### Requirement: The TV zaps through the app
Every four seconds the TV, the iPad and the iPhone SHALL switch together to the next of four channels, with a short zap and the channel's number on the TV. A button under the TV SHALL pause and resume them, and also the tune-in and the wordmark while they play. The tune-in, the wordmark, the channels and the drift SHALL stop while the hero is off screen or the tab is hidden, and a channel's screenshots SHALL load only when that channel is next.

#### Scenario: Watching the hero
- **WHEN** the visitor stays at the top of the home page
- **THEN** four seconds after the picture snaps in, the TV zaps to the guide, its corner shows 2, and the iPad and iPhone show the guide
- **AND** Movies and a movie playing follow, four seconds apart, and then Live TV again with 1 in the corner

#### Scenario: Pausing
- **WHEN** the visitor presses Pause channels under the TV
- **THEN** the channel on screen stays, the button reads Play channels, and pressing it again resumes the zapping four seconds later

#### Scenario: Pausing the tune-in
- **GIVEN** the TV is still searching for a signal
- **WHEN** the visitor presses Pause channels
- **THEN** the static and the wordmark stop where they are, and Play channels carries them on from there

#### Scenario: Scrolling away
- **WHEN** the visitor scrolls until the hero is out of view
- **THEN** the TV stops changing channels, and it waits four seconds after the hero comes back before the next zap

#### Scenario: Opened in a background tab
- **WHEN** the home page opens in a tab the visitor is not looking at
- **THEN** the tune-in stops as soon as the page's script runs, and carries on from there when the visitor switches to the tab

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
