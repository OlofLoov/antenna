## ADDED Requirements

### Requirement: Provider replies are not kept on disk
The system SHALL keep no reply to a request that carries a provider login, in its address or its headers, in a cache on disk. The first launch of a version with this rule SHALL remove the replies an earlier version cached, on every platform.

#### Scenario: Loading an Xtream source
- **GIVEN** an Xtream source whose panel answers with no cache headers
- **WHEN** its channels, movies, series or account details load
- **THEN** no reply is cached, and the app's caches hold no address with the password

#### Scenario: Downloading a playlist link
- **GIVEN** an M3U source whose link carries a username and password
- **WHEN** the playlist downloads
- **THEN** the reply is not cached

#### Scenario: First launch after the update
- **GIVEN** an earlier version cached panel replies under addresses holding the password
- **WHEN** the app launches for the first time after the update
- **THEN** those cached replies are gone, and later launches leave the cache alone

#### Scenario: Posters still load from the cache
- **GIVEN** a poster shown before
- **WHEN** it shows again
- **THEN** it may come from the cache, since a poster address carries no login
