# Spec Delta

## MODIFIED Requirements

### Requirement: The code carries nothing but a random one-time code
The system SHALL put only a version number, a random code and a public key the TV made for that code, all new each time the user enters the step, into the setup link and the Handoff offer.

#### Scenario: Read the link
- **GIVEN** the QR card on screen
- **WHEN** anyone reads the link in the code or the Handoff offer
- **THEN** they find only a version number, a random code and a public key, all new each time the user enters the step, and no source, password, device name or account detail

### Requirement: A login source sent from the iPhone needs only its login on the TV
The system SHALL fill in and lock Name and the server or portal for an arrived Xtream source, Stalker portal or Jellyfin server, wait a minute for its login from the iPhone, and then offer to sign in on the TV, saving what the user types for that source without adding a second one.

#### Scenario: The login arrives from the iPhone
- **GIVEN** the QR card on screen
- **WHEN** a new Xtream source arrives through iCloud and its login arrives from the iPhone that set it up
- **THEN** the TV says the source arrived and it is waiting for the login, checks the login with the server once it arrives, and goes on to loading channels without the user typing anything

#### Scenario: Sign in to an arrived Xtream source
- **GIVEN** the QR card on screen and possibly some text in the TV's username and password fields
- **WHEN** a new Xtream source arrives through iCloud, its login has not arrived within a minute, and the user signs in on the TV
- **THEN** the TV says the source arrived and the login has not reached it, fills in and locks Name and Server, keeps what the user had typed in the login fields, and on Connect saves the login for the arrived source without adding a second one

#### Scenario: Sign in to an arrived Stalker portal
- **GIVEN** the QR card on screen
- **WHEN** a new Stalker portal arrives through iCloud, its MAC address has not arrived within a minute, and the user enters it on the TV
- **THEN** the TV says the portal arrived and its MAC address has not reached it, fills in and locks Name and Portal, and on Connect saves the MAC address and any login for the arrived portal without adding a second source
