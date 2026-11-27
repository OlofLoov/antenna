# play-on-apple-tv Specification

## Purpose
Lets the user pick a channel, programme, film or episode on an iPhone, iPad or Mac and have Antuna on one of their Apple TVs play it, over the home network when the TV is open on it and through their private iCloud otherwise, while the phone keeps browsing without opening a stream of its own.

## Requirements

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

### Requirement: Play on from what can be played
The system SHALL offer "Play on <TV>" on iPhone, iPad and Mac on a movie's title page, a series' title page, an episode, a channel in Live, the Guide or Search, and a programme's details in the Guide, and SHALL open a list of the TVs when there is more than one.

#### Scenario: One TV
- **GIVEN** one Apple TV, Living Room, on the account
- **WHEN** the user opens a film's title page
- **THEN** a "Play on Living Room" button sits with My list and Trailer under Play

#### Scenario: Two TVs
- **GIVEN** the Apple TVs Living Room and Bedroom on the account
- **WHEN** the user taps "Play on" on a title page
- **THEN** a menu lists Living Room and Bedroom, each with whether it can start now
- **AND** choosing one sends the title there

#### Scenario: A channel
- **GIVEN** a channel row in Live, the Guide or Search
- **WHEN** the user touches and holds it, or right-clicks it on a Mac
- **THEN** the menu offers "Play on Living Room" next to the actions it has today

#### Scenario: A programme on now in the Guide
- **GIVEN** a programme's details in the Guide for a programme on now
- **WHEN** the user taps "Watch on Living Room"
- **THEN** the TV plays the channel live

#### Scenario: A past programme with catch-up
- **GIVEN** a programme's details for a programme that has ended, on a channel with catch-up
- **WHEN** the user chooses to play it on Living Room
- **THEN** the TV plays the recording from its start, as catch-up does on the TV

#### Scenario: A programme later today
- **GIVEN** a programme's details for a programme that has not started
- **WHEN** the user looks for a way to play it on the TV
- **THEN** there is none; Remind me stays as it is

#### Scenario: A film with a saved place
- **GIVEN** a film the user stopped 40 minutes in
- **WHEN** the user sends it to Living Room
- **THEN** the TV resumes it at 40 minutes, as Resume does on the TV

#### Scenario: An episode
- **GIVEN** a series' title page with its episode list
- **WHEN** the user touches and holds an episode and chooses "Play on Living Room"
- **THEN** the TV plays that episode, from its saved place when it has one

### Requirement: Starts at once on the same network
The system SHALL deliver a request to an Apple TV that has Antuna open on the same network within one second of the user choosing it, and the TV SHALL start the item without asking, leaving whatever it was showing.

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

#### Scenario: The network drops mid-send
- **GIVEN** the user chose a TV listed as ready now
- **WHEN** the network request fails or gets no answer within three seconds
- **THEN** the request goes through iCloud instead, and the phone says "Sent. Living Room offers it when Antuna opens there"

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

### Requirement: The TV offers a waiting request
The system SHALL show on the Apple TV, when Antuna opens there, comes to the front, or a request arrives while it is open, an offer naming the sending device and the item, "From Anna's iPhone: Salt Road", with Play and Not now, and SHALL play the item on Play and delete the request on either choice.

#### Scenario: Open Antuna on the TV
- **GIVEN** a waiting request for Salt Road sent from Anna's iPhone to Living Room
- **WHEN** Antuna opens on Living Room
- **THEN** after any "Who's watching?" choice, the offer shows over the first screen with focus on Play
- **AND** Play starts Salt Road and Not now leaves the TV where it was

#### Scenario: Menu on the offer
- **GIVEN** the offer on screen
- **WHEN** the viewer presses Menu or Back on the Siri Remote
- **THEN** the offer closes as Not now does

#### Scenario: A request for another TV
- **GIVEN** a waiting request sent to Bedroom
- **WHEN** Antuna opens on Living Room
- **THEN** Living Room shows no offer

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the offer appears
- **THEN** it reads the sending device, the item and the focused button

### Requirement: Requests expire and leave no trace
The system SHALL drop a request for a live channel or a programme on now 5 minutes after it was sent, and a request for a film, an episode or catch-up 6 hours after, and SHALL delete every request from iCloud when it plays, when it is dismissed or when it expires.

#### Scenario: A live channel sent an hour ago
- **GIVEN** a request for Sport One sent to Living Room an hour ago
- **WHEN** Antuna opens on Living Room
- **THEN** there is no offer and the request is deleted

#### Scenario: A film sent in the afternoon
- **GIVEN** a request for Salt Road sent three hours ago
- **WHEN** Antuna opens on Living Room
- **THEN** the offer for Salt Road shows

#### Scenario: Nobody picks it up
- **GIVEN** an expired request that no TV picked up
- **WHEN** any of the user's devices opens Antuna
- **THEN** the request is deleted unread

### Requirement: A request holds no link and no login
The system SHALL put in a request only which source, which channel, title, episode or programme, a start position, a display name for the item, the sending device's name and the target TV, and SHALL NOT put in it, in the network message or in the TV's record, any stream link, server address, username, password or token.

#### Scenario: Read a waiting request
- **GIVEN** a request waiting in iCloud
- **WHEN** anyone reads it, including the user's other devices
- **THEN** they find identifiers, a position and names, and no link, address or login

#### Scenario: Watch the network
- **GIVEN** someone recording the traffic on the home network
- **WHEN** the iPhone sends a request to the TV
- **THEN** the message is encrypted, and the TV's network announcement carries no TV name, account or source detail

### Requirement: Only the same account can send over the network
The system SHALL accept a request over the network only from a device that proves it belongs to the same iCloud account, with no pairing step, and SHALL ignore any other.

#### Scenario: A guest's iPhone on the same Wi-Fi
- **GIVEN** a guest with Antuna on another iCloud account, on the same network as Living Room
- **WHEN** the guest's iPhone tries to send to Living Room
- **THEN** Living Room ignores it and shows nothing

#### Scenario: A new iPhone on the account
- **GIVEN** an iPhone that signed in to the account today and opened Antuna for the first time
- **WHEN** it sends to Living Room
- **THEN** Living Room plays the request without any pairing or code

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
- **THEN** the TV keeps the request until a profile is chosen, then plays or offers it there

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
- **THEN** the TV keeps it until the paywall goes, then offers it

### Requirement: Connected to a TV
The system SHALL connect the sending device to the TV after a request goes over the network, show a "Playing on <TV>" bar above the tab bar on iPhone and at the bottom of the window on iPad and Mac, or the same line in Live's picture area, with what the TV plays and a play and pause button, and open a sheet from the bar with the item, play and pause, "Play on this iPhone" and "Disconnect".

#### Scenario: The bar after a send
- **GIVEN** the user sent Sport One to Living Room over the network
- **WHEN** the TV starts playing
- **THEN** the iPhone shows "Playing on Living Room" with the channel, the programme and a pause button above the tab bar on every tab but Live, where the picture area shows the same

#### Scenario: Pause from the phone
- **GIVEN** the bar shows a film playing on Living Room
- **WHEN** the user taps pause
- **THEN** the film pauses on the TV and the button turns to play within a second

#### Scenario: The TV changes on its own
- **GIVEN** the phone connected to Living Room
- **WHEN** someone changes the channel or pauses with the Siri Remote
- **THEN** the bar shows the new channel or the paused state within a second

#### Scenario: Through iCloud only
- **GIVEN** a request that went through iCloud
- **WHEN** it was sent
- **THEN** the phone is not connected and shows no bar

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** it reaches the bar
- **THEN** it reads "Playing on Living Room", the item, and the play or pause action

### Requirement: Play goes to the TV while connected
The system SHALL send to the connected TV, instead of playing on the phone, every play the user starts while connected: a channel row, Watch in the Guide, Play or Resume on a title page, an episode, a reminder's Watch and a search result.

#### Scenario: Pick a channel in Live
- **GIVEN** the iPhone connected to Living Room
- **WHEN** the user taps another channel in Live
- **THEN** Living Room tunes that channel and the row is marked as playing on Living Room

#### Scenario: Play a film
- **GIVEN** the iPhone connected to Living Room
- **WHEN** the user taps Play on a film's page
- **THEN** the button reads "Play on Living Room" and the film starts on the TV

#### Scenario: The request is refused
- **GIVEN** the iPhone connected to Living Room
- **WHEN** a channel the user taps is locked on the TV
- **THEN** the passcode prompt shows on the TV, the iPhone says so, and the iPhone still plays nothing

### Requirement: The phone opens no stream while connected
The system SHALL open no stream from any of the user's sources on the connected phone, iPad or Mac while it is connected, because many providers allow one connection at a time: the Live picture, the Guide's playing bar and multi-view tiles SHALL show the channel's logo or the title's art with "Playing on <TV>" in place of video.

#### Scenario: The Live picture
- **GIVEN** the iPhone connected to Living Room playing Sport One
- **WHEN** the user opens Live
- **THEN** the picture area shows Sport One's logo on a dark ground with "Playing on Living Room", and no video or sound plays on the iPhone

#### Scenario: The Guide
- **GIVEN** the iPhone connected to Living Room
- **WHEN** the user opens the Guide
- **THEN** the "Playing on Living Room" bar takes the place of the now-playing bar and no stream opens

#### Scenario: Multi-view
- **GIVEN** an iPad or Mac connected to Living Room
- **WHEN** the user touches and holds a channel
- **THEN** "Add to Multi-view" is not offered

#### Scenario: Connect while a channel plays on the phone
- **GIVEN** the iPad playing a channel, or showing multi-view
- **WHEN** the user sends a channel to Living Room
- **THEN** the iPad stops every stream it had open before the TV starts

#### Scenario: Picture in Picture
- **GIVEN** a channel in Picture in Picture on the iPhone
- **WHEN** the user sends a channel to Living Room
- **THEN** Picture in Picture closes

#### Scenario: Trailers
- **GIVEN** the iPhone connected to Living Room
- **WHEN** the user taps Trailer on a title page
- **THEN** the link opens outside Antuna, as it does today, since Antuna opens no stream for it

### Requirement: Play on this iPhone
The system SHALL let the user move what the TV plays to the phone from the connected sheet: the TV stops, the phone disconnects, and the phone plays the same channel live or the same film or episode from the TV's position.

#### Scenario: Move a film to the iPhone
- **GIVEN** Living Room playing Salt Road at 1 h 12 min, connected to the iPhone
- **WHEN** the user chooses "Play on this iPhone"
- **THEN** Living Room stops and goes back to the title page, and the iPhone plays Salt Road from 1 h 12 min

#### Scenario: Move a channel to the iPhone
- **GIVEN** Living Room playing Sport One
- **WHEN** the user chooses "Play on this iPhone"
- **THEN** Living Room stops before the iPhone tunes Sport One live

### Requirement: The connection ends cleanly
The system SHALL end the connected state when the user chooses Disconnect, when the TV stops playing, when the TV leaves the network or closes Antuna, and when the phone goes to the background, and SHALL then let the phone play on its own again. Disconnect SHALL leave the TV playing.

#### Scenario: Disconnect
- **GIVEN** the iPhone connected to Living Room
- **WHEN** the user chooses Disconnect
- **THEN** the bar goes, Living Room keeps playing, and the next tap on a channel plays it on the iPhone

#### Scenario: The TV stops
- **GIVEN** the iPhone connected to Living Room
- **WHEN** someone stops playback on the TV with the remote
- **THEN** the bar says "Stopped on Living Room" for three seconds and goes

#### Scenario: Back from the background
- **GIVEN** the iPhone was connected to Living Room and went to the background
- **WHEN** the user opens Antuna again and Living Room still plays what the iPhone sent
- **THEN** the iPhone connects again by itself and the bar comes back, with no stream opened on the iPhone in between

#### Scenario: Left the house
- **GIVEN** the iPhone connected to Living Room
- **WHEN** the iPhone leaves the home network
- **THEN** the bar goes within ten seconds and the iPhone plays nothing until the user taps play

### Requirement: The local network is asked for only when needed
The system SHALL ask for local network access on iPhone, iPad and Mac only when the user first opens Play on with at least one Apple TV on the account, and SHALL still send through iCloud when access is refused.

#### Scenario: No Apple TV
- **GIVEN** an account with no Apple TV running Antuna
- **WHEN** the user uses Antuna on the iPhone
- **THEN** the iPhone never asks for local network access on account of this feature

#### Scenario: Access refused
- **GIVEN** the user refused local network access
- **WHEN** they send to Living Room
- **THEN** the request goes through iCloud, every TV is listed as playing when Antuna opens there, and the list has a line pointing at Settings to allow access
