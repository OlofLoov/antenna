# antuna-website Specification

## Purpose
The small static site at the app's own domain: the setup page, the file that lets setup links open the app, and the Terms of Use and Privacy Policy the paywall links to.

## Requirements

### Requirement: The site answers every address the app uses
The system SHALL publish, on the app's domain over HTTPS, the setup page at `/setup`, the Terms of Use at `/terms`, the Privacy Policy at `/privacy` and the association file at `/.well-known/apple-app-site-association`, and the domain the site is published under SHALL be the one the app's setup links and legal links use.

#### Scenario: The paywall's links
- **GIVEN** the paywall on iPhone or Apple TV
- **WHEN** the user follows Terms of Use or Privacy Policy
- **THEN** a page with that title opens at the app's domain

#### Scenario: The setup page stays
- **WHEN** an iPhone without Antuna opens a setup link
- **THEN** the same one-line setup page as before shows, with its App Store link

#### Scenario: A folder starting with a dot
- **WHEN** the site is published
- **THEN** the association file under `/.well-known/` is published with the rest and is not left out for its folder's name

### Requirement: Setup links open Antuna
The system SHALL publish an association file that is valid JSON, names exactly one app, Antuna's app id made of a ten-character team id and the app's bundle id, and opens only `/setup` addresses in it, served as JSON from its address with no file extension and no redirect.

#### Scenario: An iPhone with Antuna scans the TV's code
- **GIVEN** an iPhone with Antuna installed
- **WHEN** the user opens a setup link from the camera
- **THEN** Antuna opens, not Safari

#### Scenario: Other addresses stay in Safari
- **WHEN** the user opens the Terms of Use link on an iPhone with Antuna
- **THEN** Safari shows the page and Antuna does not open

### Requirement: The team id placeholder never reaches the site
The system SHALL refuse to publish the site while the association file still holds the team id placeholder and no team id is configured, and SHALL refuse a configured team id that is not ten capital letters or digits.

#### Scenario: No team id set
- **GIVEN** the committed association file holds the placeholder and no team id is configured
- **WHEN** the site is published
- **THEN** publishing fails and names the missing team id, and the site keeps its previous version

#### Scenario: A team id set
- **GIVEN** a configured team id of ten capital letters or digits
- **WHEN** the site is published
- **THEN** the published association file names that team id with Antuna's bundle id

#### Scenario: A malformed team id
- **GIVEN** a configured team id with lowercase letters or the wrong length
- **WHEN** the site is published
- **THEN** publishing fails

### Requirement: The Terms of Use put the streams on the user
The system SHALL publish Terms of Use that name Code Crave as the publisher, say Antuna ships no channels, playlists or other content and plays only sources the user adds, make the user responsible for having the right to watch what they add, provide the app as is, say Apple's standard license agreement applies and these terms add to it, and say how to reach the publisher.

#### Scenario: Reading the terms
- **WHEN** someone opens the Terms of Use
- **THEN** they find sections on what Antuna is, their sources, purchases, Apple's license agreement, no warranty, limits on liability, changes to the terms and contact

#### Scenario: Who answers for a stream
- **WHEN** someone reads the section on their sources
- **THEN** it says Antuna comes with no content and they need the right to watch what they add

### Requirement: The Terms of Use explain the purchases
The system SHALL say in the Terms of Use that the yearly subscription renews automatically until canceled in the user's Apple Account settings, the lifetime unlock is paid once, both can be shared with Family Sharing, and Apple takes the payment and handles refunds.

#### Scenario: Canceling the subscription
- **WHEN** someone looks for how to stop the yearly subscription renewing
- **THEN** the purchases section says to cancel in their Apple Account's subscription settings at least 24 hours before it renews, and that refunds are requested from Apple

#### Scenario: Sharing with the family
- **WHEN** someone reads the purchases section
- **THEN** it says both purchases can be shared with their Family Sharing group

### Requirement: The Privacy Policy says where data is kept
The system SHALL publish a Privacy Policy that names Code Crave as the publisher and says sources, favorites, preferences, reminders, groups and watch progress sync through the user's own private iCloud where Code Crave cannot read them, logins stay in the user's iCloud Keychain except a sealed login sent from an iPhone to an Apple TV that waits in the user's private iCloud for at most ten minutes, how to delete the data, and how to reach the publisher.

#### Scenario: Reading the policy
- **WHEN** someone opens the Privacy Policy
- **THEN** they find sections on what Antuna stores, logins, network connections, analytics and tracking, purchases, deleting data, children, changes to the policy and contact

#### Scenario: Where a password goes
- **WHEN** someone reads the section on logins
- **THEN** it says passwords stay in their iCloud Keychain and names the ten-minute exception for sending a login to an Apple TV

### Requirement: The Privacy Policy rules out tracking
The system SHALL say in the Privacy Policy that Antuna has no analytics, tracking, advertising or third-party SDK, that Code Crave runs no server that receives the user's data, that network requests go only to the user's sources, the addresses those sources list and Apple's services, and that Apple handles purchases.

#### Scenario: Looking for tracking
- **WHEN** someone looks for what Antuna collects about them
- **THEN** the policy says Antuna has no analytics or tracking and sends nothing to Code Crave

#### Scenario: Where the app connects
- **WHEN** someone reads the section on network connections
- **THEN** it lists their sources, addresses their sources list such as logos and guides, and Apple

### Requirement: The legal pages are dated and link to each other
The system SHALL show a "Last updated" date near the top of the Terms of Use and of the Privacy Policy, and each SHALL link to the other.

#### Scenario: Moving between the pages
- **GIVEN** the Terms of Use is open
- **WHEN** the user follows the Privacy Policy link
- **THEN** the Privacy Policy opens, and its own link leads back

#### Scenario: Checking the date
- **WHEN** someone opens either page
- **THEN** a "Last updated" line with a full date shows under the title

### Requirement: The pages read on a phone and in dark mode
The system SHALL lay out every page at the width of the device without zooming, follow the device's light or dark appearance on the legal pages, and load no scripts, images, fonts or other files from any address.

#### Scenario: A phone in dark mode
- **GIVEN** an iPhone in dark mode
- **WHEN** the user opens the Privacy Policy
- **THEN** the text is light on a dark background, fits the screen, and needs no sideways scrolling

#### Scenario: A phone in light mode
- **GIVEN** an iPhone in light mode
- **WHEN** the user opens the Terms of Use
- **THEN** the text is dark on a light background

#### Scenario: Nothing else loads
- **WHEN** any page opens
- **THEN** the browser makes no request beyond the page itself

### Requirement: The site publishes from main
The system SHALL publish the site when a change to it lands on main, and only then.

#### Scenario: A change to a page lands
- **WHEN** a pull request that edits the Privacy Policy merges to main
- **THEN** the published Privacy Policy shows the edit after the publish run

#### Scenario: A change elsewhere lands
- **WHEN** a pull request that touches only app code merges
- **THEN** the site is not published again

### Requirement: The header shows the wordmark
Every page of the site SHALL show the Antuna wordmark in its header, linking home, in near-white letters with teal tips on the dark page and near-black letters with darker teal tips on the light page. Screen readers SHALL read it as "Antuna". The browser tab SHALL show the app icon.

#### Scenario: Dark mode
- **GIVEN** a visitor whose device is in dark mode
- **WHEN** they open any page
- **THEN** the header shows the light wordmark on the dark page, with the page showing through the play triangle

#### Scenario: Light mode
- **GIVEN** a visitor whose device is in light mode
- **WHEN** they open any page
- **THEN** the header shows the dark wordmark with darker teal tips

#### Scenario: A screen reader
- **WHEN** a screen reader reaches the header
- **THEN** it reads a link named "Antuna"

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
