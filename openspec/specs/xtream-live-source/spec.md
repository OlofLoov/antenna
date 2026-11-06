# xtream-live-source Specification

## Purpose
Lists an Xtream Codes provider's live categories and streams, builds their playable and guide links, and maps each stream onto the same channel shape as an M3U entry so the rest of the app does not care where a channel came from. It serves the new user who wants "to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing".

## Requirements

### Requirement: Request shape
The system SHALL send exactly one GET per call to `<server>/player_api.php` with the query items `username`, `password`, `action`, then the optional `category_id`, in that order. Every query value SHALL be percent-encoded outside the RFC 3986 unreserved set. The server's own path SHALL be kept without its trailing slashes, and any query or fragment on the server URL SHALL be dropped.

#### Scenario: Live streams for one category
- **GIVEN** credentials for `http://panel:8080` with username `u` and password `p`
- **WHEN** the live streams of category "3" are requested
- **THEN** exactly one GET goes to `http://panel:8080/player_api.php?username=u&password=p&action=get_live_streams&category_id=3`, and without a category the `category_id` item is absent

#### Scenario: Server URL with a path
- **GIVEN** a server URL `http://host/xtream`, `http://host/xtream/` or `http://host/xtream//`
- **WHEN** any call is made
- **THEN** it goes to `http://host/xtream/player_api.php`

#### Scenario: Server URL with a query or fragment
- **GIVEN** a server URL `http://h:8080/x/?token=1#frag`
- **WHEN** the guide link is built
- **THEN** it is `http://h:8080/x/xmltv.php?username=u&password=p`, without the token or fragment

### Requirement: Loose numeric types decode
The system SHALL decode numeric fields of a live stream whether they arrive as JSON numbers or as strings of a whole number, and SHALL read the category id as a string. An optional field that does not decode, such as a fractional `num`, a `tv_archive` of "yes", or an `epg_channel_id` or `stream_icon` that is not text, SHALL be left empty without dropping the row.

#### Scenario: Strings where numbers belong
- **GIVEN** a live stream where `num`, `stream_id`, `tv_archive` and `tv_archive_duration` are strings and `category_id` is the number 3
- **WHEN** it is decoded
- **THEN** the values are the matching integers and the category id is "3"

#### Scenario: A fractional string
- **GIVEN** a `num` holding "7.5", and a `stream_id` holding "42.0"
- **WHEN** they are decoded
- **THEN** the number is empty, because an integer decodes only from a whole number, and the stream id is 42

#### Scenario: Optional fields of the wrong type
- **GIVEN** a live stream with `tv_archive` "yes", `tv_archive_duration` 1e400 and `epg_channel_id` 5
- **WHEN** it is decoded
- **THEN** the row is kept with no archive flag, no archive duration and no guide id

#### Scenario: A broken row in the stream list
- **GIVEN** a live stream list with a row that is not an object, lacks `name` or `stream_id`, has a `name` that is a number, or whose `stream_id` is not a whole number
- **WHEN** the list is requested
- **THEN** that row is skipped, the other rows are returned in server order, a row with an empty `name` is kept, and duplicate stream ids are kept

#### Scenario: Empty list shapes
- **GIVEN** a category or stream list body of `[]`, `{}`, `false` or `null`
- **WHEN** it is requested
- **THEN** the list is empty, and any other body that is not an array fails as a decoding failure at path ""

### Requirement: Category id as number or string
The system SHALL read a category id given as a number or a string into the same string form. A category list SHALL fail whole, as a decoding failure naming the row and field, when any row lacks `category_id` or `category_name`.

#### Scenario: Mixed category ids
- **GIVEN** categories with `category_id` 7 in one item, "8" in another and 3.5 in a third
- **WHEN** they are decoded
- **THEN** the category ids are "7", "8" and "3.5"

#### Scenario: Category missing its name or id
- **GIVEN** a category list whose first item lacks `category_name`, or lacks `category_id`
- **WHEN** it is decoded
- **THEN** the whole category list fails to decode, at path "[0].category_name" or "[0].category_id"

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
The system SHALL map a live stream and its category name to a channel with id, name, number, group, guide id, logo, the `.ts` playable link and catch-up. Catch-up SHALL be on when `tv_archive` is above 0, and the day count SHALL be `tv_archive_duration` either way. An empty guide id or icon SHALL map to none; any other icon text SHALL become the logo, relative or not. A repeated category id SHALL take the first category's name.

#### Scenario: A BBC One stream
- **GIVEN** a stream with `stream_id` 42, `name` "BBC One", `num` 7, `stream_icon` "", `epg_channel_id` "", `tv_archive` 1, `tv_archive_duration` 3 and category name "UK" on host `panel`
- **WHEN** it is mapped to a channel
- **THEN** the id is `xtream#panel#42`, name "BBC One", number 7, group "UK", no guide id, no logo, and catch-up of 3 days

#### Scenario: Archive duration without archive
- **GIVEN** a stream with `tv_archive` 0, `tv_archive_duration` "3" and `stream_icon` "p.jpg"
- **WHEN** it is mapped to a channel
- **THEN** the channel has no catch-up, a day count of 3, and the relative logo `p.jpg`

#### Scenario: Unknown or repeated category
- **GIVEN** a stream whose `category_id` matches no category, and two categories sharing the id "7" named "A" then "B"
- **WHEN** the provider's channels are loaded
- **THEN** the first stream has no group, and streams in category "7" are in group "A"

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
The system SHALL read the account's expiry date and connection limit as text whether they arrive as numbers or strings. The account call SHALL fail as a decoding failure when the body has no `user_info`, or when its `username` or `status` is present but not text.

#### Scenario: Number and string
- **GIVEN** `user_info` with `exp_date` as a number and `max_connections` as a string
- **WHEN** the account info is decoded
- **THEN** both are available as text

#### Scenario: Missing or mistyped fields
- **GIVEN** a body `{"foo":1}`, or `user_info` with `status` 1
- **WHEN** the account info is decoded
- **THEN** it fails as a decoding failure at path "user_info" or "user_info.status"

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
