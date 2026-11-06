## Purpose

Turns an M3U playlist into a stable list of channels and guide links, quickly enough that playlists with tens of thousands of entries do not stall the app. It serves the new user who wants "to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing", and the user with several subscriptions who wants "them merged into one channel list and one guide".

## ADDED Requirements

### Requirement: Header EPG URLs
The system SHALL read the guide links named by the `url-tvg` and `x-tvg-url` attributes of the `#EXTM3U` header, split on commas, and return them in the order written.

#### Scenario: Two guide links in the header
- **GIVEN** a header `#EXTM3U url-tvg="http://a/epg.xml,http://b/epg.xml.gz"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://a/epg.xml` and `http://b/epg.xml.gz`, in that order

#### Scenario: A junk guide link survives as a relative link
- **GIVEN** a `url-tvg` entry that is not a well-formed URL
- **WHEN** the playlist is parsed
- **THEN** the entry is kept as a relative link with its invalid characters percent-encoded, and is dropped only when no link can be formed at all

### Requirement: Standard attributes map to the channel
The system SHALL map the `#EXTINF` attributes `tvg-id`, `tvg-name`, `tvg-logo`, `group-title` and `tvg-chno` to the channel's guide id, name, logo, group and number. Attribute names SHALL be matched without regard to case, quoted and unquoted values SHALL both be read, and the last duplicate attribute SHALL win.

#### Scenario: All standard attributes present
- **GIVEN** an entry with `tvg-id="x.uk" tvg-name="X" tvg-logo="http://l/x.png" group-title="UK" tvg-chno="12"`
- **WHEN** the playlist is parsed
- **THEN** the channel has guide id "x.uk", name "X", logo `http://l/x.png`, group "UK" and number 12

#### Scenario: A channel number that is not an integer
- **GIVEN** an entry with `tvg-chno="twelve"`
- **WHEN** the playlist is parsed
- **THEN** the channel is produced with no number

### Requirement: Title fallback
The system SHALL use the text after the attribute block's closing comma as the channel name when `tvg-name` is absent or empty.

#### Scenario: No tvg-name
- **GIVEN** an entry whose `#EXTINF` has no `tvg-name`, or an empty one, and ends with `,Channel Title`
- **WHEN** the playlist is parsed
- **THEN** the channel name is "Channel Title"

#### Scenario: Neither name nor title
- **GIVEN** an entry with no `tvg-name` and nothing after the comma
- **WHEN** the playlist is parsed
- **THEN** the channel is produced with an empty name and is not skipped

#### Scenario: No comma at all
- **GIVEN** an `#EXTINF` line without a comma
- **WHEN** the playlist is parsed
- **THEN** the channel has an empty name, no attributes and a positional id, because the attribute block ends at the first unquoted comma

### Requirement: Comma inside a quoted attribute
The system SHALL treat a comma inside a quoted attribute value as part of the value, not as the start of the title.

#### Scenario: Group name with a comma
- **GIVEN** `group-title="Kids, Family",Cartoon Network`
- **WHEN** the playlist is parsed
- **THEN** the group is "Kids, Family" and the name is "Cartoon Network"

### Requirement: Empty tvg-id is not an EPG id
The system SHALL treat an empty `tvg-id` as no guide id.

#### Scenario: Empty tvg-id
- **GIVEN** an entry with `tvg-id=""`
- **WHEN** the playlist is parsed
- **THEN** the channel has no guide id

### Requirement: EXTGRP applies when no group-title
The system SHALL use a pending `#EXTGRP` value as the group of the next emitted channel that has no `group-title`, and SHALL clear the pending value once that channel is emitted.

#### Scenario: EXTGRP applies once
- **GIVEN** `#EXTGRP:News` between an `#EXTINF` without `group-title` and its URL, followed by a second `#EXTINF` without `group-title` and its URL
- **WHEN** the playlist is parsed
- **THEN** the first channel's group is "News" and the second channel has no group

#### Scenario: EXTGRP before the EXTINF
- **GIVEN** `#EXTGRP:News` placed before an `#EXTINF` without `group-title`
- **WHEN** the playlist is parsed
- **THEN** that channel's group is "News"

#### Scenario: EXTGRP on an entry that is never emitted
- **GIVEN** an `#EXTGRP` line attached to an orphan entry or one missing its URL
- **WHEN** the playlist is parsed
- **THEN** the value is not cleared and applies to the next entry that is emitted

### Requirement: group-title wins over EXTGRP
The system SHALL prefer an entry's own `group-title` over a pending `#EXTGRP` value.

#### Scenario: Both present
- **GIVEN** `#EXTGRP:News` between an `#EXTINF` with `group-title="Sport"` and its URL
- **WHEN** the playlist is parsed
- **THEN** the channel's group is "Sport"

### Requirement: Catch-up flags
The system SHALL mark a channel as having catch-up and record its number of days when `catchup` and `catchup-days` say so.

#### Scenario: Catch-up with days
- **GIVEN** `catchup="default" catchup-days="7"`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up, with 7 days

#### Scenario: Catch-up without days
- **GIVEN** `catchup="default"` alone
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up and no day count

### Requirement: Stable and unique ids
The system SHALL give every channel an id that is identical when the same playlist text is parsed again and unique within one parse, including entries that share a `tvg-id` but differ in URL.

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

### Requirement: Unknown directives are ignored
The system SHALL skip lines starting with `#` that it does not understand without losing the pending entry.

#### Scenario: EXTVLCOPT between EXTINF and URL
- **GIVEN** an `#EXTVLCOPT:http-user-agent=Foo` line between an `#EXTINF` and its URL
- **WHEN** the playlist is parsed
- **THEN** the channel is still produced with the URL that follows

### Requirement: Orphan URL lines are skipped
The system SHALL produce no channel for a URL line that has no preceding `#EXTINF`, and SHALL keep parsing the entries after it.

#### Scenario: Orphan before a valid pair
- **GIVEN** a URL line with no preceding `#EXTINF`, followed by a valid `#EXTINF` and URL pair
- **WHEN** the playlist is parsed
- **THEN** the orphan line produces no channel and the following pair produces one

#### Scenario: Two EXTINF lines in a row
- **GIVEN** two consecutive `#EXTINF` lines followed by one URL
- **WHEN** the playlist is parsed
- **THEN** the first `#EXTINF` is dropped and the second gets the URL

#### Scenario: Any text after EXTINF is taken as the URL
- **GIVEN** an `#EXTINF` followed by a line of free text that does not start with `#`
- **WHEN** the playlist is parsed
- **THEN** a channel is produced with that text, percent-encoded, as a relative stream URL, and no scheme check is made

#### Scenario: Windows line endings
- **GIVEN** a playlist with `\r\n` line endings
- **WHEN** the playlist is parsed
- **THEN** no URL or title ends with a carriage return

### Requirement: Empty input
The system SHALL return no channels and no guide links for empty input or input that holds only a header.

#### Scenario: Empty or header only
- **GIVEN** an empty string, or a string holding only `#EXTM3U`
- **WHEN** the playlist is parsed
- **THEN** the result has zero channels and zero guide links

### Requirement: Group list preserves first-seen order
The system SHALL list a playlist's groups once each, in the order they first appear.

#### Scenario: Repeated groups
- **GIVEN** channels in groups "B", "A", "B", "C"
- **WHEN** the playlist's group list is read
- **THEN** it is "B", "A", "C"

### Requirement: Large playlists stay fast
The system SHALL parse a playlist of 50,000 entries in under 5 seconds in a debug build on the reference machine. This is a benchmark run on request, not in the default test run or in CI.

#### Scenario: 50,000 entries
- **GIVEN** a generated playlist of 50,000 entries
- **WHEN** it is parsed in a debug build on the reference machine with benchmarks enabled
- **THEN** parsing completes within 5 seconds

### Requirement: Catch-up disabled explicitly
The system SHALL treat `catchup="0"` as no catch-up.

#### Scenario: catchup is 0
- **GIVEN** `catchup="0"`
- **WHEN** the playlist is parsed
- **THEN** the channel has no catch-up

#### Scenario: catchup 0 with tvg-rec
- **GIVEN** `catchup="0" tvg-rec="3"`
- **WHEN** the playlist is parsed
- **THEN** the channel has no catch-up and 3 days, because `catchup` wins for the flag and `tvg-rec` still gives the days

### Requirement: Legacy tvg-rec
The system SHALL read `tvg-rec` as the catch-up flag and day count when `catchup` and `catchup-days` are absent. `catchup` SHALL win over `tvg-rec` for the flag and `catchup-days` SHALL win for the days.

#### Scenario: Only tvg-rec
- **GIVEN** only `tvg-rec="3"` and no `catchup` or `catchup-days`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up, with 3 days

#### Scenario: tvg-rec is 0
- **GIVEN** only `tvg-rec="0"`
- **WHEN** the playlist is parsed
- **THEN** the channel has no catch-up and 0 days
