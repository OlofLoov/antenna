# Spec Delta

## MODIFIED Requirements

### Requirement: Stalker type is stored
The system SHALL store a Stalker portal source with its MAC address as the Keychain username, its password beside it, and an optional login.

#### Scenario: Stalker save
- **GIVEN** type Stalker portal with a MAC address and password
- **WHEN** the source is saved
- **THEN** a source of kind Stalker exists, and the Keychain item under its id holds the MAC address as username and the password

#### Scenario: Stalker save with a login
- **GIVEN** type Stalker portal with a MAC address, password and login
- **WHEN** the source is saved
- **THEN** the Keychain item under its id also holds the login, and the synced source holds none of the three

## REMOVED Requirements

### Requirement: Stalker contributes no channels
**Reason**: Stalker portals now load their channels through the `stalker-portal-source` capability.
**Migration**: None. Existing Stalker sources start loading channels on the next refresh with their stored MAC and password.

## ADDED Requirements

### Requirement: Stalker channels are combined with other sources
The system SHALL load a Stalker portal source's channels into the combined channel list alongside every other source, and SHALL record a portal failure like any other source's.

#### Scenario: Stalker beside M3U
- **GIVEN** a Stalker source first in order with a stored credential and 3 channels, and an M3U source second with 2 channels
- **WHEN** the channel list loads
- **THEN** it holds the 3 Stalker channels followed by the 2 M3U channels
