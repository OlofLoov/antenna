# antenna-website Specification

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
- **WHEN** an iPhone without Antenna opens a setup link
- **THEN** the same one-line setup page as before shows, with its App Store link

#### Scenario: A folder starting with a dot
- **WHEN** the site is published
- **THEN** the association file under `/.well-known/` is published with the rest and is not left out for its folder's name

### Requirement: Setup links open Antenna
The system SHALL publish an association file that is valid JSON, names exactly one app, Antenna's app id made of a ten-character team id and the app's bundle id, and opens only `/setup` addresses in it, served as JSON from its address with no file extension and no redirect.

#### Scenario: An iPhone with Antenna scans the TV's code
- **GIVEN** an iPhone with Antenna installed
- **WHEN** the user opens a setup link from the camera
- **THEN** Antenna opens, not Safari

#### Scenario: Other addresses stay in Safari
- **WHEN** the user opens the Terms of Use link on an iPhone with Antenna
- **THEN** Safari shows the page and Antenna does not open

### Requirement: The team id placeholder never reaches the site
The system SHALL refuse to publish the site while the association file still holds the team id placeholder and no team id is configured, and SHALL refuse a configured team id that is not ten capital letters or digits.

#### Scenario: No team id set
- **GIVEN** the committed association file holds the placeholder and no team id is configured
- **WHEN** the site is published
- **THEN** publishing fails and names the missing team id, and the site keeps its previous version

#### Scenario: A team id set
- **GIVEN** a configured team id of ten capital letters or digits
- **WHEN** the site is published
- **THEN** the published association file names that team id with Antenna's bundle id

#### Scenario: A malformed team id
- **GIVEN** a configured team id with lowercase letters or the wrong length
- **WHEN** the site is published
- **THEN** publishing fails

### Requirement: The Terms of Use put the streams on the user
The system SHALL publish Terms of Use that name Code Crave as the publisher, say Antenna ships no channels, playlists or other content and plays only sources the user adds, make the user responsible for having the right to watch what they add, provide the app as is, say Apple's standard license agreement applies and these terms add to it, and say how to reach the publisher.

#### Scenario: Reading the terms
- **WHEN** someone opens the Terms of Use
- **THEN** they find sections on what Antenna is, their sources, purchases, Apple's license agreement, no warranty, limits on liability, changes to the terms and contact

#### Scenario: Who answers for a stream
- **WHEN** someone reads the section on their sources
- **THEN** it says Antenna comes with no content and they need the right to watch what they add

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
- **THEN** they find sections on what Antenna stores, logins, network connections, analytics and tracking, purchases, deleting data, children, changes to the policy and contact

#### Scenario: Where a password goes
- **WHEN** someone reads the section on logins
- **THEN** it says passwords stay in their iCloud Keychain and names the ten-minute exception for sending a login to an Apple TV

### Requirement: The Privacy Policy rules out tracking
The system SHALL say in the Privacy Policy that Antenna has no analytics, tracking, advertising or third-party SDK, that Code Crave runs no server that receives the user's data, that network requests go only to the user's sources, the addresses those sources list and Apple's services, and that Apple handles purchases.

#### Scenario: Looking for tracking
- **WHEN** someone looks for what Antenna collects about them
- **THEN** the policy says Antenna has no analytics or tracking and sends nothing to Code Crave

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
