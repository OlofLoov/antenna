# m3u-playlists Specification

## Purpose
Turns an M3U playlist into a stable list of channels and guide links, quickly enough that playlists with tens of thousands of entries do not stall the app. It serves the new user who wants "to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing", and the user with several subscriptions who wants "them merged into one channel list and one guide".

## Requirements

### Requirement: Header EPG URLs
The system SHALL read the guide links named by the `url-tvg`, `x-tvg-url` and `tvg-url` attributes of every `#EXTM3U` line, split on commas, with spaces around each entry trimmed and empty entries skipped. Per header line the `url-tvg` links SHALL come first, then the `x-tvg-url` links, then the `tvg-url` links, each in the order written. Links from later header lines SHALL follow, and repeats SHALL be kept.

#### Scenario: Two guide links in the header
- **GIVEN** a header `#EXTM3U url-tvg="http://a/epg.xml,http://b/epg.xml.gz"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://a/epg.xml` and `http://b/epg.xml.gz`, in that order

#### Scenario: Both attributes and a second header line
- **GIVEN** `#EXTM3U x-tvg-url="http://x" url-tvg="http://u"` followed later by `#EXTM3U url-tvg="http://third"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://u`, `http://x` and `http://third`, in that order

#### Scenario: Blank entries
- **GIVEN** `url-tvg=""`, or `url-tvg=" http://a , ,http://b"`
- **WHEN** the playlist is parsed
- **THEN** the first gives no guide link and the second gives `http://a` and `http://b`

#### Scenario: A junk guide link survives as a relative link
- **GIVEN** a `url-tvg` entry that is not a well-formed URL, such as `b c`
- **WHEN** the playlist is parsed
- **THEN** the entry is kept as a relative link with its invalid characters percent-encoded (`b%20c`), and is dropped only when no link can be formed at all

#### Scenario: The tvg-url spelling
- **GIVEN** a header `#EXTM3U tvg-url="http://t/epg.xml.gz"`
- **WHEN** the playlist is parsed
- **THEN** the guide link is `http://t/epg.xml.gz`

#### Scenario: All three spellings on one line
- **GIVEN** `#EXTM3U tvg-url="http://t" x-tvg-url="http://x" url-tvg="http://u"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://u`, `http://x` and `http://t`, in that order

### Requirement: Standard attributes map to the channel
The system SHALL map the `#EXTINF` attributes `tvg-id`, `tvg-name`, `tvg-logo`, `group-title` and `tvg-chno` to the channel's guide id, name, logo, group and number. Attribute names SHALL be matched without regard to case, quoted and unquoted values SHALL both be read, values SHALL be kept as written without trimming, and the last duplicate attribute SHALL win. An unquoted value SHALL end at the first space.

#### Scenario: All standard attributes present
- **GIVEN** an entry with `tvg-id="x.uk" tvg-name="X" tvg-logo="http://l/x.png" group-title="UK" tvg-chno="12"`
- **WHEN** the playlist is parsed
- **THEN** the channel has guide id "x.uk", name "X", logo `http://l/x.png`, group "UK" and number 12

#### Scenario: A channel number that is not an integer
- **GIVEN** an entry with `tvg-chno="twelve"`, or `tvg-chno="012"`
- **WHEN** the playlist is parsed
- **THEN** the first channel is produced with no number and the second with number 12

#### Scenario: A logo that is not a URL
- **GIVEN** an entry with `tvg-logo="not a url"`
- **WHEN** the playlist is parsed
- **THEN** the logo is kept as the relative link `not%20a%20url`, and an empty `tvg-logo` gives no logo

#### Scenario: Attribute reading stops at a bare word
- **GIVEN** an entry `#EXTINF:-1 foo tvg-id="x",T`, or `#EXTINF:-1 tvg-name=Two Words tvg-id="x",T`
- **WHEN** the playlist is parsed
- **THEN** reading stops at the first word that has no `=`, so the first channel has no guide id, and the second is named "Two" with no guide id

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
The system SHALL use a pending `#EXTGRP` value, trimmed of spaces, as the group of the next emitted channel that has no `group-title` attribute, and SHALL clear the pending value once any channel is emitted. A later `#EXTGRP` SHALL replace a pending one.

#### Scenario: EXTGRP applies once
- **GIVEN** `#EXTGRP:News` between an `#EXTINF` without `group-title` and its URL, followed by a second `#EXTINF` without `group-title` and its URL
- **WHEN** the playlist is parsed
- **THEN** the first channel's group is "News" and the second channel has no group

#### Scenario: EXTGRP before the EXTINF
- **GIVEN** `#EXTGRP:News` placed before an `#EXTINF` without `group-title`
- **WHEN** the playlist is parsed
- **THEN** that channel's group is "News"

#### Scenario: Two EXTGRP lines
- **GIVEN** `#EXTGRP:A` then `#EXTGRP:B` before one entry's URL
- **WHEN** the playlist is parsed
- **THEN** the channel's group is "B"

#### Scenario: EXTGRP on an entry that is never emitted
- **GIVEN** an `#EXTGRP` line attached to an orphan entry or one missing its URL
- **WHEN** the playlist is parsed
- **THEN** the value is not cleared and applies to the next entry that is emitted

### Requirement: group-title wins over EXTGRP
The system SHALL prefer an entry's own `group-title` over a pending `#EXTGRP` value, even when the `group-title` is empty.

#### Scenario: Both present
- **GIVEN** `#EXTGRP:News` between an `#EXTINF` with `group-title="Sport"` and its URL
- **WHEN** the playlist is parsed
- **THEN** the channel's group is "Sport"

#### Scenario: Empty group-title
- **GIVEN** `#EXTGRP:News` between an `#EXTINF` with `group-title=""` and its URL
- **WHEN** the playlist is parsed
- **THEN** the channel's group is the empty text, and the group list holds it as an empty group

### Requirement: Catch-up flags
The system SHALL mark a channel as having catch-up when it has a `catchup` attribute with any value other than "0", the empty value included. The day count SHALL be `catchup-days` read as an integer, and SHALL be none when that value is not an integer. A day count SHALL be kept even when the channel has no catch-up.

#### Scenario: Catch-up with days
- **GIVEN** `catchup="default" catchup-days="7"`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up, with 7 days

#### Scenario: Catch-up without days
- **GIVEN** `catchup="default"` alone, or `catchup=""`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up and no day count

#### Scenario: Days without catch-up
- **GIVEN** `catchup-days="7"` alone
- **WHEN** the playlist is parsed
- **THEN** the channel has no catch-up and 7 days

#### Scenario: Days that are not a number
- **GIVEN** `catchup="default" catchup-days="x" tvg-rec="3"`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up and no day count, because `catchup-days` is present and wins over `tvg-rec`

### Requirement: Stable and unique ids
The system SHALL derive a channel's id from its `tvg-id` and stream link when it has a guide id, and otherwise from its stream link and its position among the emitted channels, counting from 1. The same playlist text SHALL give the same ids on every parse. Ids SHALL be unique within one parse except for entries that share both `tvg-id` and stream link.

#### Scenario: Same text parsed twice
- **GIVEN** the same playlist text parsed twice
- **WHEN** the ids are compared
- **THEN** they are identical between runs and unique within one run, including two entries with the same `tvg-id` but different URLs, and an entry with `tvg-id="same.uk"` and link `http://s/one.ts` has the id `same.uk#http://s/one.ts`

#### Scenario: Identical tvg-id and URL
- **GIVEN** two entries with the same `tvg-id` and the same URL
- **WHEN** the playlist is parsed
- **THEN** both channels have the same id and neither is dropped

#### Scenario: Entries without tvg-id are positional
- **GIVEN** a playlist whose entries are reordered or have an entry inserted, with or without a `tvg-id`
- **WHEN** the playlist is parsed again
- **THEN** every later entry without `tvg-id` gets a new id, because its position counts every emitted channel, and those ids are stable only for byte-identical input

### Requirement: Unknown directives are ignored
The system SHALL skip lines starting with `#` that it does not understand, and blank lines, without losing the pending entry. Directive names SHALL be matched with their case as written, so `#extinf:` is an unknown directive. Spaces and tabs around every line SHALL be trimmed.

#### Scenario: EXTVLCOPT between EXTINF and URL
- **GIVEN** an `#EXTVLCOPT:http-user-agent=Foo` line between an `#EXTINF` and its URL
- **WHEN** the playlist is parsed
- **THEN** the channel is still produced with the URL that follows

#### Scenario: Blank line between EXTINF and URL
- **GIVEN** an `#EXTINF`, an empty line, then an indented URL line
- **WHEN** the playlist is parsed
- **THEN** the channel is produced with the URL, without the indent

#### Scenario: Lowercase directive
- **GIVEN** `#extinf:-1,T` followed by a URL
- **WHEN** the playlist is parsed
- **THEN** no channel is produced, because the URL has no preceding `#EXTINF`

### Requirement: Orphan URL lines are skipped
The system SHALL produce no channel for a URL line that has no preceding `#EXTINF`, and SHALL keep parsing the entries after it. A URL line from which no link can be formed SHALL drop the pending entry.

#### Scenario: Orphan before a valid pair
- **GIVEN** a URL line with no preceding `#EXTINF`, followed by a valid `#EXTINF` and URL pair
- **WHEN** the playlist is parsed
- **THEN** the orphan line produces no channel and the following pair produces one

#### Scenario: Two EXTINF lines in a row
- **GIVEN** two consecutive `#EXTINF` lines followed by one URL
- **WHEN** the playlist is parsed
- **THEN** the first `#EXTINF` is dropped and the second gets the URL

#### Scenario: Any text after EXTINF is taken as the URL
- **GIVEN** an `#EXTINF` followed by a line of free text that does not start with `#`, such as `http://a/b c`
- **WHEN** the playlist is parsed
- **THEN** a channel is produced with that text, percent-encoded, as its stream URL (`http://a/b%20c`), and no scheme check is made

#### Scenario: A line that forms no link
- **GIVEN** an `#EXTINF` followed by `http://a b`, whose host holds a space
- **WHEN** the playlist is parsed
- **THEN** no channel is produced and the entry is dropped

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
The system SHALL list a playlist's groups once each, in the order they first appear, leaving out channels with no group.

#### Scenario: Repeated groups
- **GIVEN** channels in groups "B", "A", "B", "C"
- **WHEN** the playlist's group list is read
- **THEN** it is "B", "A", "C"

### Requirement: Large playlists stay fast
The system SHALL parse a playlist of 50,000 entries in under 5 seconds in a debug build on the reference machine, an Apple M1 with 16 GB. This is a benchmark run on request, not in the default test run or in CI.

#### Scenario: 50,000 entries
- **GIVEN** a generated playlist of 50,000 entries, each with a `tvg-id` and one of 40 groups
- **WHEN** it is parsed in a debug build on the reference machine with benchmarks enabled
- **THEN** all 50,000 channels are produced within 5 seconds

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
The system SHALL read `tvg-rec` as the catch-up flag when `catchup` is absent and as the day count when `catchup-days` is absent, with the same rules as those attributes. `catchup` SHALL win over `tvg-rec` for the flag and `catchup-days` SHALL win for the days.

#### Scenario: Only tvg-rec
- **GIVEN** only `tvg-rec="3"` and no `catchup` or `catchup-days`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up, with 3 days

#### Scenario: tvg-rec is 0
- **GIVEN** only `tvg-rec="0"`
- **WHEN** the playlist is parsed
- **THEN** the channel has no catch-up and 0 days

#### Scenario: tvg-rec that is not a number
- **GIVEN** only `tvg-rec="yes"`
- **WHEN** the playlist is parsed
- **THEN** the channel has catch-up and no day count

### Requirement: Leading byte-order mark is ignored
The system SHALL ignore a byte-order mark at the very start of a playlist and parse the rest exactly as if it were not there.

#### Scenario: Header after a byte-order mark
- **GIVEN** a playlist that starts with a byte-order mark followed by `#EXTM3U url-tvg="http://a/epg.xml"`
- **WHEN** the playlist is parsed
- **THEN** the guide links are `http://a/epg.xml`, the same as without the mark

#### Scenario: First channel after a byte-order mark
- **GIVEN** a playlist with no header that starts with a byte-order mark followed by an `#EXTINF` line and its URL
- **WHEN** the playlist is parsed
- **THEN** that first channel is produced with its title and URL

#### Scenario: Only a byte-order mark
- **GIVEN** a playlist that holds only a byte-order mark
- **WHEN** the playlist is parsed
- **THEN** the result has zero channels and zero guide links

### Requirement: Title-first channel names
The system SHALL offer a parsing option that names a channel from its title after the comma before its `tvg-name`, for sources whose title is the name the user set.

#### Scenario: Title first
- **GIVEN** an entry with `tvg-name="KGWDT"` and the title "NBC"
- **WHEN** it is parsed with the title-first option
- **THEN** the channel is named "NBC"

#### Scenario: Empty title
- **GIVEN** an entry with `tvg-name="KGWDT"` and an empty title
- **WHEN** it is parsed with the title-first option
- **THEN** the channel is named "KGWDT"

### Requirement: Minor channel numbers
The system SHALL read a channel number with a part after the dot, such as 6.1, as a major and a minor number.

#### Scenario: An over-the-air number
- **GIVEN** an entry with `tvg-chno="6.1"`
- **WHEN** it is parsed
- **THEN** the channel has major number 6 and minor number 1

#### Scenario: A whole number
- **GIVEN** an entry with `tvg-chno="104"`
- **WHEN** it is parsed
- **THEN** the channel has number 104 and no minor number

### Requirement: Movies and episodes in a playlist are recognized
The system SHALL sort each playlist entry by the first rule that applies: a `series` folder in the link makes it an episode; a `movie` or `movies` folder a movie; a season and episode marker in the name, such as "S01E02", an episode; a group whose first word is VOD, Movie, Movies, Film or Films a movie; a live sign a live channel; a link ending in `.mp4`, `.mkv`, `.avi`, `.mov` or `.m4v` a movie. Every other entry SHALL be a live channel.

#### Scenario: A panel's movie link
- **GIVEN** an entry linking to `http://tv.example.net/movie/u/p/9.mkv`
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: A movie group
- **GIVEN** an entry in the group "VOD | Action" whose link has no file extension
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: An episode
- **GIVEN** an entry named "Show S01E02" linking to an `.mp4` file
- **WHEN** the playlist loads
- **THEN** the entry is an episode, not a movie

#### Scenario: A live channel
- **GIVEN** an entry in the group "Vodafone TV" linking to a `.ts` stream
- **WHEN** the playlist loads
- **THEN** the entry is a live channel

#### Scenario: A news channel served as an mp4 file
- **GIVEN** an entry `#EXTINF:-1 tvg-id="news24.example" group-title="News"` linking to `http://cdn.example/news24/live.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a live channel and shows in Live, not in Movies

#### Scenario: A movie file with a length
- **GIVEN** an entry `#EXTINF:5400,The Film` with no guide id, no group and no catch-up, linking to `http://cdn.example/the-film.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: A movie link beats live signs
- **GIVEN** an entry with a guide id and catch-up attributes linking to `http://tv.example.net/movie/u/p/9.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a movie

### Requirement: Live signs keep an entry live
The system SHALL count as live signs: catch-up attributes, a guide id, a group with the word Live, News, Sport or Sports or the text "24/7", and an `#EXTINF` duration of -1 or 0.

#### Scenario: Each live sign
- **GIVEN** an entry linking to an `.mp4` file with no movie folder, episode marker or movie group
- **WHEN** it has catch-up, a guide id, the group "UK | News", or the duration -1
- **THEN** the entry is a live channel

### Requirement: Playlist movies stay out of live channels
The system SHALL leave a playlist's movies out of its live channels everywhere live channels show, and out of the channel count of the onboarding checklist and Settings. Episodes and live channels SHALL keep their playlist order.

#### Scenario: A playlist with channels and movies
- **GIVEN** a playlist with two live channels, one movie and one episode
- **WHEN** it loads
- **THEN** Live lists the two channels and the episode, and not the movie

### Requirement: Playlist movies show in Movies
The system SHALL list a playlist's movies in the Movies section with the entry's name, its logo as the poster and its group as the category, and SHALL play a movie from its link. The Movies tab SHALL show on iPhone and Apple TV when a playlist's last load had movies, even without an Xtream source. A movie's id SHALL hold no link or login.

#### Scenario: Browsing playlist movies
- **GIVEN** a playlist with a movie "Film A" in the group "VOD | Action"
- **WHEN** the user opens Movies
- **THEN** "Film A" shows under "VOD | Action" and plays from its link

#### Scenario: A playlist without movies
- **GIVEN** only a playlist with live channels
- **WHEN** it loads
- **THEN** there is no Movies tab

#### Scenario: Series
- **GIVEN** a playlist with episodes only
- **WHEN** the user opens Series
- **THEN** the playlist adds no series
