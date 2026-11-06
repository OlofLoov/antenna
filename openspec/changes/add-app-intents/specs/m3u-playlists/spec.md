# Spec Delta

## MODIFIED Requirements

### Requirement: Stable and unique ids
The system SHALL give every channel an id that is identical when the same playlist text is parsed again and unique within one parse, including entries that share a `tvg-id` but differ in URL. The id SHALL contain no part of the stream link, so it can be stored and synced without exposing a login.

#### Scenario: Same text parsed twice
- **GIVEN** the same playlist text parsed twice
- **WHEN** the ids are compared
- **THEN** they are identical between runs and unique within one run, including two entries with the same `tvg-id` but different URLs

#### Scenario: Identical tvg-id and URL
- **GIVEN** two entries with the same `tvg-id` and the same URL
- **WHEN** the playlist is parsed
- **THEN** both channels have the same id and neither is dropped

#### Scenario: Entries without tvg-id are positional
- **GIVEN** a playlist whose entries without `tvg-id` are reordered or have an entry inserted before them
- **WHEN** the playlist is parsed again
- **THEN** every later entry without `tvg-id` gets a new id, because those ids are stable only for byte-identical input

#### Scenario: A stream link with a login
- **GIVEN** an entry whose stream link contains a username and password
- **WHEN** the playlist is parsed
- **THEN** the channel's id contains neither the link, the username nor the password
