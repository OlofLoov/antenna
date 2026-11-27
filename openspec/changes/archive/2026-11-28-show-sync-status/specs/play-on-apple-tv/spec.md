## MODIFIED Requirements

### Requirement: Apple TVs on the same iCloud account
The system SHALL list as places to play only Apple TVs that run Antuna on the same iCloud account as the sending device, each by the name the TV gives itself, and SHALL say for each whether it can start now or will offer the request when Antuna opens there.

#### Scenario: One Apple TV open at home
- **GIVEN** an iPhone and an Apple TV named Living Room on the same iCloud account and the same network, with Antuna open on the TV
- **WHEN** the user opens the list of places to play on the iPhone
- **THEN** Living Room is listed as ready now

#### Scenario: The TV app is closed
- **GIVEN** the Apple TV Living Room has run Antuna before on this iCloud account, and Antuna is not open on it now
- **WHEN** the user opens the list of places to play
- **THEN** Living Room is listed with "Plays when Antuna opens there"

#### Scenario: A TV on someone else's account
- **GIVEN** a guest's Apple TV running Antuna on the same network, signed in to a different iCloud account
- **WHEN** the user opens the list of places to play
- **THEN** the guest's TV is not listed

#### Scenario: Two TVs with the same name
- **GIVEN** two Apple TVs on the account that both call themselves Apple TV
- **WHEN** the user opens the list of places to play
- **THEN** both are listed, told apart by a number after the name

#### Scenario: A TV not seen for two months
- **GIVEN** an Apple TV that has not opened Antuna for 60 days
- **WHEN** the user opens the list of places to play
- **THEN** that TV is not listed

#### Scenario: No Apple TV on the account
- **GIVEN** no Apple TV on the iCloud account has ever opened Antuna, or the device is not signed in to iCloud
- **WHEN** the user looks at a title page, a channel, a programme's details or an episode
- **THEN** there is no Play on button or menu item anywhere

#### Scenario: A TV opens Antuna for the first time while the phone is open
- **GIVEN** Antuna open on an iPhone, with no Apple TV on the account yet
- **WHEN** an Apple TV on the account opens Antuna for the first time
- **THEN** within about 30 seconds, without leaving the app, the iPhone shows Play on with that TV
- **AND** opening a title page or a programme's details reads the list again, so the TV can show up sooner

### Requirement: Waits in iCloud when the TV is not reachable
The system SHALL keep a request for a TV that is not reachable on the network in the user's private iCloud database, SHALL tell the user it was sent, and SHALL keep only the newest request for each TV.

#### Scenario: The TV app is closed
- **GIVEN** Antuna is not open on Living Room
- **WHEN** the user sends a film to Living Room
- **THEN** the iPhone says "Sent. Living Room offers it when Antuna opens there"

#### Scenario: Away from home
- **GIVEN** the iPhone is on mobile data and Antuna is open on Living Room at home
- **WHEN** the user sends a channel to Living Room
- **THEN** Living Room offers the request within a minute

#### Scenario: A second request replaces the first
- **GIVEN** a waiting request for Living Room
- **WHEN** the user sends another item to Living Room before the TV picks the first one up
- **THEN** only the second one is offered

#### Scenario: The phone is offline
- **GIVEN** the iPhone has no network
- **WHEN** the user tries to send
- **THEN** the iPhone says it is offline and nothing is sent

#### Scenario: The phone is not signed in to iCloud
- **GIVEN** the iPhone is not signed in to iCloud
- **WHEN** the user looks for Play on
- **THEN** it is not offered, as with no Apple TV on the account


#### Scenario: iCloud Drive is off
- **GIVEN** an iPhone signed in to iCloud with iCloud Drive turned off, and an Apple TV signed in to the same account
- **WHEN** Antuna opens on both
- **THEN** the TV is listed on the iPhone and Play on is offered, as with iCloud Drive on
