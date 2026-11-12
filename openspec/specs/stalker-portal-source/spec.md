# stalker-portal-source Specification

## Purpose
Lets a user whose provider only offers a Stalker portal (also sold as Ministra) sign in with the portal address and the MAC address the provider registered, and get the same live channels, playback and guide that an Xtream user gets.

## Requirements

### Requirement: Type the MAC and portal address the way your provider wrote them
The system SHALL accept a MAC address written with colons, dashes, or as twelve plain hex digits, in either case and with stray spaces, as one MAC, and SHALL reject malformed MACs and portal addresses without `http` or `https`.

#### Scenario: MAC forms
- **GIVEN** a user typing a MAC address with colons, with dashes, as twelve plain hex digits, in either case or with stray spaces around it
- **WHEN** the form checks it
- **THEN** every one of those forms is accepted as the same MAC, written back as `00:1A:79:12:34:56`

#### Scenario: Malformed input
- **GIVEN** a MAC with too few, too many or non-hex digits, or a portal address without `http` or `https` in front
- **WHEN** the form checks it
- **THEN** it is turned down so the form can say so

### Requirement: Connect with the portal address you were given
The system SHALL find the portal from any address form a provider hands out, sign in with the login when there is one, and save the source under a tidied address showing the portal's host name.

#### Scenario: Address forms
- **GIVEN** a portal address with or without a trailing `/c/`, under `/stalker_portal` or not, with a port, and, if the portal asks for one, a login and password
- **WHEN** the user taps Connect
- **THEN** Antenna finds the portal, signs in with the login when there is one, and saves the source under a tidied address, so the sources list shows the portal's host name

#### Scenario: Plain http
- **GIVEN** a portal and stream hosts on plain `http`
- **WHEN** the user connects and tunes
- **THEN** both work

### Requirement: Connect says why it failed
The system SHALL report a distinct error for no connection, a server error, an unauthorized device or login, a device refused with the portal's own message, and no portal found, and SHALL never report a server outage as a wrong address.

#### Scenario: Each failure
- **GIVEN** a portal that is offline, has a server error, refuses the device or its login, refuses the device with a message of its own, or is not a portal at all
- **WHEN** the user taps Connect
- **THEN** the app gets a different error for each case (no connection, server error, not authorized, device refused with the portal's message, no portal found)
- **AND** a server outage is never reported as a wrong address

#### Scenario: A login left empty
- **GIVEN** a portal that needs a login the user left empty
- **WHEN** the user taps Connect
- **THEN** the portal refuses the device or sends an empty list, and the app reports that as not authorized or an empty source

### Requirement: Portals that remember your device still let you in
The system SHALL send, for a given MAC, the same serial number, device id and signature that other players such as StbEmu and TiviMate send, so a portal that tied the MAC to those ids accepts Antenna.

#### Scenario: A MAC already tied to another player
- **GIVEN** a MAC address that a portal has already tied to the device id of another player such as StbEmu or TiviMate
- **WHEN** Antenna signs in with that MAC
- **THEN** it sends the same serial number, device id and signature those players send for that MAC, so the portal accepts it

### Requirement: Channels, guide and playback share one sign-in
The system SHALL sign in to a portal once per session and share that session between loading channels, the guide and playback, even when they ask at the same moment.

#### Scenario: Two requests at once
- **GIVEN** a portal source that has not signed in yet in this session
- **WHEN** the channel loader, the guide or playback asks for something, even two of them at the same moment
- **THEN** Antenna signs in once, answers both, and reuses the same session for later requests

### Requirement: An expired session renews itself once
The system SHALL sign in again once and repeat the request when the portal turns down Antenna's session key, and SHALL fail as not authorized if the repeat is turned down too.

#### Scenario: The session key expired
- **GIVEN** a portal that has expired or replaced Antenna's session key, for example because another device signed in with the same MAC
- **WHEN** the portal turns down a request
- **THEN** Antenna signs in again once, repeats the request and returns the answer, even when several requests were turned down at the same time

#### Scenario: The repeat is turned down
- **GIVEN** a renewed session that the portal also turns down
- **WHEN** the repeated request fails
- **THEN** the request fails as not authorized with no third try

### Requirement: Channels show up grouped by genre
The system SHALL load each portal channel with its name, number, genre as group, logo, catch-up days and a stable identity, leaving out the portal's "All" genre and listing unknown genres as ungrouped.

#### Scenario: Load a portal
- **GIVEN** a portal with genres and channels
- **WHEN** the source loads
- **THEN** each channel appears with its name, the portal's channel number, its genre as the group, its logo, whether it has catch-up and for how many days, and an identity that stays the same across reloads, so favorites stick
- **AND** the portal's catch-all "All" genre is not shown as a group, and channels with an unknown genre are listed as ungrouped

#### Scenario: A very large portal
- **GIVEN** a portal with tens of thousands of channels in one answer
- **WHEN** the source loads over a slow link
- **THEN** the request has five minutes before it gives up

#### Scenario: Offline
- **GIVEN** channels already loaded in this session
- **WHEN** the device goes offline and a request fails
- **THEN** it fails as no connection and the loaded channels stay in the catalogue

### Requirement: Tuning gets a fresh stream address
The system SHALL ask the portal for a channel's stream address each time the user tunes to it, and SHALL fail with an error and no address when the channel is not from a portal or the answer has no usable address.

#### Scenario: Tune a portal channel
- **GIVEN** a channel from a Stalker source
- **WHEN** the user tunes to it
- **THEN** Antenna asks the portal for that channel's stream address and hands back the playable address from the answer

#### Scenario: No usable address
- **GIVEN** a channel that is not from a portal, or a portal answer with no usable address
- **WHEN** the user tunes to it
- **THEN** it fails with an error and no address

### Requirement: Secrets never show up in messages or logs
The system SHALL keep the MAC in any form, the login, password, session key, derived device ids, resolved stream addresses and the portal's port and path out of every printed value, error and log line.

#### Scenario: Printing and logging
- **GIVEN** a source with a MAC, login, password, a session key, the device ids worked out from the MAC, a stream address handed back for tuning, and a portal message that contains the MAC
- **WHEN** any of these values, or any error, is printed or logged
- **THEN** none shows the MAC in any form, the login, the password, the session key, the device ids, a stream address, or the portal's port and path
- **AND** the portal's message reads with the MAC replaced by "…", and the source prints as the portal's host name only

### Requirement: The portal's guide fills the programme grid
The system SHALL load the portal's own guide for a Stalker source with no separate guide address, matching programmes by XMLTV id or else by the portal's channel id.

#### Scenario: Portal guide
- **GIVEN** a Stalker source with no separate guide address, and channels with and without an XMLTV id (the id guide files use)
- **WHEN** the guide loads the portal's guide for up to seven days
- **THEN** programmes appear on the right channels, and a channel without an XMLTV id still gets its programmes through the portal's own channel id
- **AND** rows for unknown channels or with impossible times are counted rather than shown

#### Scenario: A guide address the user added
- **GIVEN** a Stalker source with a guide address the user added
- **WHEN** the guide loads
- **THEN** it still matches by XMLTV id

### Requirement: A broken answer is an error, not a crash
The system SHALL turn a portal answer it cannot read into a reading error that quotes nothing from the answer, and SHALL skip and count broken channel or genre rows while loading the rest.

#### Scenario: Unreadable answers
- **GIVEN** a portal answer that is an HTML login page, XML, or empty
- **WHEN** Antenna reads it
- **THEN** it becomes a reading error that quotes nothing from the answer

#### Scenario: Some broken rows
- **GIVEN** a channel list with some broken rows
- **WHEN** Antenna reads it
- **THEN** the broken channel or genre rows are skipped and counted while the rest load

### Requirement: Your MAC and login stay in the Keychain
The system SHALL read a Stalker source's MAC, password and optional login from its Keychain item only, and SHALL never keep the MAC in the synced source, a favorite, a channel id or a log.

#### Scenario: Three kinds of Keychain item
- **GIVEN** a Keychain item with a MAC, password and login, an item saved before this change with only a MAC and password, and an item whose username is not a MAC
- **WHEN** the app reads each one for a Stalker source
- **THEN** the first gives all three, the second loads without a login so no login step runs, and the third counts as no credential
- **AND** the MAC is kept only in the Keychain item, never in the synced source, a favorite, a channel id or a log
