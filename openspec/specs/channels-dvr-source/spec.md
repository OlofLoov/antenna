# channels-dvr-source Specification

## Purpose
Lets a Channels DVR user add their home TV server by typing one address and see its channels with the names and numbers they set there, plus seven days of guide, with favorites that survive an address change.

## Requirements

### Requirement: Type the address the way Channels DVR shows it
The system SHALL turn a typed Channels DVR address into one tidy server address, adding `http://` and port 8089 only when the user gave neither, and SHALL turn down an address that carries a username or password, another scheme, or no host.

#### Scenario: Tidy the address
- **GIVEN** a user who types a server address as an IP, a `.local` name or a remote host name, with or without `http://`, a port, a path or a trailing slash
- **WHEN** the form checks it
- **THEN** Antenna turns it into one tidy server address, adding `http://` and port 8089 only when the user gave neither

#### Scenario: Turn down a bad address
- **WHEN** the typed address has a username or password in it, another scheme such as `ftp`, or no host
- **THEN** it is turned down, so a password never ends up in the synced source

### Requirement: Connect says what it found
The system SHALL accept any working Channels DVR server whatever its version, and report a starting server, a non-Channels DVR server, a password demand, a server error, an unreachable host and an offline device as distinct errors.

#### Scenario: Each outcome of the status check
- **GIVEN** an address that points at a working Channels DVR server, a server that is still starting, something that is not Channels DVR, a server that asks for a password, a server with an error, an unreachable host, or a device with no network
- **WHEN** the user taps Connect
- **THEN** a working server is accepted whatever its version, and the app gets its version text for the checklist
- **AND** each of the other cases gets its own error (starting, not a Channels DVR server, needs a password, server error, unreachable, offline), and "unreachable" and "offline" are never confused

#### Scenario: A sleeping or restarting server
- **GIVEN** a NAS that is asleep, or a server that is restarting
- **WHEN** the source loads
- **THEN** it fails this load as unreachable or starting, and the next load tries again

#### Scenario: Remote access without its own key
- **GIVEN** a Channels DVR remote-access address used without its own sign-in key
- **WHEN** the user taps Connect
- **THEN** the server's password demand or login page fails as such

### Requirement: Reach a remote server behind a password
The system SHALL send a source's proxy username and password with every request to its server, and send none for a source without them.

#### Scenario: With and without a proxy password
- **GIVEN** a source with a proxy username and password, and a source without one
- **WHEN** either source talks to its server
- **THEN** the first sends the username and password with every request, a colon in the password included, and the second sends none

#### Scenario: A username the standard format cannot carry
- **WHEN** the proxy username is empty or contains a colon
- **THEN** it is turned down

### Requirement: Channels keep the names and numbers you set
The system SHALL show each Channels DVR channel with its display name (or call sign when that is empty), its number as set in Channels DVR including any part after the dot, its group, logo and stream, and no catch-up.

#### Scenario: Map the lineup
- **GIVEN** a lineup where channels have a display name, a call sign, a channel number and a group, some numbered like 6.1
- **WHEN** the source loads
- **THEN** each channel shows the display name (the call sign only when the display name is empty), its number as set in Channels DVR including the part after the dot, its group, its logo and its stream, with no catch-up

### Requirement: Favorites survive an address change
The system SHALL give each Channels DVR channel an identity taken from the server's lineup, never from the server's address.

#### Scenario: Home and remote address
- **GIVEN** the same lineup fetched once from the server's home address and once from its remote address
- **WHEN** the channels are compared
- **THEN** every channel has the same identity both times

#### Scenario: The server's channel id option flips
- **GIVEN** favorites on a Channels DVR source
- **WHEN** the user turns Channels DVR's "use channel ids in M3U" option on or off
- **THEN** every channel's identity changes and its favorites are dropped

### Requirement: An empty or wrong lineup is handled
The system SHALL list every channel in a full lineup, treat an empty lineup as no channels without an error, and fail a web page, an empty answer or a server error with an error that says which.

#### Scenario: Each kind of lineup answer
- **GIVEN** a lineup download that returns a full lineup, an empty lineup, a web page, nothing at all, or a server error
- **WHEN** the source loads
- **THEN** a full lineup gives all its channels, an empty one gives no channels and no error, and a web page, an empty answer or a server error fails with an error that says which

#### Scenario: An older Antenna
- **GIVEN** an older Antenna that receives a Channels DVR source through iCloud
- **WHEN** it loads the source as a playlist
- **THEN** it gets a web page and lists no channels without crashing

### Requirement: A source waits for its password to sync
The system SHALL show a remote source whose password has not reached this device as waiting for its credential, an unreadable password as failed, and load a source with no password without touching the Keychain.

#### Scenario: Three kinds of credential state
- **GIVEN** a remote source whose password has not reached this device yet, a source whose password cannot be read, and a home source with no password
- **WHEN** the source loads
- **THEN** the first sends nothing and shows as waiting for its credential, the second sends nothing and shows as failed, and the third loads without touching the Keychain

### Requirement: One unreachable server does not hold up the rest
The system SHALL list the channels of every reachable source while an unreachable Channels DVR server shows as failed without asking for its lineup or guide.

#### Scenario: Mixed sources
- **GIVEN** a playlist source, a Channels DVR server that cannot be reached, and a Channels DVR server that answers
- **WHEN** the app loads every source
- **THEN** the first and third sources' channels are listed and the unreachable one shows as failed without asking for its lineup or guide

### Requirement: Passwords never show up in messages or logs
The system SHALL keep the proxy username, password, their encoded form and the port out of every printed or logged source, sign-in detail and error, and print a source as its host name only.

#### Scenario: Print and log everything
- **GIVEN** a remote source with a username and password on a server with a port
- **WHEN** the source, its sign-in details or any error is printed or logged
- **THEN** none shows the username, password, their encoded form or the port, and the source prints as the server's host name only

### Requirement: The guide lines up without manual matching
The system SHALL fetch the guide from the Channels DVR server itself and match every guide channel to exactly one Antenna channel, with no guide link for the user to add.

#### Scenario: Lineup and guide from one server
- **GIVEN** a lineup and the guide file (XMLTV, the common guide format) exported by the same server
- **WHEN** both are loaded
- **THEN** every guide channel matches exactly one Antenna channel and every programme lands on a channel, so the user never matches channels to the guide by hand
- **AND** the guide is fetched from the server with no guide link for the user to add

#### Scenario: A guide link set by hand
- **GIVEN** a Channels DVR source with a guide link the user set by hand
- **WHEN** the guide loads
- **THEN** the hand-set link wins over the server's own guide

#### Scenario: A guide too large
- **GIVEN** a server guide over the guide's size limits
- **WHEN** it loads
- **THEN** the guide fails on its own and the channels still load
