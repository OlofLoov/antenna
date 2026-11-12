# guide-data Specification

## Purpose
Downloads each source's TV guide, matches its programmes to the user's channels, and answers what is on now, what is next and what is on between two times, while telling screens how far a download has got and why it failed. It serves the viewer who wants "to see what is on now and next without leaving the picture" and "a guide grid of what is on across channels over the coming days", and the user who wants several subscriptions "merged into one channel list and one guide".

## Requirements

### Requirement: Find the guide for each source
The system SHALL use the guide link the user entered for a source, else for a playlist the first guide link the playlist names, else for an Xtream source the provider's guide link built from the user's login, else for a Stalker portal the portal's own guide. Working this out SHALL send nothing over the network.

#### Scenario: Order of preference
- **GIVEN** a source
- **WHEN** the app works out where its guide lives
- **THEN** it uses the entered link, else the playlist's first link, else the Xtream provider's link, else the Stalker portal's own guide, and nothing goes over the network

#### Scenario: No guide
- **GIVEN** a playlist with no guide link
- **WHEN** the app works out where its guide lives
- **THEN** the source has no guide

#### Scenario: Stalker portal without a guide link
- **GIVEN** a Stalker portal source with no guide link entered
- **WHEN** the app works out where its guide lives
- **THEN** the source uses the portal's own guide

#### Scenario: Stalker session turned down while loading the guide
- **GIVEN** a Stalker portal guide download that the portal turns down
- **WHEN** the guide loads
- **THEN** the portal session is renewed once and the download is tried once more

#### Scenario: Link changed on another device
- **GIVEN** a guide link changed on another device
- **WHEN** the next refresh runs
- **THEN** the new link is used

### Requirement: Login not on this device
The system SHALL download nothing for an Xtream source without its own guide link whose login is missing or unreadable on this device, SHALL tell callers once, and SHALL load the guide at the next refresh trigger after the login arrives. A source that has no login key at all SHALL count as a missing login.

#### Scenario: Login missing or unreadable
- **GIVEN** an Xtream source with no guide link of its own whose login has not reached this device or cannot be read
- **WHEN** its guide is due to load
- **THEN** nothing is downloaded, callers hear once that the login is missing or unreadable, and its channels report the guide as unavailable while the login is missing, or failed when it cannot be read

#### Scenario: Login arrives
- **GIVEN** that source's login reaches the device
- **WHEN** the next refresh trigger fires
- **THEN** the guide loads without the user doing anything

#### Scenario: Guide already loaded
- **GIVEN** an Xtream source whose guide loaded, and whose login then goes missing
- **WHEN** a refresh runs
- **THEN** callers hear that the login is missing, and the loaded guide keeps answering

### Requirement: Programmes land on the right channels
The system SHALL match programmes to channels within each source by guide id, ignoring spaces and newlines around the ids and otherwise matching exactly, case included, whichever of the guide and the channel list loads first.

#### Scenario: Ids with spaces, a channel without an id, two sources
- **GIVEN** a channel and a programme whose guide ids differ only by spaces around them, a channel with no guide id, and two sources whose guides both use the id "one"
- **WHEN** the guide and the channel list have both loaded, in either order
- **THEN** the first channel gets its programme, the channel without an id gets none and reports no data, and each source's channels get programmes only from that source's guide

#### Scenario: Stalker source with a guide link
- **GIVEN** a Stalker source with its own guide link
- **WHEN** the guide loads
- **THEN** it downloads, and every programme is unmatched until the source has channels

### Requirement: What is on now and next
The system SHALL answer which programme is on a channel at a given time, a programme being on from its start time up to but not including its stop time, and which programmes come next: up to the number asked for, in start order, each starting at or after the time given.

#### Scenario: Now and the next three
- **GIVEN** programmes 20:00 to 22:00, 22:00 to 23:00 and 23:15 to 00:00 on one channel
- **WHEN** a caller asks what is on at 21:34 and at 22:00, and for the next three from 22:00
- **THEN** 21:34 gives the 20:00 programme, 22:00 gives the 22:00 programme, a time with nothing on gives nothing, and the next three are the 22:00 and 23:15 programmes in order

#### Scenario: None asked for
- **GIVEN** the same channel
- **WHEN** a caller asks for the next zero programmes
- **THEN** it gets none

#### Scenario: Guide entirely in the past
- **GIVEN** a guide whose programmes have all ended
- **WHEN** a caller asks what is on now
- **THEN** nothing is on, and the guide still counts as loaded

### Requirement: Programmes in a time window
The system SHALL return every programme overlapping a time window, in start order, leaving gaps empty and leaving out channels with nothing in the window. Where two overlap the later start SHALL win and the earlier SHALL be cut short, never split. Of two with the same start, the one later in the guide file SHALL win. The guide's reach SHALL run from the earliest start to the latest stop across all sources, unmatched programmes included.

#### Scenario: Gaps, overlaps and a zero-length programme
- **GIVEN** programmes on a channel with a gap between two of them, some overlapping, and one that ends as it starts
- **WHEN** a caller asks for 20:00 to 22:00, or how far the guide reaches
- **THEN** it gets every overlapping programme in start order with the gap left empty, the later of two overlapping programmes wins, the zero-length one is ignored, and the reach spans all sources

#### Scenario: Same start twice
- **GIVEN** two programmes on one channel that both start at 20:00, "A" then "B" in the guide file
- **WHEN** a caller asks what is on at 20:00
- **THEN** it gets "B" only

#### Scenario: No programmes anywhere
- **GIVEN** no programmes from any source
- **WHEN** a caller asks how far the guide reaches
- **THEN** the guide has no reach

### Requirement: Progress a screen can show
The system SHALL report download progress in bytes, with the total when the server gives one, after the first 64 KiB, then at most every 250 ms, then with the final count when it differs. After a load, and again each time the source's channels are loaded, it SHALL report the channels with any programme, the channel total, the days covered and the unmatched programmes, or why the load failed. A late caller SHALL first hear each source's latest news, in source order.

#### Scenario: Listening to a load
- **GIVEN** guides loading
- **WHEN** a caller listens for progress
- **THEN** it hears bytes arrived and the total as the download runs, then per source the channels with a guide, the channel total, the days covered and the unmatched count, or the failure

#### Scenario: Days covered
- **GIVEN** a guide whose programmes run from yesterday to 06:00 UTC the day after tomorrow
- **WHEN** the counts are reported
- **THEN** the days are 3, counting UTC calendar days from today on which a programme starts or is on at midnight UTC

#### Scenario: Channels change after the load
- **GIVEN** a source whose guide has loaded
- **WHEN** its channel list is loaded again
- **THEN** callers hear fresh counts for the new list

#### Scenario: Late listener
- **GIVEN** guides that have already loaded
- **WHEN** a caller starts listening
- **THEN** it first hears the latest news for each source

### Requirement: A guide state that does not flicker
The system SHALL report each channel's guide as loading, unavailable or failed before its source's first completed download, and as having a guide or no data after one, keeping that state through later refreshes, failed and offline ones included. Guides SHALL be kept in memory only. A source that no longer has any guide link SHALL lose its guide and report unavailable.

#### Scenario: Before and after the first download
- **GIVEN** a source
- **WHEN** a caller asks for a channel's guide state
- **THEN** before the first completed download it is loading, unavailable (no guide link) or failed, and after one it is "has a guide" or "no data"

#### Scenario: Playlist not loaded yet
- **GIVEN** a playlist source with no entered guide link whose playlist has not loaded on this device
- **WHEN** guides refresh
- **THEN** nothing is downloaded and its channels report loading until the playlist loads

#### Scenario: A channel from no source
- **GIVEN** a channel that is not tagged with a source
- **WHEN** a caller asks for its guide state
- **THEN** it is unavailable

#### Scenario: A later refresh fails
- **GIVEN** a source whose guide loaded once
- **WHEN** a later refresh fails or the device is offline
- **THEN** the state does not change, the previous guide still answers, and the failure is reported only through progress

#### Scenario: The guide link goes away
- **GIVEN** a playlist source whose guide loaded from an entered link, which the user then clears, and whose loaded playlist names no guide
- **WHEN** its guide is next due to load
- **THEN** its programmes are dropped and its channels report unavailable

#### Scenario: App launched again
- **GIVEN** guides that loaded before the app quit
- **WHEN** the app launches
- **THEN** no programmes are available until each guide downloads again

### Requirement: Failures say why
The system SHALL report a failed guide load as a server error with its code, a timeout, offline, another network failure with its code, malformed, empty, unsupported, login refused or too large, SHALL stop a download as soon as it crosses the size limit, and SHALL leave other sources' guides untouched. Only the provider's own Xtream guide link SHALL turn 401 and 403 into login refused; any other link reports the status.

#### Scenario: Each failure
- **GIVEN** a guide link that answers with an error, times out, fails offline, sends a damaged or unreadable file, sends a file with no programmes, refuses the user's login, or is larger than the limit
- **WHEN** the guide loads
- **THEN** the caller hears the matching reason, a too-large download stops as soon as it crosses the limit, and other sources' guides are untouched

#### Scenario: Offline and other network failures
- **GIVEN** a download that fails as not connected, connection lost or data not allowed, or as cannot connect to host
- **WHEN** the guide loads
- **THEN** the first three report offline and the last reports a network failure with that code

#### Scenario: Status 401 on an entered link
- **GIVEN** a guide link the user entered that answers 401
- **WHEN** the guide loads
- **THEN** it fails as a server error with status 401, not as a refused login

#### Scenario: Empty body
- **GIVEN** a guide link that answers 200 with no body, or only whitespace
- **WHEN** the guide loads
- **THEN** it fails as empty

#### Scenario: HTML login page
- **GIVEN** a provider that answers with an HTML login page instead of a guide
- **WHEN** the guide loads
- **THEN** it fails as empty or malformed, not as a crash or a silent blank

### Requirement: Download limits and timeouts
The system SHALL fail a guide as too large past 32 MB of gzip or 96 MB of XML on Apple TV, and 96 MB of gzip or 256 MB of XML elsewhere, counting 1,000,000 bytes to the MB and checking unpacked XML too. A declared length over the limit SHALL fail once the first bytes show the kind of file. A download SHALL time out after 30 seconds without data or 600 seconds in all, and SHALL use no cache and no cookies.

#### Scenario: Declared length over the limit
- **GIVEN** a gzip guide whose server declares a length above the gzip limit
- **WHEN** the guide loads
- **THEN** it fails as too large after the first chunk, without reading the rest

#### Scenario: A small file that unpacks too large
- **GIVEN** a gzip guide under the gzip limit that unpacks past the XML limit
- **WHEN** the guide loads
- **THEN** it fails as too large

#### Scenario: Request settings
- **GIVEN** any guide download
- **WHEN** the request is sent
- **THEN** it sends no cookie and no range, reads nothing from a cache, and times out as described

### Requirement: Refreshed about twice a day
The system SHALL download only guides that are missing or completed more than 12 hours ago when the app launches, comes to the foreground, or finishes loading a source's channels. Guides SHALL download one at a time, in the sources' order. An explicit refresh SHALL download regardless of age, and SHALL restart a download already running for that source, putting it ahead of the queue. A changed guide link alone SHALL NOT make a guide stale.

#### Scenario: Stale and fresh sources
- **GIVEN** sources whose guide on this device is missing or more than 12 hours old, and others refreshed 12 hours ago or more recently
- **WHEN** the app launches, comes to the foreground, or finishes loading a source's channels
- **THEN** only the missing or stale guides download, never two at once, and a guide counts as fresh only if its programmes are on this device

#### Scenario: Explicit refresh
- **GIVEN** a guide loaded an hour ago, or one downloading now
- **WHEN** a refresh of that source is asked for
- **THEN** it downloads again, restarting a running download without reporting a failure

#### Scenario: Link changed while the guide is fresh
- **GIVEN** a guide that loaded an hour ago, whose link then changes
- **WHEN** the app comes to the foreground
- **THEN** nothing downloads, and the new link is used at the next download

#### Scenario: Offline or suspended
- **GIVEN** the device is offline without a previous guide, or the app is suspended mid-download
- **WHEN** the app next comes to the foreground
- **THEN** the guide is tried again, and with no sources nothing is requested

#### Scenario: A removed source comes back
- **GIVEN** a source whose guide was removed, and which is listed again
- **WHEN** guides refresh
- **THEN** it counts as a new source and its guide downloads

### Requirement: Logins never in the clear
The system SHALL keep every part of a login and the full guide link out of logs and file names. Logs SHALL show the link's scheme, host, port and path, with each query value replaced by "…", a query item without a value replaced whole by "…", and the login and fragment removed, plus only the source and the kind of failure. File names SHALL use the source's id only.

#### Scenario: Link with credentials
- **GIVEN** a guide link with a username, password or token in the query or before the host
- **WHEN** anything is logged or a file name is chosen
- **THEN** no log line or file name contains any part of the login or the full link

#### Scenario: Query items without values and a fragment
- **GIVEN** the links `http://epg.example/g.xml?abc123` and `http://epg.example/g.xml?token=abc123&key=k9#frag`
- **WHEN** they are logged
- **THEN** they read `http://epg.example/g.xml?…` and `http://epg.example/g.xml?token=…&key=…`

### Requirement: Compressed guides
The system SHALL unpack a gzip-compressed guide even when the server does not say it is compressed, reading only its first member, and SHALL fail as unsupported anything that is neither XML nor gzip, or gzip that does not hold XML. XML MAY start with a UTF-8 byte order mark and any amount of whitespace.

#### Scenario: Gzip without a header
- **GIVEN** a guide sent gzip-compressed without saying so
- **WHEN** it loads
- **THEN** it gives the same programmes as the uncompressed file

#### Scenario: Leading whitespace and a byte order mark
- **GIVEN** a guide that starts with hundreds of newlines, or with a UTF-8 byte order mark
- **WHEN** it loads
- **THEN** it gives the same programmes as the file without them

#### Scenario: Neither XML nor gzip
- **GIVEN** a guide link that sends some other kind of file, such as a PNG image, a UTF-16 guide, or gzip that unpacks to something other than XML
- **WHEN** it loads
- **THEN** it fails as unsupported

#### Scenario: Gzip that unpacks to nothing
- **GIVEN** a gzip guide that unpacks to no bytes
- **WHEN** it loads
- **THEN** it fails as empty

### Requirement: Deleting a source removes its guide
The system SHALL stop a deleted source's guide download, remove its programmes from every answer, shrink the guide's reach, report its channels as unavailable and send no more news about it, whether the delete happened on this device or through iCloud.

#### Scenario: Delete during or after a load
- **GIVEN** a source whose guide is loading or has loaded
- **WHEN** the source is deleted on this device or through iCloud
- **THEN** any download stops, its programmes disappear from every answer, the reach shrinks accordingly, its channels report unavailable, and callers hear nothing more about it

#### Scenario: Late listener after a delete
- **GIVEN** a deleted source that had sent news
- **WHEN** a caller starts listening
- **THEN** it hears nothing about that source

### Requirement: Guide from a source that serves programmes directly
The system SHALL take programmes for a source that serves them in batches straight from that source, instead of downloading an XMLTV file, and show progress batch by batch.

#### Scenario: A Jellyfin source's guide
- **GIVEN** a Jellyfin source with channels loaded
- **WHEN** the guide refreshes
- **THEN** the programmes come from the server in batches of channels, with no XMLTV download, and the loading progress counts batches

#### Scenario: Refresh fails
- **GIVEN** a Jellyfin source with a guide already loaded
- **WHEN** a refresh fails as no connection
- **THEN** the previous guide is kept

### Requirement: Guide address worked out from the source
The system SHALL fetch the guide for a source that knows its own guide address from that address when the user has set no guide link, sending the source's proxy password with the request.

#### Scenario: A Channels DVR source with a proxy password
- **GIVEN** a Channels DVR source with a proxy username and password and no guide link set by hand
- **WHEN** the guide refreshes
- **THEN** it downloads seven days of guide from the server's own guide address with the username and password sent
