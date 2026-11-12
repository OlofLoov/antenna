## MODIFIED Requirements

### Requirement: Favorites reference stable channel ids
The system SHALL produce the same channel id for a channel when its source reloads with unchanged content, for M3U entries and for Xtream streams. For M3U entries the id SHALL also stay the same when the links, the login in them or the order of entries change, and SHALL never hold the stream link.

#### Scenario: Reload with unchanged content
- **GIVEN** a favorite for a channel from an M3U entry, or from an Xtream stream
- **WHEN** the same source is reloaded with unchanged content
- **THEN** the same channel id is produced, so the favorite still refers to it

#### Scenario: Positional M3U ids
- **GIVEN** a favorite for an M3U entry, with or without `tvg-id`
- **WHEN** the playlist order changes, or the provider changes the password in every link
- **THEN** the favorite still refers to that channel, because M3U ids no longer depend on position or link

#### Scenario: The synced favorite holds no login
- **GIVEN** an M3U playlist whose links carry the provider's username and password
- **WHEN** the user adds one of its channels to Favorites
- **THEN** the favorite that syncs through iCloud holds neither the link, the username nor the password

## ADDED Requirements

### Requirement: Favorites saved before the id change carry over
The system SHALL rewrite each favorite and own-group channel saved with an M3U channel's earlier id to its new id the first time its playlist loads on a device, keeping its place, profile and group, and SHALL keep a channel that ends up listed twice in Favorites or one own group only once.

#### Scenario: First launch after the update
- **GIVEN** a favorite of an M3U channel saved by an earlier version, whose id holds the stream link
- **WHEN** its playlist loads
- **THEN** the favorite stays in Favorites at the same place, and the stored favorite no longer holds the link

#### Scenario: Another device
- **GIVEN** the favorite was rewritten on one device
- **WHEN** a second device running this version syncs it and loads the same playlist
- **THEN** the favorite is listed once and the second device writes nothing more for it

#### Scenario: Two devices rewrite at once
- **GIVEN** two devices that rewrite the same favorite before either sees the other's change, or a favorite saved twice with the old and the new id
- **WHEN** the changes sync
- **THEN** the channel is listed once in Favorites

#### Scenario: Playlist not loaded on this device
- **GIVEN** a favorite with an earlier id whose playlist has not loaded on this device, fails to load, or was deleted
- **WHEN** Favorites is shown
- **THEN** the favorite is kept as it is, and is rewritten when its playlist next loads

#### Scenario: A channel the playlist no longer lists
- **GIVEN** a favorite with an earlier id whose channel is no longer in the playlist
- **WHEN** the playlist loads
- **THEN** the favorite is kept unchanged, as any favorite of a missing channel is

#### Scenario: Own groups
- **GIVEN** a channel in one of the user's own groups saved with an earlier id
- **WHEN** its playlist loads
- **THEN** it stays in that group at the same place, under its new id
