# Spec Delta

## Purpose

Lets a household that shares one Apple TV keep each person's sources, logins, favorites, history and progress separate, by running Antenna as whichever Apple TV user is current instead of adding a profile picker of its own.

## ADDED Requirements

### Requirement: Antenna runs as the person using the Apple TV
The system SHALL run the Apple TV app as the current Apple TV user, and SHALL leave the iPhone, iPad and Mac app unchanged.

#### Scenario: Read the apps' permissions
- **GIVEN** the Apple TV app and the iPhone, iPad and Mac app as built
- **WHEN** their system permissions are read
- **THEN** the Apple TV app is opted in to running as the current user, and the other apps are not

### Requirement: No profile picker of Antenna's own
The system SHALL open on the same screen it would without per-user storage, and SHALL never show a profile chooser of its own.

#### Scenario: Open in any setup state
- **GIVEN** an Apple TV with no sources, with sources ready, or with sources waiting for a password
- **WHEN** Antenna opens
- **THEN** the user lands on the welcome, channels or sign-in screen as before, and no profile chooser appears

### Requirement: A hint when the Apple TV has several users
The system SHALL show a hint on the welcome screen, when the Apple TV has more than one user and the current user has no sources, that each user has their own sources.

#### Scenario: Several users, no sources
- **GIVEN** an Apple TV with more than one user, and a current user with no sources
- **WHEN** the welcome screen is shown
- **THEN** the hint "Each user on this Apple TV has their own sources. Another user's are not shown here. Switch user in Control Center to use theirs." is shown below the usual text

#### Scenario: A user added while Antenna is in the background
- **GIVEN** an Apple TV with one user and Antenna in the background
- **WHEN** a second user is added in the Apple TV's settings and the welcome screen next appears
- **THEN** the hint shows without restarting Antenna

#### Scenario: Offline or not signed in to iCloud
- **GIVEN** an Apple TV with several users, offline or with the current user not signed in to iCloud
- **WHEN** the welcome screen is shown
- **THEN** the hint still shows

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the welcome screen with the hint is shown
- **THEN** VoiceOver reads the hint as one element before the iCloud note

### Requirement: No hint with one user
The system SHALL show the usual welcome screen with no hint on an Apple TV with one user.

#### Scenario: One user, no sources
- **GIVEN** an Apple TV with one user and no sources
- **WHEN** the welcome screen is shown
- **THEN** there is no hint and the screen is the usual welcome screen

### Requirement: The hint appears only on the welcome screen
The system SHALL show the several-users hint on the Apple TV welcome screen only.

#### Scenario: Later setup steps and other platforms
- **GIVEN** the Apple TV has several users
- **WHEN** the user goes on to choose a source type, enter details, read help, or is asked to sign in to a synced source, or opens the welcome screen on iPhone, iPad or Mac
- **THEN** the hint is not shown

### Requirement: Each person sees their own sources
The system SHALL show each Apple TV user only their own sources, and return a user to their own channels and last channel when they switch back.

#### Scenario: Switch and switch back
- **GIVEN** users A and B on one Apple TV, A with a source, B with none
- **WHEN** A, mid-playback or not, switches to B, and later back
- **THEN** B sees the welcome screen with the hint, and A comes back to their own channels with their last channel playing and no setup step

#### Scenario: The same Apple Account on two users
- **GIVEN** two Apple TV users signed in to the same Apple Account
- **WHEN** each uses Antenna
- **THEN** their sources, favorites, recent searches, progress and My list merge through iCloud, each still signs in once, and last channel and recently watched stay separate

#### Scenario: A guide download at a switch
- **GIVEN** a guide download running for user A
- **WHEN** A switches to B
- **THEN** the download stops and resumes the next time A opens Antenna

### Requirement: Each person signs in once on this Apple TV
The system SHALL ask each Apple TV user to sign in once to a synced provider whose password is not on the device, and keep that sign-in for that user only.

#### Scenario: A synced source without its password
- **GIVEN** B's iCloud holds a provider whose password is not on this Apple TV
- **WHEN** B opens Antenna
- **THEN** B is asked to sign in, sees channels after connecting, and is not asked again on later launches, while A's own sign-in is untouched

#### Scenario: Two users with the same login
- **GIVEN** two users with the same provider login
- **WHEN** each sets up Antenna
- **THEN** each types it once

### Requirement: Passwords are never stored for the whole Apple TV
The system SHALL store a password signed in on Apple TV for the current user only.

#### Scenario: Another user opens Antenna
- **GIVEN** user A signs in to a provider on this Apple TV
- **WHEN** user B opens Antenna on it
- **THEN** A's password is not available to B

### Requirement: What Antenna remembers is per person
The system SHALL keep each Apple TV user's last channel, recently watched channels and recent searches separate.

#### Scenario: Two users' history
- **GIVEN** A and B have each used Antenna on the same Apple TV
- **WHEN** either opens Antenna
- **THEN** they see their own last channel, recently watched channels and recent searches

### Requirement: Switching mid-setup leaves no half-added source
The system SHALL keep a source saved before a user switch, with its password, and leave nothing behind from a source that was still connecting.

#### Scenario: Switch during setup
- **GIVEN** A is adding a source
- **WHEN** A switches to B and back, either after the source was saved or while Antenna was still connecting
- **THEN** a saved source is still there with its password and A goes straight to channels
- **AND** an unfinished one left nothing behind, so A starts at the welcome screen
