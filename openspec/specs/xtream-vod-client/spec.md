# xtream-vod-client Specification

## Purpose
Lists an Xtream provider's movie and series categories, titles, per-title details and episodes, with stable ids, tolerant decoding and playable links, and sets the error and credential rules every Xtream call follows. It serves the movie and series watcher who wants "to browse my provider's movies and series with posters and details, like a streaming app", and the series watcher who wants "to pick a season and episode and see what each one is about".

## Requirements

### Requirement: Request shape
The system SHALL send exactly one GET per call to `<server>/player_api.php` with the query items `username`, `password`, `action`, then the id item (`category_id`, `vod_id` or `series_id`) when an id is given. The account call SHALL have no `action`. Both credentials SHALL be percent-encoded outside the RFC 3986 unreserved set.

#### Scenario: Every call
- **GIVEN** credentials for server H with username `alice-7f3e` and password `a&b/c+d`
- **WHEN** each of the movie, series, live and account calls runs
- **THEN** each issues one GET whose query is `username=alice-7f3e&password=a%26b%2Fc%2Bd&action=<action>[&<id item>]`, with `action` one of `get_vod_categories`, `get_vod_streams`, `get_vod_info`, `get_series_categories`, `get_series`, `get_series_info`, `get_live_categories` or `get_live_streams`

#### Scenario: Guide link
- **GIVEN** the same credentials
- **WHEN** the guide link is built
- **THEN** it targets `<server>/xmltv.php` with `username` and `password` only, encoded the same way

### Requirement: VOD item fields
The system SHALL read a movie row's stream id, name, poster, added date, rating, container extension and category, and SHALL give it the id `xtream#<host>#vod#<stream_id>`. A name or category given as a number SHALL be read as its text.

#### Scenario: Dune
- **GIVEN** a `get_vod_streams` row with `stream_id` 55, `name` "Dune", `stream_icon` "http://h/p.jpg", `added` "1730600000", `rating` "7.4", `container_extension` "mkv", `category_id` "12"
- **WHEN** it is decoded with host H
- **THEN** the movie has stream id 55, id "xtream#H#vod#55", name "Dune", poster `http://h/p.jpg`, added at Unix time 1730600000, rating 7.4, extension "mkv" and category "12"

#### Scenario: No category
- **GIVEN** a row without `category_id`
- **WHEN** it is decoded
- **THEN** the movie has no category

#### Scenario: Numbers for text
- **GIVEN** a row with `name` 1917 and `category_id` 12.0
- **WHEN** it is decoded
- **THEN** the movie is named "1917" and its category is "12"

### Requirement: Loose forms
The system SHALL read ids given as numbers or strings, and dates and ratings given as numbers or numeric strings. "N/A", "", null, a rating of 0 or below, and a rating that is not finite SHALL give no value.

#### Scenario: Each form
- **GIVEN** the Dune row with `stream_id` and `category_id` each as number or string, and `added` and `rating` each as a number, a numeric string, "N/A", "" and null
- **WHEN** it is decoded
- **THEN** the ids equal the Dune values in every form, `added` and `rating` equal them for the number and numeric-string forms and are absent for the others

#### Scenario: Zero, negative or infinite rating
- **GIVEN** `rating` 0, "0", -2, "inf" or "nan"
- **WHEN** it is decoded
- **THEN** the rating is absent

### Requirement: URL fields
The system SHALL accept an image link only when it parses with an `http` or `https` scheme and a non-empty host. The rule SHALL apply to `stream_icon`, `cover` and each `backdrop_path` entry.

#### Scenario: Poster links
- **GIVEN** `stream_icon` values `http://h/p.jpg`, `https://h/p.jpg`, `ftp://h/p`, `//h/p`, `p.jpg`, `""` and `http://`
- **WHEN** they are decoded
- **THEN** only the first two give a poster

### Requirement: Unparseable added date
The system SHALL leave the added date empty for any value that is not a usable Unix time, and SHALL never crash on it.

#### Scenario: Bad dates
- **GIVEN** `added` values "0", "", null, "abc", "nan", "inf", "-inf", "1e400" and a number too large for an integer
- **WHEN** they are decoded
- **THEN** each gives no date and decoding never crashes

### Requirement: Broken rows are skipped
The system SHALL skip and count a list row that is not an object, lacks its id, lacks a `name` that is non-blank text or an integer, has an id that is not a whole number, or repeats an earlier row's id. Other bad fields SHALL leave that field empty and keep the row. An integer SHALL decode only from a whole number in range, never truncated, never crashing.

#### Scenario: Six broken rows
- **GIVEN** a movie list where one element is not an object, one row lacks `stream_id`, one lacks `name`, one has `stream_id` "abc", one has "1e400" and one repeats an earlier `stream_id`
- **WHEN** it is decoded
- **THEN** the other rows are returned in server order and 6 are counted as skipped, the first occurrence of a repeated id winning

#### Scenario: Whole numbers
- **GIVEN** integer fields holding `55`, `55.0`, `"55"`, `"55.0"`, `"55.7"`, `55.7`, "1e2" and "0x37"
- **WHEN** they are decoded
- **THEN** the first four give 55 and the rest do not decode

#### Scenario: Blank optional strings
- **GIVEN** a movie, series or episode row with empty or whitespace-only optional strings, or a blank `name`
- **WHEN** it is decoded
- **THEN** the optional strings are empty, and a row with a blank name is skipped

#### Scenario: Live stream list
- **GIVEN** a live stream list with a row that is not an object, lacks `name` or `stream_id`, or whose `stream_id` does not decode
- **WHEN** it is requested
- **THEN** that row is skipped without a count, the others are returned, and duplicates are kept

### Requirement: Non-array list body
The system SHALL fail a list whose body is not an array as a decoding error naming the dotted path that failed, "" for the root. The error SHALL contain no part of the body eight bytes or longer.

#### Scenario: Object, string, boolean or HTML
- **GIVEN** a list body that is a JSON object other than `{}`, a string, `true`, or an HTML login page
- **WHEN** it is decoded
- **THEN** it fails as a decoding error at path "", and the error text holds no eight-byte piece of the body

#### Scenario: Nested failure
- **GIVEN** a failure inside the fourth row's `stream_id`
- **WHEN** it is decoded
- **THEN** the path is "[3].stream_id"

### Requirement: Category lists fail whole
The system SHALL fail a whole category list when any row lacks `category_name`, and no call SHALL let a raw decoder error escape.

#### Scenario: Second row without a name
- **GIVEN** a movie or series category list of three rows where the second lacks `category_name`
- **WHEN** it is requested
- **THEN** it fails as a decoding error at path "[1].category_name"

#### Scenario: Account call on HTML
- **GIVEN** the account call answered by an HTML page
- **WHEN** it runs
- **THEN** it fails as a decoding error at path ""

### Requirement: VOD info
The system SHALL read a movie's plot, year, duration, genre, age rating, backdrops, container extension, cast, director, rating and trailer link. Duration SHALL come from `duration_secs` when above 0, else from `duration` as `hh:mm:ss` or `mm:ss` of non-negative whole parts; 0 SHALL count as none. An `info` or `movie_data` that is missing, empty or not an object SHALL leave its fields empty.

#### Scenario: A full info body
- **GIVEN** a `get_vod_info` body with `info.plot` "A desert", `info.releasedate` "2024-03-01", `info.duration` "02:08:00", `info.duration_secs` 7680, `info.genre` "Sci-Fi", `info.age` "15", `info.backdrop_path` ["http://h/b1.jpg", "p.jpg"] and `movie_data.container_extension` "mkv"
- **WHEN** it is decoded
- **THEN** plot is "A desert", year 2024, duration 7680 seconds, genre "Sci-Fi", age rating "15", backdrops `http://h/b1.jpg` only, extension "mkv"

#### Scenario: Duration from text
- **GIVEN** the same body without `duration_secs`
- **WHEN** it is decoded
- **THEN** the duration is 7680 seconds from "02:08:00"

#### Scenario: Other duration texts
- **GIVEN** a `duration` of "02:08", "90:00", "1:2:3:4", "00:00:00" or "-1:00"
- **WHEN** it is decoded
- **THEN** "02:08" gives 128 seconds as minutes and seconds, "90:00" gives 5400 seconds, and the rest give no duration

#### Scenario: Info of the wrong type
- **GIVEN** a body `{"info":"x","movie_data":5}`
- **WHEN** it is decoded
- **THEN** every field is empty and the call does not fail

#### Scenario: Year and shapes
- **GIVEN** `info` absent, `{}` or `[]`; `movie_data` absent; `backdrop_path` as one string; a year in `release_date` or `releaseDate`; and a year of "0000"
- **WHEN** they are decoded
- **THEN** missing parts give empty fields, one backdrop string is accepted, the first non-empty of the three date keys gives the year even when a later key holds a better one, "0000" or a value not starting with four digits gives none, and `age` is read as number or string

#### Scenario: Cast, director and rating
- **GIVEN** an info body with a cast, a director and a rating of 7.4, and another with a rating of 0
- **WHEN** they are decoded
- **THEN** the first gives that cast, director and rating 7.4, and the second gives no rating

#### Scenario: Trailer link
- **GIVEN** a trailer field holding a full web address, an 11-character YouTube id, or anything else
- **WHEN** it is decoded
- **THEN** the address is kept as is, the id becomes a YouTube watch link, and anything else gives no trailer

### Requirement: Series row fields
The system SHALL read a series row's id, name, cover, last-modified date and category, and SHALL give it the id `xtream#<host>#series#<series_id>`.

#### Scenario: Dark
- **GIVEN** a `get_series` row with `series_id` 7, `name` "Dark", `cover` "http://h/c.jpg", `last_modified` "1730600000", `category_id` "3"
- **WHEN** it is decoded with host H
- **THEN** the series has id 7, id "xtream#H#series#7", name "Dark", poster `http://h/c.jpg`, last modified at Unix time 1730600000 and category "3"

#### Scenario: Last-modified rules
- **GIVEN** `last_modified` in the loose and unparseable forms used for movie added dates
- **WHEN** it is decoded
- **THEN** it follows the same rules

### Requirement: Episodes flatten
The system SHALL turn the episodes of a series into one flat list, whether keyed by season, given as an array, or given as an array of season arrays numbered from 0. A season SHALL give its episodes as an array, an object keyed by episode number, or one episode object, and nothing for any other value. An episode's season SHALL be its own `season`, else its season's key or position. Episode ids SHALL be `xtream#<host>#episode#<id>`, and a numeric title SHALL be read as text.

#### Scenario: Dictionary keyed by season
- **GIVEN** a `get_series_info` whose `episodes` is keyed "1", "2" and "10", each episode with `id`, `episode_num`, `title`, `container_extension` and `info.duration_secs`
- **WHEN** it is decoded with host H
- **THEN** the series details follow the movie info rules, and the episodes are one flat list with id, season, number, title, extension and duration

#### Scenario: Array of episodes
- **GIVEN** `episodes` as an array
- **WHEN** it is decoded
- **THEN** the same flat list results

#### Scenario: Array of season arrays
- **GIVEN** `episodes` as an array of three arrays, the first holding a special, the second two episodes of season 1 and the third an episode that says it is season 2
- **WHEN** it is decoded
- **THEN** the special is in season 0, the next two in season 1 and the last in season 2, and none are skipped

#### Scenario: A season keyed by episode number
- **GIVEN** season "1" as an object holding episodes under "2" and "1" and a string under "3", and season "2" as one episode object
- **WHEN** it is decoded
- **THEN** season 1 has its two episodes in order, season 2 has its one episode, and the string counts as one skipped episode

#### Scenario: Season and number fallback
- **GIVEN** episodes with no `season` of their own, a non-numeric season key, or an `episode_num` that is absent or not a number
- **WHEN** they are decoded
- **THEN** the season comes from the key when numeric, else none, the number is none when not numeric, and the response's `seasons` array is ignored

#### Scenario: Leading zeros, numbers and odd keys
- **GIVEN** `episodes` keyed "01" holding an episode with `id` "9", `title` 42 and `episode_num` "3", and a key "x" holding 5
- **WHEN** they are decoded
- **THEN** the one episode is in season 1, number 3, titled "42", and the "x" key adds nothing and is not counted as skipped

### Requirement: Episode order
The system SHALL sort episodes by season then number, numerically, with none before any value, keeping server order for ties.

#### Scenario: Shuffled episodes
- **GIVEN** episodes with seasons none, 1, 2 and 10 and numbers none, 1, 2 and 10 in shuffled order, plus two with equal season and number
- **WHEN** they are decoded
- **THEN** they are sorted by season then number, none first, and the tied pair keeps server order

#### Scenario: Season keys
- **GIVEN** `episodes` keyed by season, whose key order JSON does not keep
- **WHEN** they are decoded
- **THEN** seasons are visited by numeric key ascending, then other keys by name, and that order settles ties and first occurrences

### Requirement: Season count
The system SHALL count the distinct seasons of the resolved episodes, not the number of season keys.

#### Scenario: Episode with its own season
- **GIVEN** episodes under key "2" where one carries `season` 3 and the others none
- **WHEN** they are decoded
- **THEN** the season count is 2

### Requirement: Episode skipping and title fallback
The system SHALL skip and count an episode that is not an object, lacks an id, has an id that is not a whole number, or repeats an earlier id, keeping the first. An episode without a title SHALL be titled "Episode <number>", or "Episode" without a number.

#### Scenario: Broken episodes
- **GIVEN** an episode list where one element is not an object, one lacks `id`, one has `id` "abc", one has `title` "", one lacks `title` and one repeats an earlier `id`
- **WHEN** it is decoded
- **THEN** the first three and the repeat are skipped and 4 are counted, and the two untitled episodes read "Episode <number>", or "Episode" when there is no number

### Requirement: Empty episodes shapes
The system SHALL give no episodes, a season count of 0 and no skipped episodes when `episodes` is absent, `{}`, `[]`, or any value that is neither an array nor an object, such as `false` or a string.

#### Scenario: Each empty shape
- **GIVEN** `episodes` absent, `{}`, `[]`, `false` or `"x"`
- **WHEN** it is decoded
- **THEN** there are no episodes, the season count is 0 and none are skipped

### Requirement: Playable URLs
The system SHALL build movie and episode links as `<server>/movie/<user>/<password>/<id>.<ext>` and `<server>/series/<user>/<password>/<id>.<ext>`, keeping any server path. The extension SHALL be trimmed of whitespace and one leading dot, defaulting to "mp4". Credentials SHALL be encoded as for requests.

#### Scenario: Movie and episode
- **GIVEN** movie 55 with extension "mkv" and episode 901 with "mp4" on `http://h:8080` with user u and password p
- **WHEN** their links are built
- **THEN** they are `http://h:8080/movie/u/p/55.mkv` and `http://h:8080/series/u/p/901.mp4`

#### Scenario: Extension, path and encoding
- **GIVEN** an extension " .mkv " or none, a server `http://h/xtream`, and password `a&b/c+d`
- **WHEN** the movie link is built
- **THEN** the extension is "mkv" or "mp4", the path is kept as `http://h/xtream/movie/u/p/55.mkv`, and the password appears as `a%26b%2Fc%2Bd`, as it does in live and guide links

### Requirement: Errors and client values never carry credentials
The system SHALL keep the username, password, port and request paths out of the text of every error, credential and client value. The text of credentials and of a client SHALL be the server host alone.

#### Scenario: Secrets in descriptions
- **GIVEN** a client for `http://panel.example:8080` with username `alice-7f3e` and password `s3cr3t-9b2a`
- **WHEN** the descriptions of the credentials, the client and each error kind are read, along with each error's user info
- **THEN** none contains `alice-7f3e`, `s3cr3t-9b2a`, `:8080`, `player_api.php`, `/movie/`, `/series/` or `/live/`, and the credentials and client describe themselves as `panel.example`

### Requirement: Decoding is fast
The system SHALL decode a movie list of 50,000 rows in under 500 ms in a debug test run on the reference machine. This is a benchmark run on request, not in CI.

#### Scenario: 50,000 rows
- **GIVEN** a `get_vod_streams` body of 50,000 rows generated from a 20-row template
- **WHEN** it is decoded with benchmarks enabled
- **THEN** it completes in under 500 ms

### Requirement: Transport failures carry no URL
The system SHALL report a network failure as a transport error with its code only, carrying neither the server URL nor the credentials. A failure that carries no network code SHALL be a transport error with the unknown code.

#### Scenario: Each network failure
- **GIVEN** the network fails as not connected, connection lost, data not allowed, timed out, host not found or secure connection failed
- **WHEN** any call runs
- **THEN** it fails as a transport error with that code, and neither its description nor its user info holds the server URL or the credentials

### Requirement: Cancellation
The system SHALL report a call whose task is canceled in flight, or canceled once the response has arrived, as canceled, not as an Xtream error or a transport error.

#### Scenario: Task canceled
- **GIVEN** the calling task is canceled while the request is in flight
- **WHEN** any call runs
- **THEN** it fails as canceled

### Requirement: Unauthorized
The system SHALL fail every `player_api.php` call as a refused login on 401, 403, or a JSON object body whose `user_info.auth` is 0 as number or string. That check SHALL run only on object bodies, before other decoding. Other non-2xx SHALL fail with the status, a non-HTTP response with -1.

#### Scenario: Refused login
- **GIVEN** the server answers 401 or 403, or 200 with `{"user_info":{"auth":0}}` or `{"user_info":{"auth":"0"}}`
- **WHEN** any call runs, or a movie list is decoded from that body
- **THEN** it fails as a refused login

#### Scenario: Other statuses
- **GIVEN** the server answers 500, or a response that is not HTTP
- **WHEN** any call runs
- **THEN** it fails with status 500, or -1

#### Scenario: Array bodies and the auth field
- **GIVEN** an array body, `{"user_info":{"auth":1}}` and `{"user_info":{"auth":"yes"}}`
- **WHEN** they are decoded
- **THEN** the array is never checked for a refused login, the account's auth reads 1 for the first object and is absent for the second

### Requirement: Empty list shapes
The system SHALL treat a list or info body of `[]`, `{}`, `false` or `null` as empty. Any other info body that is not an object, a non-empty array included, SHALL fail as a decoding error.

#### Scenario: Empty bodies
- **GIVEN** a list call answering `[]`, `{}`, `false` or `null`, and a movie or series info call answering the same
- **WHEN** they are decoded
- **THEN** the list has no items and none skipped, and the info has every field empty, with no episodes, season count 0 and none skipped

#### Scenario: Info body that is not an object
- **GIVEN** an info body that is a string, a number or `[1]`
- **WHEN** it is decoded
- **THEN** it fails as a decoding error

### Requirement: Ids are stable
The system SHALL give the same row the same id in every response, and SHALL keep live, movie, series and episode ids apart. Ids SHALL ignore scheme and port.

#### Scenario: Four kinds sharing 55
- **GIVEN** a live stream, a movie, a series and an episode sharing numeric id 55 on host h, and the same row decoded twice
- **WHEN** their ids are compared
- **THEN** equal rows give equal ids, and the four kinds give `xtream#h#55`, `xtream#h#vod#55`, `xtream#h#series#55` and `xtream#h#episode#55`

### Requirement: Title id round trip
The system SHALL read a title id back into its host, kind and numeric id, and SHALL reject strings that are not well-formed title ids, including any that would not print back to the same string.

#### Scenario: Valid and invalid ids
- **GIVEN** `xtream#h#55`, `xtream#h#vod#55`, `xtream#h#series#55`, `xtream#h#episode#55`, `xtream#h#vod#abc`, `xtream#h#movie#55`, `xtream##55` and `m3u#x`
- **WHEN** each is read back
- **THEN** the first four give host "h", kinds live, movie, series and episode, and id 55, and the last four give nothing, `xtream##55` because its host is empty

#### Scenario: Forms that do not print back
- **GIVEN** `xtream#h#live#55`, `xtream#h#055` and `xtream#h#-5`
- **WHEN** each is read back
- **THEN** the first two give nothing, and the third gives a live id of -5

### Requirement: Episode description and picture
The system SHALL read each episode's description and picture when the provider gives them, and SHALL leave them empty otherwise.

#### Scenario: Episode with and without details
- **GIVEN** a series info body where one episode has a description and a picture and another has neither
- **WHEN** it is decoded
- **THEN** the first episode carries its description and picture, and the second has none

### Requirement: Panel bodies that are almost JSON
The system SHALL read a panel's answer that is JSON apart from a byte-order mark, a server notice printed before it, text after it, text in Latin-1 or Windows-1252, or tabs and line breaks typed inside a string, as the JSON it holds. A web page SHALL still fail to read.

#### Scenario: A notice before the series
- **GIVEN** a `get_series_info` answer that starts with a PHP notice, holds a plot in Windows-1252 with a raw tab and line break, and ends with a warning
- **WHEN** it is decoded
- **THEN** the plot reads "Café owner’s story" with its tab and line break, and the episode list is complete

#### Scenario: A byte-order mark
- **GIVEN** a series list or series answer that starts with a UTF-8 byte-order mark
- **WHEN** it is decoded
- **THEN** it reads as if the mark were not there, and a refused login is still reported as refused

#### Scenario: A web page
- **GIVEN** a login page, or any answer with `<html` or `<!doctype` before its first brace
- **WHEN** it is decoded
- **THEN** it fails as a body that is not JSON
