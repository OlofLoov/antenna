## Purpose

Lists an Xtream Codes provider's live categories and streams, builds their playable and guide links, and maps each stream onto the same channel shape as an M3U entry so the rest of the app does not care where a channel came from. It serves the new user who wants "to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing".

## ADDED Requirements

### Requirement: Request shape
The system SHALL send exactly one GET per call to `<server>/player_api.php` with the query items `username`, `password`, `action`, then the optional `category_id`, in that order. Both credentials SHALL be percent-encoded outside the RFC 3986 unreserved set.

#### Scenario: Live streams for one category
- **GIVEN** credentials for `http://panel:8080` with username `u` and password `p`
- **WHEN** the live streams of category "3" are requested
- **THEN** exactly one GET goes to `http://panel:8080/player_api.php?username=u&password=p&action=get_live_streams&category_id=3`, and without a category the `category_id` item is absent

#### Scenario: Server URL with a path
- **GIVEN** a server URL `http://host/xtream` or `http://host/xtream/`
- **WHEN** any call is made
- **THEN** it goes to `http://host/xtream/player_api.php`

### Requirement: Loose numeric types decode
The system SHALL decode numeric fields of a live stream whether they arrive as JSON numbers or as strings of a whole number, and SHALL read the category id as a string.

#### Scenario: Strings where numbers belong
- **GIVEN** a live stream where `num`, `stream_id`, `tv_archive` and `tv_archive_duration` are strings and `category_id` is the number 3
- **WHEN** it is decoded
- **THEN** the values are the matching integers and the category id is "3"

#### Scenario: A fractional string
- **GIVEN** a numeric field holding "7.5"
- **WHEN** it is decoded
- **THEN** it does not decode as 7, because an integer decodes only from a whole number

#### Scenario: A broken row in the stream list
- **GIVEN** a live stream list with a row that is not an object, lacks `name` or `stream_id`, or whose `stream_id` is not a whole number
- **WHEN** the list is requested
- **THEN** that row is skipped, the other rows are returned, and duplicate stream ids are kept

### Requirement: Category id as number or string
The system SHALL read a category id given as a number or a string into the same string form.

#### Scenario: Mixed category ids
- **GIVEN** categories with `category_id` 7 in one item and "8" in another
- **WHEN** they are decoded
- **THEN** the category ids are "7" and "8"

#### Scenario: Category missing its name
- **GIVEN** a category list where one item lacks `category_name`
- **WHEN** it is decoded
- **THEN** the whole category list fails to decode

#### Scenario: Repeated category id
- **GIVEN** categories with ids `7` and `"7"`
- **WHEN** they are decoded
- **THEN** both are returned with the id "7" and nothing is deduplicated

### Requirement: Live stream URL
The system SHALL build a live stream's playable link as `<server>/live/<username>/<password>/<stream id>.ts`, or `.m3u8` when asked, with both credentials percent-encoded.

#### Scenario: Stream 42
- **GIVEN** stream id 42 on `http://panel:8080` with username `u` and password `p`
- **WHEN** its playable link is built
- **THEN** it is `http://panel:8080/live/u/p/42.ts`, and in the HLS form it ends in `42.m3u8`

### Requirement: Guide URL
The system SHALL build the provider's guide link as `<server>/xmltv.php` with only `username` and `password` in the query, percent-encoded as for every request.

#### Scenario: Guide link
- **GIVEN** credentials for `http://panel:8080` with username `u` and password `p`
- **WHEN** the guide link is built
- **THEN** it is `http://panel:8080/xmltv.php?username=u&password=p`

### Requirement: Channel mapping
The system SHALL map a live stream and its category name to a channel with id, name, number, group, guide id, logo and catch-up days. An empty guide id or icon SHALL map to none.

#### Scenario: A BBC One stream
- **GIVEN** a stream with `stream_id` 42, `name` "BBC One", `num` 7, `stream_icon` "", `epg_channel_id` "", `tv_archive` 1, `tv_archive_duration` 3 and category name "UK" on host `panel`
- **WHEN** it is mapped to a channel
- **THEN** the id is `xtream#panel#42`, name "BBC One", number 7, group "UK", no guide id, no logo, and catch-up of 3 days

### Requirement: Non-2xx response is a typed error
The system SHALL report 401 and 403 responses, and a body whose `user_info.auth` is 0, as a refused login. Other non-2xx statuses SHALL fail with their status code, and a response that is not HTTP SHALL fail as status -1.

#### Scenario: Forbidden
- **GIVEN** the server answers 403
- **WHEN** any endpoint is called
- **THEN** the call fails as a refused login

#### Scenario: Server error
- **GIVEN** the server answers 500
- **WHEN** any endpoint is called
- **THEN** the call fails with status 500

#### Scenario: Bad credentials answered with 200
- **GIVEN** the server answers 200 with `{"user_info":{"auth":0}}`
- **WHEN** any endpoint is called
- **THEN** the call fails as a refused login

#### Scenario: Errors carry no secrets
- **GIVEN** any failed call
- **WHEN** its error is read or logged
- **THEN** it carries a status code or failure kind only, never a URL or credential

### Requirement: Malformed JSON is an error, not a crash
The system SHALL report a body it cannot decode as a decoding failure with an empty path, and SHALL NOT crash or let a raw decoder error reach the caller.

#### Scenario: HTML login page
- **GIVEN** the server answers 200 with an HTML login page
- **WHEN** the live streams are requested
- **THEN** the call fails as a decoding failure at path ""

### Requirement: Account info decodes loose types
The system SHALL read the account's expiry date and connection limit as text whether they arrive as numbers or strings.

#### Scenario: Number and string
- **GIVEN** `user_info` with `exp_date` as a number and `max_connections` as a string
- **WHEN** the account info is decoded
- **THEN** both are available as text

### Requirement: Ids are stable per server and stream
The system SHALL derive a channel id from the server host and stream id only, so the same stream gives the same id across responses.

#### Scenario: Same stream twice
- **GIVEN** the same stream decoded from two separate responses
- **WHEN** both are mapped to channels
- **THEN** the ids are equal, and two different stream ids on one server give different ids

#### Scenario: Scheme and port are ignored
- **GIVEN** two panels on one host with different ports, or one panel over http and https
- **WHEN** their streams are mapped
- **THEN** equal stream ids give colliding channel ids, and a server URL without a host gives `xtream##42`
