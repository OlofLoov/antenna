# apple-tv-login-from-iphone Specification

## Purpose
Lets the user sign in an Apple TV by scanning a code with an iPhone, iPad or Mac that has the login, so the login reaches the TV encrypted and only that TV can read it, without typing it with the remote.

## Requirements

### Requirement: The Apple TV sign-in offers a QR code
The system SHALL show a "Send the login from your iPhone" card with a scannable QR code next to the Apple TV's sign-in fields, in onboarding and in a source's details, when the TV is signed in to iCloud, and the keyboard card otherwise.

#### Scenario: Onboarding asks for logins
- **GIVEN** an Apple TV signed in to iCloud, with sources that arrived without their logins
- **WHEN** onboarding's "Sign in on this Apple TV" step shows
- **THEN** a card next to the fields shows a QR code and the status "Waiting for your iPhone"
- **AND** the code asks for every source still to sign in, up to eight

#### Scenario: Sign in from a source's details
- **GIVEN** an Apple TV signed in to iCloud and a source whose login has not reached it
- **WHEN** the user chooses Sign in on this Apple TV in the source's details
- **THEN** the same card shows next to the fields and its code asks for that source only

#### Scenario: Not signed in to iCloud
- **GIVEN** an Apple TV that is not signed in to iCloud
- **WHEN** the sign-in shows
- **THEN** the keyboard card shows, with no QR code and no Handoff offer

#### Scenario: Typing on the TV still works
- **GIVEN** the QR card on screen
- **WHEN** the user types the login with the remote and Connect succeeds
- **THEN** the TV moves on as its sign-in does today, and a login sent from the iPhone afterwards for the same source is ignored

#### Scenario: Focus with the remote
- **GIVEN** the QR card on screen
- **WHEN** the user moves focus with the Siri Remote
- **THEN** focus moves only between the fields and buttons, never onto the code

### Requirement: The code holds no secret
The system SHALL put only a version, a random code, a public key the TV made for this code and the identifiers of the sources it asks for into the QR code and the Handoff offer.

#### Scenario: Read the code
- **GIVEN** the QR card on screen
- **WHEN** anyone reads the link in the code or the Handoff offer
- **THEN** they find a version, a random code, a public key and source identifiers, and no login, source name, address, device name or account detail

### Requirement: A code works once and for ten minutes
The system SHALL accept one delivery per code, replace the code with a new one after ten minutes or once a delivery arrives, and throw away the key that opens deliveries for the old code.

#### Scenario: Ten minutes pass
- **GIVEN** the QR card on screen for ten minutes with nothing delivered
- **WHEN** the tenth minute ends
- **THEN** the card shows a new code, and a delivery sent to the old one is never opened

#### Scenario: Two iPhones scan the same code
- **GIVEN** two iPhones scanned the same code
- **WHEN** both send
- **THEN** the first delivery is used and the second iPhone says the code was already used

#### Scenario: The user leaves the sign-in
- **GIVEN** the QR card on screen
- **WHEN** the user leaves the sign-in, or the Apple TV signs out of iCloud
- **THEN** the code stops working, and coming back shows a new one

### Requirement: Only the Apple TV that showed the code can read the login
The system SHALL send logins encrypted to the key in the code, only through the user's own private iCloud, SHALL remove the sealed logins from a delivery when the TV picks it up, keeping only an empty marker so a second send to the same code is refused, and SHALL delete every delivery ten minutes after it was sent.

#### Scenario: A delivery waiting in iCloud
- **GIVEN** an iPhone sent logins and the TV has not picked them up yet
- **WHEN** anything other than that TV reads the delivery, including the user's other devices
- **THEN** it holds no readable login

#### Scenario: Nobody picks it up
- **GIVEN** a delivery the TV never picked up
- **WHEN** ten minutes have passed and any of the user's devices opens Antenna
- **THEN** the delivery is deleted unread

#### Scenario: A code shown by someone else's TV
- **GIVEN** a QR code shown by an Apple TV on a different iCloud account
- **WHEN** the user scans it and sends
- **THEN** the delivery lands in the user's own iCloud, where that TV cannot see it, and the iPhone finds none of the sources it asks for

### Requirement: The iPhone asks before it sends
The system SHALL open a "Sign in your Apple TV" sheet on iPhone, iPad or Mac when the user scans the code or accepts the Handoff offer, list the sources the TV asked for with whether this device has each login, and send only after the user chooses Send.

#### Scenario: Scan the code
- **GIVEN** Antenna on an iPhone that has the logins of the sources the TV asked for
- **WHEN** the user scans the code
- **THEN** a sheet lists those sources by name with "Ready to send", and nothing leaves the iPhone until the user chooses Send

#### Scenario: Some logins ready, some not
- **GIVEN** the sheet lists one source with its login on this iPhone and one without
- **WHEN** the user chooses Send without entering the missing one
- **THEN** only the ready login is sent, and the TV keeps asking for the other

#### Scenario: The paywall is up
- **GIVEN** the paywall is up
- **WHEN** the user scans the code
- **THEN** the sheet opens once the purchase goes through

#### Scenario: A damaged or newer code
- **WHEN** the user opens a damaged sign-in link, or one from a newer Antenna
- **THEN** no sheet sends anything, and for a newer link the user is asked to update Antenna

### Requirement: The iPhone takes a login it does not have
The system SHALL let the user enter a listed source's missing login on the iPhone, check it with the server before accepting it, and keep it in the iPhone's Keychain as well as sending it.

#### Scenario: Enter a missing login
- **GIVEN** a listed source whose login is not on this iPhone
- **WHEN** the user chooses Enter, types a login the server accepts and confirms
- **THEN** the row reads "Ready to send" and the login is kept on this iPhone too

#### Scenario: The server turns it down
- **GIVEN** the user entering a missing login
- **WHEN** the server turns it down
- **THEN** the same message as the source's details shows under the fields and the row stays not ready

### Requirement: Sources the iPhone does not have
The system SHALL tell the user when the TV asked for sources this device does not have, and point at the iCloud account when it has none of them.

#### Scenario: One source has not reached the iPhone
- **GIVEN** the TV asked for two sources and one is not on this iPhone
- **WHEN** the sheet opens
- **THEN** it lists the one it has and a line says one source the Apple TV asked for is not on this iPhone yet

#### Scenario: None of them
- **GIVEN** none of the sources the TV asked for is on this iPhone
- **WHEN** the sheet opens
- **THEN** it says both devices need the same iCloud account, offers only Done, and sends nothing

### Requirement: The Apple TV checks a login before keeping it
The system SHALL check each delivered login with its server the way the TV's sign-in does, keep the ones that work in the TV's Keychain without adding a source, and ask on the TV for any that fail.

#### Scenario: The logins work
- **GIVEN** onboarding's sign-in step with the QR card
- **WHEN** logins for its sources arrive and the servers accept them
- **THEN** the sources load, and the TV goes on to the loading checklist without the user touching the remote

#### Scenario: One login does not work
- **GIVEN** logins for two sources arrive
- **WHEN** one server accepts and the other turns its login down
- **THEN** the first source is kept, and the sign-in shows the second with empty fields, a new code, and a message that the login from the iPhone did not work there

#### Scenario: The TV is offline
- **GIVEN** the QR card on an Apple TV that is offline
- **WHEN** the user sends from the iPhone
- **THEN** nothing arrives, and after two minutes a hint names the internet connection, Antenna on the iPhone and the same iCloud account

#### Scenario: A delivery the TV cannot read
- **GIVEN** the QR card on screen
- **WHEN** a delivery for its code arrives that this TV cannot open or understand
- **THEN** the card says so and suggests updating Antenna or typing the login on the TV

### Requirement: Every kind of source with a login
The system SHALL send and receive the login of an Xtream source, the MAC address and optional login of a Stalker portal, the username and password of a Jellyfin server, and the optional username and password of a Channels DVR server, and SHALL never ask for a playlist source.

#### Scenario: A Stalker portal
- **GIVEN** a Stalker portal whose MAC address has not reached the TV
- **WHEN** the iPhone sends it
- **THEN** the TV signs in to the portal with the MAC address and any login, and the portal loads

#### Scenario: A Jellyfin server
- **GIVEN** a Jellyfin server whose login has not reached the TV
- **WHEN** the iPhone sends it
- **THEN** the TV signs in with the username and password and gets its own access, and the iPhone's access stays on the iPhone

#### Scenario: A Channels DVR server without a password
- **GIVEN** a Channels DVR server with no username or password
- **WHEN** the TV signs in
- **THEN** it does not ask for that server, in the code or on screen

### Requirement: The iPhone says whether the TV picked it up
The system SHALL show on the sending device whether the TV picked up the delivery, and say what to check when it has not after a minute or could not be sent.

#### Scenario: Picked up
- **GIVEN** the user chose Send
- **WHEN** the TV picks up the delivery
- **THEN** the sheet says the Apple TV picked up the logins and offers Done

#### Scenario: Not picked up yet
- **GIVEN** the user chose Send
- **WHEN** a minute passes and the TV has not picked it up
- **THEN** the sheet says to keep the sign-in open on the Apple TV and to scan again if the code there changed, and still updates if the TV picks it up later

#### Scenario: Offline or not signed in to iCloud
- **GIVEN** an iPhone that is offline, or not signed in to iCloud
- **WHEN** the user chooses Send
- **THEN** nothing is sent and the sheet says which of the two to fix, with Try again when offline

### Requirement: The sign-in reads well without sight or motion
The system SHALL describe the code and every status to VoiceOver on both devices, announce a delivered login on the TV, and show progress as text when Reduce Motion is on.

#### Scenario: VoiceOver on the TV
- **GIVEN** VoiceOver on the Apple TV
- **WHEN** the QR card shows and later a login arrives
- **THEN** the code is described as something to scan with an iPhone, and the arrival is announced

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion on either device
- **WHEN** a status is in progress
- **THEN** it reads "In progress" instead of showing a spinner

### Requirement: Nothing about a login is logged or kept
The system SHALL keep the TV's key for a code in memory only, and SHALL never log or store a login, a code, a key or a delivery outside the Keychain and the ten-minute delivery.

#### Scenario: After sign-in
- **GIVEN** the TV signed in from an iPhone delivery
- **WHEN** anyone reads the app's logs, settings or synced records on any device
- **THEN** they find no login, code or key, and the only copy of the login on the TV is in its Keychain
