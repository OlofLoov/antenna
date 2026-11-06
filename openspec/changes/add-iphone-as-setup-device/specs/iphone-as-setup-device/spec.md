# Spec Delta

## Purpose

Lets the person setting up an Apple TV fill in a source on an iPhone, iPad or Mac keyboard by scanning a QR code or accepting Handoff, so the source reaches the TV through iCloud without typing it on the remote.

## ADDED Requirements

### Requirement: The Apple TV offers a QR code
The system SHALL show a "Set up from your iPhone" card with a scannable QR code on the Apple TV's setup details step when the TV is signed in to iCloud, in place of the keyboard card.

#### Scenario: Reach the details step
- **GIVEN** an Apple TV that is signed in to iCloud and on the setup details step
- **WHEN** the step appears
- **THEN** a "Set up from your iPhone" card shows a scannable QR code for the setup link and a status reading "Waiting for your iPhone"
- **AND** VoiceOver describes the code as something to scan with an iPhone
- **AND** the keyboard card is not shown

#### Scenario: iCloud sign-in changes while the step is open
- **GIVEN** the details step open
- **WHEN** the Apple TV signs in to or out of iCloud
- **THEN** the QR card and the keyboard card swap, and a newly shown QR card has a fresh code

### Requirement: No iCloud, no QR code
The system SHALL show the keyboard card and no QR code or Handoff offer when the Apple TV is not signed in to iCloud.

#### Scenario: Not signed in
- **GIVEN** an Apple TV that is not signed in to iCloud
- **WHEN** the details step shows
- **THEN** the keyboard card shows and there is no QR code or Handoff offer

### Requirement: The code carries nothing but a random one-time code
The system SHALL put only a version number and a random code, new each time the user enters the step, into the setup link and the Handoff offer.

#### Scenario: Read the link
- **GIVEN** the QR card on screen
- **WHEN** anyone reads the link in the code or the Handoff offer
- **THEN** they find only a version number and a random code that is new each time the user enters the step, and no source, password, device name or account detail

### Requirement: A playlist source sent from the iPhone starts loading on the TV
The system SHALL move the Apple TV on to loading channels when a playlist source created after the user reached the step arrives through iCloud, adding no source of its own.

#### Scenario: A new playlist source arrives
- **GIVEN** the QR card on screen
- **WHEN** a new playlist source, created after the user reached this step (allowing for clock drift), arrives through iCloud
- **THEN** the TV goes on to loading channels for that source and adds no source of its own

#### Scenario: Old sources still downloading
- **GIVEN** first launch on the TV while iCloud is still downloading older sources
- **WHEN** those sources arrive
- **THEN** they do not count as arrived, and only sources created after the user reached the step do

#### Scenario: Two iPhones scan the same code
- **GIVEN** two iPhones scanned the same code
- **WHEN** both send a source
- **THEN** the TV uses the first to arrive and the other stays in the list

#### Scenario: A source arrives while the user types on the TV
- **GIVEN** the user typing in the TV's form
- **WHEN** a playlist source arrives from the iPhone
- **THEN** loading replaces the form and the typed text is discarded

### Requirement: An Xtream source sent from the iPhone needs only the login on the TV
The system SHALL fill in and lock Name and Server for an arrived Xtream source, say its login has not reached the TV, and save the login the user types for that source without adding a second one.

#### Scenario: Sign in to an arrived Xtream source
- **GIVEN** the QR card on screen and possibly some text in the TV's username and password fields
- **WHEN** a new Xtream source arrives through iCloud and the user signs in on the TV
- **THEN** the TV says the source arrived and the login has not reached it, fills in and locks Name and Server, keeps what the user had typed in the login fields, and on Connect saves the login for the arrived source without adding a second one

### Requirement: Nothing arrives, and the TV says why that might be
The system SHALL show a hint on the Apple TV after two minutes without a usable source, naming the usual causes.

#### Scenario: Two minutes pass
- **GIVEN** the QR card on screen
- **WHEN** two minutes pass with no usable source
- **THEN** a hint says the iPhone needs Antenna, an internet connection and the same iCloud account as the TV

#### Scenario: A source this card cannot set up
- **GIVEN** the QR card on screen
- **WHEN** a source arrives of a kind the card cannot set up
- **THEN** after two minutes the hint says to update Antenna or type the source on the TV instead

#### Scenario: Offline TV or another account
- **GIVEN** an Apple TV that is offline, or a phone on a different iCloud account
- **WHEN** the user sends a source
- **THEN** nothing arrives and the two-minute hint appears

### Requirement: Typing on the TV still works
The system SHALL let the user fill in the form on the Apple TV while the QR card shows, and ignore sources that arrive from the iPhone after that succeeds.

#### Scenario: Connect on the TV
- **GIVEN** the QR card on screen
- **WHEN** the user fills in the form on the TV and Connect succeeds
- **THEN** the TV goes on to loading as onboarding does, the QR card and Handoff offer go away, and a source arriving from the iPhone afterwards stays in the list without changing the screen

### Requirement: Scanning opens the setup form on the iPhone
The system SHALL open a "Set up Apple TV" form on iPhone, iPad or Mac when the user scans the code or accepts the Handoff offer, from any screen, and open nothing new for a code already used.

#### Scenario: Scan or accept Handoff
- **GIVEN** Antenna on an iPhone, iPad or Mac, on any screen
- **WHEN** the user scans the code or accepts the Handoff offer
- **THEN** a "Set up Apple TV" form opens with the banner "Opened from your Apple TV" and onboarding's fields
- **AND** the same code arriving again opens nothing new

#### Scenario: A damaged or newer link
- **WHEN** the user opens a damaged setup link, or one from a newer Antenna
- **THEN** the plain add-source form opens, and for a newer link it asks the user to update

#### Scenario: The paywall is up
- **GIVEN** the paywall is up
- **WHEN** a setup link arrives
- **THEN** the form opens once the purchase goes through

#### Scenario: The entitlement lapses with the form open
- **GIVEN** the "Set up Apple TV" form open after a source was saved
- **WHEN** the entitlement lapses
- **THEN** the paywall replaces the form and the saved source stays

#### Scenario: A photo of the code
- **GIVEN** a photo of the code sent to someone else
- **WHEN** they scan it
- **THEN** an empty form opens on their phone and whatever they add lands in their own iCloud

### Requirement: The iPhone shows the source on its way
The system SHALL turn the "Set up Apple TV" form into a "Sending to your Apple TV" screen when Connect succeeds, which cannot be swiped or escaped away and offers "Continue on iPhone".

#### Scenario: Connect succeeds
- **GIVEN** the "Set up Apple TV" form on iPhone, iPad or Mac
- **WHEN** Connect succeeds
- **THEN** the form becomes "Sending to your Apple TV" with "Saved on this iPhone" done and the Apple TV row in progress
- **AND** it cannot be swiped or escaped away, and "Continue on iPhone" leads to onboarding's ready screen

#### Scenario: Offline before Connect
- **GIVEN** the iPhone is offline
- **WHEN** the user taps Connect
- **THEN** Connect fails as onboarding's form does, before anything is saved

#### Scenario: Reduce Motion and VoiceOver
- **GIVEN** Reduce Motion or VoiceOver is on
- **WHEN** the sending screen shows
- **THEN** progress rows read "In progress" instead of a spinner with Reduce Motion, and each status row reads as one item with VoiceOver

### Requirement: The iPhone says what to check when sending stalls
The system SHALL show "Not sent yet" with what to check when iCloud has not confirmed the upload within 30 seconds, and at once when the device is not signed in to iCloud.

#### Scenario: Upload not confirmed
- **GIVEN** the sending screen
- **WHEN** 30 seconds pass without iCloud confirming the upload, or the device is not signed in to iCloud
- **THEN** the Apple TV row reads "Not sent yet" and tells the user to check the device is online and signed in to iCloud, at once when it is not signed in

### Requirement: An iPhone without Antenna gets a plain page
The system SHALL serve a plain web page for the setup link that says what Antenna does and links to the App Store, with no scripts, images or third-party content.

#### Scenario: Scan without Antenna installed
- **GIVEN** an iPhone without Antenna installed
- **WHEN** the camera opens the setup link
- **THEN** Safari shows a page that says "Antenna sets up your Apple TV from your iPhone." with one link to the App Store, and no scripts, images or third-party content

#### Scenario: Open the link in Safari with Antenna installed
- **GIVEN** an iPhone with Antenna installed
- **WHEN** the user opens the setup link in Safari directly
- **THEN** Safari shows the same page

### Requirement: The iPhone confirms the hand-off to iCloud
The system SHALL update the sending screen to say the source was handed to iCloud as soon as iCloud confirms the upload, even after it read "Not sent yet".

#### Scenario: iCloud confirms
- **GIVEN** the sending screen, including after it reads "Not sent yet"
- **WHEN** iCloud confirms the upload
- **THEN** the Apple TV row reads "Handed to iCloud. Open Antenna on your Apple TV." and "Continue on iPhone" becomes the main button
