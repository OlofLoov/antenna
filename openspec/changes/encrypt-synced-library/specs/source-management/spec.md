## ADDED Requirements

### Requirement: The synced library is in encrypted fields
The system SHALL send everything it syncs through the user's private iCloud database to CloudKit in encrypted fields: sources and imported playlists, favorites, profiles, preferences, groups and the passcode check value, guide settings, reminders, watch progress, My list, recent searches and the names of the devices in Play on. With Advanced Data Protection on, only the user's devices hold the keys. A new kind of synced data SHALL follow the same rule.

#### Scenario: Looking at the iCloud records
- **GIVEN** a source, a favorite, a profile, watch progress and a recent search synced from one device
- **WHEN** the records are looked at in the iCloud database
- **THEN** each value is in an encrypted field, and only the record types, their count, size and change times are plain

#### Scenario: Another device reads them
- **GIVEN** a library synced in encrypted fields from device A
- **WHEN** device B on the same iCloud account receives it
- **THEN** B shows the same sources, favorites, profiles and progress as A

#### Scenario: An Apple TV's name
- **GIVEN** an Apple TV that lists itself for Play on
- **WHEN** its record is looked at in the iCloud database
- **THEN** its name is in an encrypted field, and the iPhone still lists the TV by that name

#### Scenario: A library from an earlier version
- **GIVEN** a device with sources and progress saved by a version without encrypted fields
- **WHEN** the new version opens
- **THEN** everything saved is still there
