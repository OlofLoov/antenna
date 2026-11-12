## MODIFIED Requirements

### Requirement: Stable and unique ids
The system SHALL derive a channel's id from its `tvg-id`, its name and its group, and never from its stream link. Entries that share all three SHALL be told apart by their order among those entries, counting from the first. The same playlist text SHALL give the same ids on every parse, and ids SHALL be unique within one parse.

#### Scenario: Same text parsed twice
- **GIVEN** the same playlist text parsed twice
- **WHEN** the ids are compared
- **THEN** they are identical between runs and unique within one run, including two entries with the same `tvg-id` and different names

#### Scenario: A login in the stream link
- **GIVEN** an entry whose link is `http://panel:8080/live/alice/s3cr3t/42.ts`
- **WHEN** the playlist is parsed
- **THEN** the channel's id contains neither the link, the host, `alice` nor `s3cr3t`

#### Scenario: New password, new server or reordered entries
- **GIVEN** a playlist parsed once, then again after the provider changed the password in every link, moved to another server, or reordered the entries
- **WHEN** the ids are compared
- **THEN** every channel keeps its id

#### Scenario: Entries without tvg-id are positional
- **GIVEN** an entry with no `tvg-id`, named "Kids TV" in group "Family"
- **WHEN** an entry is inserted before it and the playlist is parsed again
- **THEN** the channel keeps its id, because ids no longer count positions and its name and group did not change

#### Scenario: Identical tvg-id and URL
- **GIVEN** two entries with the same `tvg-id`, name and group, with the same link or different ones, such as a main and a backup stream
- **WHEN** the playlist is parsed
- **THEN** both channels are produced with different ids, the first keeps its id when the second is removed, and neither is dropped

#### Scenario: A renamed channel
- **GIVEN** a channel whose name or group the provider changes
- **WHEN** the playlist is parsed again
- **THEN** the channel gets a new id

### Requirement: Title fallback
The system SHALL use the text after the attribute block's closing comma, with spaces around it trimmed, as the channel name when `tvg-name` is absent or empty. A `tvg-name` holding only spaces SHALL be used as it is.

#### Scenario: No tvg-name
- **GIVEN** an entry whose `#EXTINF` has no `tvg-name`, or an empty one, and ends with `,Channel Title`
- **WHEN** the playlist is parsed
- **THEN** the channel name is "Channel Title"

#### Scenario: Neither name nor title
- **GIVEN** an entry with no `tvg-name` and nothing after the comma
- **WHEN** the playlist is parsed
- **THEN** the channel is produced with an empty name and is not skipped

#### Scenario: No comma at all
- **GIVEN** an `#EXTINF` line without a comma, or one whose quotes never close
- **WHEN** the playlist is parsed
- **THEN** the channel has an empty name and no attributes, because the attribute block ends at the first unquoted comma

## ADDED Requirements

### Requirement: Earlier ids map to the new ones
The system SHALL report, for each channel in a parse, the id an earlier version of Antenna gave the same entry, so references saved with that id can move to the new one. The earlier id SHALL be used for nothing else and SHALL never be logged.

#### Scenario: A channel with a guide id
- **GIVEN** an entry with `tvg-id="same.uk"` and link `http://s/one.ts`
- **WHEN** the playlist is parsed
- **THEN** the id earlier versions gave it, `same.uk#http://s/one.ts`, maps to the channel's new id

#### Scenario: A channel without a guide id
- **GIVEN** the third entry of a playlist, with no `tvg-id` and link `http://s/three.ts`
- **WHEN** the playlist is parsed
- **THEN** the earlier id `m3u#http://s/three.ts#3` maps to the channel's new id

#### Scenario: Two entries that shared an earlier id
- **GIVEN** two entries with the same `tvg-id` and the same link, which earlier versions gave one id
- **WHEN** the playlist is parsed
- **THEN** that earlier id maps to the first of the two

#### Scenario: An imported file with logins moved out
- **GIVEN** an imported file whose logins were moved to the Keychain
- **WHEN** it loads
- **THEN** the earlier ids are the ones built from the synced text with its placeholders, as earlier versions built them, and the new ids are the same as before its logins were put back
