# jellyfin-live-tv-source Specification

## Purpose
Lets a Jellyfin user sign in to their home server with a username and password and get its Live TV channels, guide and streams in Antenna, with each device signed in on its own.

## Requirements

### Requirement: Connect checks it is really a Jellyfin server
The system SHALL check that a typed address points at a Jellyfin server, without sending the password, before it signs in.

#### Scenario: Check the server
- **GIVEN** a user who typed a server address, with or without a path such as `/jellyfin` or a trailing slash
- **WHEN** the user taps Connect
- **THEN** Antenna checks the server without sending the password and learns its id, name and version

### Requirement: Signing in remembers this device
The system SHALL send the username and password once per device, keep the sign-in key the server returns for that device, and send only the key afterwards.

#### Scenario: First sign-in on a device
- **GIVEN** a user with a username and password, and a device that has not signed in to this server before
- **WHEN** the app first needs the server, at Connect or a channel load
- **THEN** Antenna sends the username and password once and keeps the key the server returns for this device
- **AND** every later request carries that key and never the password

#### Scenario: The device name sent to the server
- **WHEN** Antenna signs in
- **THEN** the device name it sends names the platform, never the user's own device name

#### Scenario: The password has not synced yet
- **GIVEN** a source whose password has not reached this device, and a saved key for it
- **WHEN** the source loads
- **THEN** it shows no channels and the saved key is ignored

#### Scenario: Deleting the source
- **WHEN** the user deletes a Jellyfin source
- **THEN** this device's sign-in key for it is cleared

### Requirement: Different failures get different errors
The system SHALL report a turned-down password, a blocked account, an unreachable server, a server error and refused Live TV as distinct errors, sign in again only for a turned-down key, and keep the saved key in every case.

#### Scenario: Each failure maps to its own error
- **GIVEN** a server that turns down the password, blocks this account on this device, cannot be reached, has a server error, or refuses Live TV to an account it accepted
- **WHEN** the app asks for anything
- **THEN** it gets not authorized, forbidden, no connection or a server error respectively
- **AND** only a turned-down key leads to a new sign-in, and this device's saved key is kept in every one of these cases

#### Scenario: Offline
- **GIVEN** a device with no network
- **WHEN** the first request is made
- **THEN** it fails as no connection with no retry, and the guide keeps its previous programmes

#### Scenario: An old server
- **GIVEN** a server older than Jellyfin 10.8
- **WHEN** any request after sign-in is made
- **THEN** it fails as not authorized

### Requirement: A revoked sign-in renews itself once
The system SHALL sign in again once when the server turns down this device's key, repeat only the turned-down request, and give up after that.

#### Scenario: Key revoked mid-load
- **GIVEN** a device whose key the server has revoked while a long channel list is loading
- **WHEN** the server turns down a request
- **THEN** Antenna signs in again once, keeps the new key, repeats only that request and finishes the list with nothing missing

#### Scenario: The second try is also turned down
- **GIVEN** a revoked key
- **WHEN** the new sign-in or the repeated request is turned down too
- **THEN** the request fails as not authorized, the saved key is discarded, and there is no third try

#### Scenario: The password changed on the server
- **GIVEN** a source whose password was changed on the server
- **WHEN** the source loads
- **THEN** it shows as not authorized until the user signs in again

### Requirement: Every channel loads, however many there are
The system SHALL load every Live TV channel the server reports, in the server's order, up to a ceiling of 100 000 channels.

#### Scenario: A large server
- **GIVEN** a server with 2 345 channels
- **WHEN** the source loads
- **THEN** all 2 345 channels arrive in the server's order

#### Scenario: Past the ceiling
- **GIVEN** a server with more than 100 000 channels
- **WHEN** the source loads
- **THEN** the list is cut off at 100 000

### Requirement: Channels show their name, number and logo
The system SHALL give each Jellyfin channel its name, whole-number channel number, a "Radio" group for radio channels, its logo, no catch-up, and an identity that depends only on the server's host name.

#### Scenario: A channel in the catalogue
- **GIVEN** a channel on a server reached as `jf.local`
- **WHEN** it is shown in the catalogue
- **THEN** it has its name, its number when the server gives a whole number, the group "Radio" if it is a radio channel and no group otherwise, a logo when the server has one, and no catch-up
- **AND** its identity stays the same whatever port or `http` or `https` the user typed for that host, so favorites keep working

#### Scenario: Two host names for one server
- **GIVEN** the same server added under two host names
- **WHEN** both load
- **THEN** they give two sets of channel identities, and favorites are split between them

### Requirement: A broken answer is an error, not a crash
The system SHALL skip and count broken rows in a server answer while loading the rest in order, and SHALL fail with a reading error that quotes nothing from the answer when the answer is not a list at all.

#### Scenario: Broken rows and broken answers
- **GIVEN** a server-info, channel or guide answer with some broken rows, an empty answer, a web page, or an answer that is not a list at all
- **WHEN** Antenna reads it
- **THEN** broken rows (no id, name or channel, a programme that ends before it starts, an unreadable date, a channel listed twice) are skipped and counted while the rest load in order
- **AND** an empty answer gives an empty list
- **AND** a server answer without an id or version fails
- **AND** a web page or an answer that is not a list fails as a reading error that quotes nothing from the answer

#### Scenario: A reverse proxy answers with a web page
- **GIVEN** a badly set up reverse proxy in front of the server
- **WHEN** it answers with a web page
- **THEN** the request fails as a reading error

### Requirement: Streams play and logos stay key-free
The system SHALL build stream addresses that carry this device's key and play through the MPEG-TS route, and logo addresses that never carry the key.

#### Scenario: Build the addresses
- **GIVEN** a channel and this device's key, on a server with and without a path in its address
- **WHEN** Antenna builds the channel's stream and logo addresses
- **THEN** the stream address asks for the channel unchanged with the key in it and plays through the route for MPEG-TS, the raw stream format most IPTV uses
- **AND** the logo address carries no key, so image caches never hold it

#### Scenario: Key revoked while channels are loaded
- **GIVEN** channels loaded with a key the server has since revoked
- **WHEN** the user plays one
- **THEN** playback fails until the channels reload with the new key

### Requirement: The guide covers the coming week
The system SHALL return every programme that overlaps the requested window for the requested channels, including one already on air, and send nothing when no channels are asked for.

#### Scenario: A seven-day guide
- **GIVEN** 120 channels and a seven-day window starting now
- **WHEN** the guide asks for programmes
- **THEN** every programme that overlaps the window comes back, including one already on air, with its title, episode title, description, genre, picture and times

#### Scenario: No channels
- **WHEN** the guide asks for programmes for no channels
- **THEN** nothing is sent to the server

### Requirement: Secrets never show up in messages or logs
The system SHALL keep the username, password, sign-in key, port and server path out of every printed or logged source, sign-in detail and error, and print a source as its host name only.

#### Scenario: Print and log everything
- **GIVEN** a source with a username, password, device id and saved key
- **WHEN** the source, its sign-in details or any error is printed or logged, network errors included
- **THEN** none shows the username, password, the key in any form, the port or any server path, and the source prints as the server's host name only

### Requirement: Self-signed certificates are turned down
The system SHALL fail requests to a server with a self-signed, unknown, expired or not-yet-valid certificate as an untrusted certificate, without signing in again or touching the saved key.

#### Scenario: An untrusted certificate
- **GIVEN** a server whose certificate is self-signed, from an unknown authority, expired or not yet valid
- **WHEN** the app asks for anything
- **THEN** the request fails as an untrusted certificate, with no new sign-in and the saved key untouched, so the add-source form can tell the user to use `http` at home or a trusted certificate
