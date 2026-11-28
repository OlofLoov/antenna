## RENAMED Requirements

- FROM: `### Requirement: The TV offers a waiting request`
- TO: `### Requirement: The TV counts down a waiting request`

## MODIFIED Requirements

### Requirement: Apple TVs on the same iCloud account
The system SHALL list as places to play only Apple TVs that run Antuna on the same iCloud account as the sending device, each by the name the TV gives itself, and SHALL say for each whether it can start now or will play the request if Antuna opens there within a minute.

#### Scenario: One Apple TV open at home
- **GIVEN** an iPhone and an Apple TV named Living Room on the same iCloud account and the same network, with Antuna open on the TV
- **WHEN** the user opens the list of places to play on the iPhone
- **THEN** Living Room is listed as ready now

#### Scenario: The TV app is closed
- **GIVEN** the Apple TV Living Room has run Antuna before on this iCloud account, and Antuna is not open on it now
- **WHEN** the user opens the list of places to play
- **THEN** Living Room is listed with "Plays if opened within a minute"

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

### Requirement: The local network is asked for only when needed
The system SHALL ask for local network access on iPhone, iPad and Mac only when the user first opens Play on with at least one Apple TV on the account, and SHALL still send through iCloud when access is refused.

#### Scenario: No Apple TV
- **GIVEN** an account with no Apple TV running Antuna
- **WHEN** the user uses Antuna on the iPhone
- **THEN** the iPhone never asks for local network access on account of this feature

#### Scenario: Access refused
- **GIVEN** the user refused local network access
- **WHEN** they send to Living Room
- **THEN** the request goes through iCloud, every TV is listed with "Plays if opened within a minute", and the list has a line pointing at Settings to allow access

### Requirement: Starts at once on the same network
The system SHALL deliver a request to an Apple TV that has Antuna open on the same network within one second of the user choosing it, and the TV SHALL start the item without asking, leaving whatever it was showing. A refused handshake or a dropped connection SHALL be tried again before the request goes through iCloud.

#### Scenario: Send a channel to an open TV
- **GIVEN** Antuna open on Living Room on the same network, showing the Movies tab
- **WHEN** the user chooses "Play on Living Room" for the channel Sport One on the iPhone
- **THEN** within a second Living Room starts tuning Sport One full screen
- **AND** a banner on the TV says "From Anna's iPhone" for four seconds, without taking focus

#### Scenario: The TV is in multi-view
- **GIVEN** Living Room showing multi-view
- **WHEN** a request arrives over the network
- **THEN** multi-view ends and the requested item plays full screen

#### Scenario: The phone was playing the same thing
- **GIVEN** the iPhone playing Sport One
- **WHEN** the user sends Sport One to Living Room
- **THEN** the iPhone stops its stream before the TV starts its own

#### Scenario: The iPhone app was restarted
- **GIVEN** Antuna open on Living Room, and Antuna on the iPhone opened again after iOS closed it in the background
- **WHEN** the user sends a channel to Living Room within a few seconds of opening Antuna
- **THEN** Living Room plays it over the network, and nothing goes through iCloud

#### Scenario: The TV comes back from sleep
- **GIVEN** Living Room woke up with Antuna open, and the phone found it on the network
- **WHEN** the user sends a channel right away
- **THEN** Living Room plays it over the network

#### Scenario: The source is still loading on the TV
- **GIVEN** Living Room opened Antuna a moment ago and is still loading the source
- **WHEN** the user sends a channel from that source
- **THEN** Living Room plays it once the source has loaded, and the iPhone says "Playing on Living Room" and shows the bar

#### Scenario: The network drops mid-send
- **GIVEN** the user chose a TV listed as ready now
- **WHEN** the connection fails again after being tried again, or the TV does not answer
- **THEN** the request goes through iCloud instead, and the phone says "Sent. Living Room plays it if Antuna opens there within a minute"

### Requirement: Waits in iCloud when the TV is not reachable
The system SHALL keep a request for a TV that is not reachable on the network in the user's private iCloud database, SHALL tell the user it was sent, and SHALL keep only the newest request for each TV.

#### Scenario: The TV app is closed
- **GIVEN** Antuna is not open on Living Room
- **WHEN** the user sends a film to Living Room
- **THEN** the iPhone says "Sent. Living Room plays it if Antuna opens there within a minute"

#### Scenario: Away from home
- **GIVEN** the iPhone is on mobile data and Antuna is open on Living Room at home
- **WHEN** the user sends a channel to Living Room
- **THEN** Living Room starts counting down the request within a minute

#### Scenario: A second request replaces the first
- **GIVEN** a waiting request for Living Room
- **WHEN** the user sends another item to Living Room before the TV picks the first one up
- **THEN** only the second one is counted down

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

### Requirement: The TV counts down a waiting request
The system SHALL show on the Apple TV, for a request it did not start at once (one that waited in iCloud, or one it kept behind the paywall or "Who's watching?"), a banner naming the sending device and the item with a countdown from five, "From Anna's iPhone", "Salt Road", "Starts in 5", with Cancel and Play now. It SHALL play the item when the countdown ends without any press on the remote, play it at once on Play now, and drop it on Cancel or Menu.

#### Scenario: Open Antuna on the TV
- **GIVEN** a waiting request for Salt Road sent from Anna's iPhone to Living Room
- **WHEN** Antuna opens on Living Room
- **THEN** after any "Who's watching?" choice, the banner shows at the top trailing corner of the first screen with focus on Cancel, counting down from 5
- **AND** five seconds later Salt Road starts, with nobody touching the remote

#### Scenario: One click cancels
- **GIVEN** the countdown on screen
- **WHEN** the viewer presses select on the Siri Remote
- **THEN** the banner goes, nothing plays, and focus goes back where it was

#### Scenario: Menu on the offer
- **GIVEN** the countdown on screen
- **WHEN** the viewer presses Menu or Back on the Siri Remote
- **THEN** the countdown stops as Cancel does

#### Scenario: Play now
- **GIVEN** the countdown on screen
- **WHEN** the viewer moves to Play now and presses select
- **THEN** Salt Road starts at once

#### Scenario: The request expires during the countdown
- **GIVEN** a request for Salt Road sent 58 seconds ago, counting down on Living Room
- **WHEN** it passes its one-minute expiry before the countdown ends
- **THEN** Salt Road still plays when the countdown ends

#### Scenario: A request for another TV
- **GIVEN** a waiting request sent to Bedroom
- **WHEN** Antuna opens on Living Room
- **THEN** Living Room shows no countdown

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the banner appears
- **THEN** it reads the sending device, the item and the focused Cancel button

### Requirement: Requests expire and leave no trace
The system SHALL drop every request one minute after it was sent, whether it names a live channel, a programme, a film or an episode, and SHALL delete every request from iCloud when it plays, when it is canceled or when it expires.

#### Scenario: A live channel sent an hour ago
- **GIVEN** a request for Sport One sent to Living Room an hour ago
- **WHEN** Antuna opens on Living Room
- **THEN** there is no countdown and the request is deleted

#### Scenario: A film sent in the afternoon
- **GIVEN** a request for Salt Road sent three hours ago
- **WHEN** Antuna opens on Living Room
- **THEN** there is no countdown and the request is deleted

#### Scenario: Opened within the minute
- **GIVEN** a request for Salt Road sent 30 seconds ago
- **WHEN** Antuna opens on Living Room
- **THEN** the countdown for Salt Road shows

#### Scenario: Nobody picks it up
- **GIVEN** an expired request that no TV picked up
- **WHEN** any of the user's devices opens Antuna
- **THEN** the request is deleted unread

### Requirement: The TV keeps its own locks and profile
The system SHALL play a request on the Apple TV in the profile active there, under that profile's locks and adult-content setting, asking for the passcode on the TV as it does for any other way of starting playback, and SHALL save progress to that profile.

#### Scenario: A locked channel
- **GIVEN** a channel in a locked group and locks closed on Living Room
- **WHEN** the iPhone sends that channel
- **THEN** Living Room shows its passcode prompt, and the iPhone says "Enter the passcode on Living Room"

#### Scenario: Adult content the TV's profile hides
- **GIVEN** the Kids profile active on Living Room, which hides adult content
- **WHEN** the iPhone sends an adult channel
- **THEN** Living Room asks for the passcode, as a link to hidden content does

#### Scenario: Who's watching on the TV
- **GIVEN** Living Room with two profiles, showing "Who's watching?"
- **WHEN** a request arrives
- **THEN** the TV keeps the request until a profile is chosen, then counts it down there

#### Scenario: A locked channel after the countdown
- **GIVEN** a waiting request for a channel in a locked group on Living Room
- **WHEN** its countdown ends
- **THEN** Living Room shows its passcode prompt before anything plays

#### Scenario: Different profiles on phone and TV
- **GIVEN** Mum's profile on the iPhone and Dad's on Living Room
- **WHEN** Mum sends a film
- **THEN** it plays in Dad's profile and its progress is saved to Dad's

### Requirement: The phone says why the TV cannot play
The system SHALL tell the sending device, in words, when the TV cannot play a request sent over the network, and SHALL show the same reason on the TV.

#### Scenario: The TV has no login for the source
- **GIVEN** a source whose login has not reached Living Room
- **WHEN** the iPhone sends one of its channels
- **THEN** the iPhone says "Living Room isn't signed in to <source>" with a way to sign it in from the iPhone
- **AND** Living Room shows the sign-in it shows for that source today

#### Scenario: The source has not reached the TV
- **GIVEN** a source added on the iPhone that has not synced to Living Room yet
- **WHEN** the iPhone sends one of its titles
- **THEN** the iPhone says "Living Room doesn't have <source> yet. Try again in a minute"

#### Scenario: The item is gone
- **GIVEN** a film the provider removed since the iPhone loaded its list
- **WHEN** the iPhone sends it
- **THEN** the iPhone says "Living Room couldn't find Salt Road"

#### Scenario: The paywall on the TV
- **GIVEN** Living Room showing the paywall
- **WHEN** a request arrives
- **THEN** the TV keeps it until the paywall goes, then counts it down

## ADDED Requirements

### Requirement: The phone can take a request back
The system SHALL offer Cancel on the sending device's "Sent" line for ten seconds after a request went through iCloud or was kept by the TV, SHALL then delete the request from iCloud if it still waits there, or else tell the TV over the network to drop it, and SHALL say which happened.

#### Scenario: Cancel before the TV picks it up
- **GIVEN** the iPhone sent Salt Road to Living Room through iCloud and shows "Sent. Living Room plays it if Antuna opens there within a minute"
- **WHEN** the user taps Cancel
- **THEN** the request is deleted from iCloud, the iPhone says "Canceled", and Living Room shows nothing when Antuna opens there

#### Scenario: Cancel during the countdown
- **GIVEN** Living Room took the request from iCloud and counts it down, and the iPhone can reach it on the network
- **WHEN** the user taps Cancel on the iPhone
- **THEN** the countdown on Living Room goes, nothing plays, and the iPhone says "Canceled"

#### Scenario: Cancel while the TV keeps it behind a gate
- **GIVEN** Living Room showing "Who's watching?" kept the request, and the iPhone says "Sent. Living Room plays it once Antuna is ready there"
- **WHEN** the user taps Cancel
- **THEN** Living Room drops the request, so nothing counts down after a profile is chosen, and the iPhone says "Canceled"

#### Scenario: Too late
- **GIVEN** Living Room took the request and is not reachable on the network, or already plays it
- **WHEN** the user taps Cancel
- **THEN** the iPhone says "Living Room already has it" and the countdown on the TV goes on

#### Scenario: Started at once
- **GIVEN** a request Living Room started over the network
- **WHEN** the iPhone shows "Playing on Living Room"
- **THEN** there is no Cancel; the connected bar's pause and Disconnect are the controls
