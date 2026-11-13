# app-release Specification

## Purpose
How a version of Antenna is approved and published, which version the apps
report, what each app bundle declares about privacy, and the test source App
Review uses.

## Requirements

### Requirement: A release waits for the owner
The system SHALL keep one release pull request open while main has changes
that have not been released, listing them by kind, and SHALL release nothing
until the owner merges it.

#### Scenario: A feature lands
- **WHEN** a pull request with a new feature merges to main
- **THEN** the release pull request lists the feature under Features and proposes the next minor version

#### Scenario: Only fixes land
- **WHEN** the only changes since the last release are fixes
- **THEN** the release pull request proposes the next patch version

#### Scenario: Only housekeeping lands
- **WHEN** the only changes since the last release are docs, tests, CI or chores
- **THEN** no release pull request is opened for them

#### Scenario: The release pull request passes the repo's checks
- **WHEN** the release pull request is opened or updated
- **THEN** its title and its commit pass the commit message rules every other pull request follows

### Requirement: Merging the release pull request publishes the release
The system SHALL, when the owner merges the release pull request, tag that
commit with the version, publish a GitHub release whose notes are the
changelog entry, and upload nothing to the App Store.

#### Scenario: The owner approves
- **WHEN** the owner merges the release pull request for 0.2.0
- **THEN** main has a tag v0.2.0 and a GitHub release named for it with the same notes as the changelog

#### Scenario: Nothing goes to Apple
- **WHEN** a release is published
- **THEN** no build is archived or uploaded to App Store Connect or TestFlight

### Requirement: Every bundle reports the release version
The system SHALL give the iPhone, iPad, Mac and Apple TV apps and the Top
Shelf extension the version of the last merged release pull request, from
one place the release process updates.

#### Scenario: Building a release
- **WHEN** release 0.2.0 is merged and the apps are built from that commit
- **THEN** each app and the Top Shelf extension report version 0.2.0

#### Scenario: Extension and app agree
- **WHEN** the Apple TV app is built
- **THEN** the Top Shelf extension inside it has the same version as the app

### Requirement: Each bundle declares its privacy
The system SHALL ship a privacy manifest in each app and in the Top Shelf
extension that says Antenna does not track, collects no data, contacts no
tracking domain, and names a permitted reason for each required-reason API
the bundle calls.

#### Scenario: Reading the manifest
- **WHEN** someone opens the built Apple TV app
- **THEN** the app and its Top Shelf extension each contain a privacy manifest saying no tracking and no collected data

#### Scenario: An API that needs a reason
- **WHEN** a bundle checks free disk space, reads file dates or uses its own preferences
- **THEN** its privacy manifest lists that kind of API with the reason that matches the use

### Requirement: App Review gets a test source outside the app
The system SHALL serve a reviewer playlist and a matching guide from the
Antenna site, made only of freely available public test streams, and SHALL
not name, bundle or link that playlist anywhere in the app.

#### Scenario: The reviewer adds the source
- **GIVEN** a reviewer with the address from the review notes
- **WHEN** they add it as a playlist source and enter nothing else
- **THEN** Live lists the test channels, each plays, and the guide shows programmes for them from the guide address the playlist names

#### Scenario: Searching the app for the playlist
- **WHEN** someone searches the app's code and resources for the reviewer playlist's address
- **THEN** it is not there

### Requirement: The reviewer guide covers the coming weeks
The system SHALL publish the reviewer guide with programmes from the day it
publishes until at least four weeks later, and SHALL publish it again after
every release.

#### Scenario: A release is approved
- **WHEN** a release is published
- **THEN** the site publishes again and the reviewer guide starts on that day

#### Scenario: A reviewer opens the guide during review
- **GIVEN** a release published 10 days ago
- **WHEN** the reviewer opens the guide
- **THEN** every test channel shows what is on now and next

### Requirement: Every app shows its icon
Antenna on iPhone, iPad, Mac and Apple TV MUST show the Antenna icon wherever the system shows an app icon: the Home Screen, the Dock, Settings, Spotlight, the App Switcher and the App Store. The icon MUST contain no text and no third-party mark.

#### Scenario: Installing on iPhone
- **WHEN** the user installs Antenna on an iPhone or iPad
- **THEN** the Home Screen shows the Antenna icon, not the blank placeholder

#### Scenario: Opening on a Mac
- **WHEN** the user opens Antenna on a Mac
- **THEN** the Dock and Finder show the Antenna icon, and the mark is still recognizable at 16 pixels in a list

#### Scenario: Focusing the icon on Apple TV
- **WHEN** the user moves focus to Antenna on the Apple TV Home Screen
- **THEN** the icon lifts and its layers shift apart as the user moves a finger on the Siri Remote

#### Scenario: Top Shelf with nothing to list
- **GIVEN** Antenna sits in the top row on Apple TV and has no favorites or recents to show
- **WHEN** the user focuses it
- **THEN** the Top Shelf shows the Antenna mark on the dark ground instead of an empty area

### Requirement: The icon follows the Home Screen appearance
On iPhone, iPad and Mac the icon MUST have a dark, a tinted and a clear version in which the mark stays legible, matching the icon appearance the user picked.

#### Scenario: Dark icons
- **WHEN** the user sets Home Screen icons to dark
- **THEN** Antenna's icon shows the blue mark on a black ground

#### Scenario: Tinted icons
- **WHEN** the user sets Home Screen icons to tinted with any color
- **THEN** Antenna's mark shows in that tint and stays readable at Home Screen size
