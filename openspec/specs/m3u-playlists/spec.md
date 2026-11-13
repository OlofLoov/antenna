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
- **THEN** the channel has an empty name and no attributes, because the attribute block ends at the first unquoted comma

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
The system SHALL sort each playlist entry by the first rule that applies: a `series` folder in the link makes it an episode; a `movie` or `movies` folder a movie; an episode marker such as "S01E02" in the name an episode; a group starting with VOD a movie; a group starting with Movie or Film a movie when the link is a video file; a live sign a live channel; a video file a movie. A video file link ends in `.mp4`, `.mkv`, `.avi`, `.mov` or `.m4v`. Every other entry SHALL be a live channel.

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

#### Scenario: Live movie channels in a Movies group
- **GIVEN** entries in the group "Movies" linking to `http://tv.example/live/u/p/5.ts`, `http://tv.example/hls/film4.m3u8` and `http://tv.example/u/p/6`
- **WHEN** the playlist loads
- **THEN** each entry is a live channel and shows in Live

#### Scenario: Movie files in a Movies group
- **GIVEN** an entry `#EXTINF:-1 group-title="Movies | Drama"` linking to `http://cdn.example/files/the-film.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a movie

### Requirement: Live signs keep an entry live
The system SHALL count as live signs: catch-up attributes, a guide id, a group with the word Live, News, Sport or Sports or the text "24/7", and an `#EXTINF` duration of -1 or 0.

#### Scenario: Each live sign
- **GIVEN** an entry linking to an `.mp4` file with no movie folder, episode marker or movie group
- **WHEN** it has catch-up, a guide id, the group "UK | News", or the duration -1
- **THEN** the entry is a live channel

### Requirement: Playlist movies stay out of live channels
The system SHALL leave a playlist's movies and episodes out of its live channels everywhere live channels show, and out of the channel count of the onboarding checklist and Settings. Live channels SHALL keep their playlist order.

#### Scenario: A playlist with channels and movies
- **GIVEN** a playlist with two live channels, one movie and one episode
- **WHEN** it loads
- **THEN** Live lists the two channels, and not the movie or the episode

### Requirement: Playlist movies show in Movies
The system SHALL list a playlist's movies in the Movies section with the entry's name, its logo as the poster and its group as the category, and SHALL play a movie from its link. A movie's id SHALL hold no link or login. Where the Movies section shows is set by the requirement "Playlist titles show on every platform".

#### Scenario: Browsing playlist movies
- **GIVEN** a playlist with a movie "Film A" in the group "VOD | Action"
- **WHEN** the user opens Movies
- **THEN** "Film A" shows under "VOD | Action" and plays from its link

#### Scenario: A playlist without movies
- **GIVEN** only a playlist with live channels
- **WHEN** it loads
- **THEN** there is no Movies tab or section

#### Scenario: Series
- **GIVEN** an iPhone with only a playlist that has episodes
- **WHEN** it loads
- **THEN** the Movies tab shows and its Series part lists the playlist's shows

### Requirement: Playlist episodes group into series
The system SHALL group a playlist's episodes into series by the show name, the part of the entry name before its season and episode marker, ignoring case, punctuation and spacing. Each episode SHALL take its season, number and title from the name, and episodes SHALL be ordered by season, then number. Series and episode ids SHALL hold no link or login.

#### Scenario: Two seasons of one show
- **GIVEN** entries named "Show S02E01", "Show - S01E02 - The Visit" and "show s01e01"
- **WHEN** the playlist loads
- **THEN** there is one series "Show" with season 1 episodes 1 and 2 ("The Visit") and season 2 episode 1

#### Scenario: Different shows
- **GIVEN** entries named "Alpha S01E01" and "Beta S01E01"
- **WHEN** the playlist loads
- **THEN** there are two series, "Alpha" and "Beta"

#### Scenario: An episode without a title or marker
- **GIVEN** an entry "Show S01E03" and an entry "Pilot" whose link has a `series` folder
- **WHEN** the playlist loads
- **THEN** the first is "Episode 3" of "Show", and "Pilot" is a series of its own

### Requirement: Playlist series show in Series
The system SHALL list a playlist's series in the Series section with the first episode's logo as the poster and its group as the category. Opening one SHALL show its title page with the seasons and the episode picker, and an episode SHALL play from its link. A series the playlist's last load in this run does not have SHALL make the playlist load once more before the page says its episodes could not load.

#### Scenario: Watching a playlist episode
- **GIVEN** a playlist with episodes of "Show" in the group "Shows"
- **WHEN** the user opens Series, picks "Show" and plays season 1 episode 2
- **THEN** the episode plays from its link

#### Scenario: A playlist with episodes only
- **GIVEN** only a playlist whose entries are episodes
- **WHEN** it loads
- **THEN** Live has no channels from it and Series lists its shows

#### Scenario: A series from an earlier load
- **GIVEN** Series shows "Show" from an earlier load of the playlist, and the load kept in this run does not have it
- **WHEN** the user opens "Show"
- **THEN** the playlist loads again, and the page lists the episodes when the new load has them, or says "Could not load episodes" when it does not

### Requirement: Catch-up style, source and correction
The system SHALL read an entry's `catchup` style, `catchup-source` template and `catchup-correction` hours, and SHALL ignore a correction that is not a number without dropping the channel.

#### Scenario: Full catch-up details
- **GIVEN** an entry with `catchup="shift"`, `catchup-source="?utc={utc}"` and `catchup-correction="-1"`
- **WHEN** it is parsed
- **THEN** the channel has the shift style, that source template and a correction of minus one hour

#### Scenario: A correction that is not a number
- **GIVEN** an entry with `catchup-correction="abc"`
- **WHEN** it is parsed
- **THEN** the channel is kept and has no correction

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

### Requirement: Playlist titles show on every platform
The system SHALL treat a playlist whose last load on this device had movies or episodes like an Xtream source wherever Movies, Series or titles show: the iPhone tab bar, the iPad and Mac sidebar, the Apple TV tab bar, the Movies and Series chips in Search, the "Open on launch" choices, the section the app reopens on, Top Shelf links and Siri.

#### Scenario: iPad sidebar with a playlist
- **GIVEN** an iPad with only a playlist that has movies and episodes
- **WHEN** the playlist has loaded
- **THEN** the sidebar lists Movies and Series, and each opens the playlist's titles

#### Scenario: Searching playlist titles on Apple TV
- **GIVEN** an Apple TV with only a playlist that has the movie "Film A"
- **WHEN** the user searches "film"
- **THEN** "Film A" is a result

#### Scenario: Searching playlist titles on iPhone, iPad and Mac
- **GIVEN** only a playlist that has movies
- **WHEN** the user searches
- **THEN** the Movies and Series chips show beside the others

#### Scenario: Open on launch with a playlist
- **GIVEN** only a playlist whose last load had movies
- **WHEN** the user opens the "Open on launch" choices
- **THEN** Movies is one of them, and choosing it opens Movies at the next launch before the playlist has loaded again

#### Scenario: Top Shelf link to a playlist movie
- **GIVEN** an Apple TV whose Top Shelf shows a playlist movie from Continue watching
- **WHEN** the user selects its tile
- **THEN** the movie plays once the playlist's titles have loaded

#### Scenario: Siri finds a playlist movie
- **GIVEN** only a playlist that has the movie "Film A", and the app not running
- **WHEN** the user asks Siri to play "Film A" in Antenna
- **THEN** the movie is found and plays

### Requirement: Movies and Series show by what the sources offer
The iPad and Mac sidebar and the Apple TV tab bar SHALL show Movies only when a source offers movies, and Series only when a source offers series. An Xtream source SHALL offer both, whether or not it has answered. A playlist SHALL offer movies when its last load had movies and series when it had episodes.

#### Scenario: Mac sidebar with a playlist
- **GIVEN** a Mac with only a playlist that has movies
- **WHEN** the playlist has loaded
- **THEN** the sidebar lists Movies and not Series

#### Scenario: Apple TV with a playlist of episodes only
- **GIVEN** an Apple TV with only a playlist whose on-demand entries are episodes
- **WHEN** it loads
- **THEN** the tab bar shows Series and not Movies, and Series lists the shows

#### Scenario: A playlist that loses its titles
- **GIVEN** a playlist whose movies were removed by its provider, with Movies open
- **WHEN** it loads again with no movies or episodes
- **THEN** Movies and Series leave the tab bar or sidebar and Live shows

### Requirement: What a playlist offered is remembered
The system SHALL remember on the device how many movies and episodes each playlist's last load had, holding no link or login, so the tabs, the sidebar and the launch screen are right before the playlist loads again.

#### Scenario: Reopening on Series
- **GIVEN** an iPad with only a playlist that has episodes, last left on Series
- **WHEN** the app opens again
- **THEN** it opens on Series

#### Scenario: Open on launch with episodes only on Apple TV
- **GIVEN** an Apple TV set to open on Movies, with only a playlist that has episodes
- **WHEN** the app opens
- **THEN** it opens on Series

### Requirement: Season and episode markers
The system SHALL read a season and episode marker in a playlist entry name written as "S01E02" or "s1 e12", as "1x02" or "01x02" with a two- or three-digit episode, or spelled out as "Season 1 Episode 2" or "Season 1, Ep 2", ignoring case. A crossed number with a letter or digit right before or after it, or with a one-digit episode, SHALL NOT be a marker, and neither SHALL an episode number without a season. Every rule that sorts or groups episodes SHALL use the same markers.

#### Scenario: A crossed season and episode
- **GIVEN** an entry named "Show 1x02" linking to an `.mp4` file
- **WHEN** the playlist loads
- **THEN** the entry is season 1 episode 2 of the series "Show", not a movie

#### Scenario: A spelled-out season and episode
- **GIVEN** an entry named "Show Season 1 Episode 2 - The Visit"
- **WHEN** the playlist loads
- **THEN** the entry is season 1 episode 2, "The Visit", of the series "Show"

#### Scenario: Names that only look like a marker
- **GIVEN** an entry named "4x4 Off-Road" linking to an `.mp4` file, and entries named "Comedy 24x7" and "Nature 1920x1080" linking to `.ts` streams
- **WHEN** the playlist loads
- **THEN** the first is a movie and the other two are live channels

#### Scenario: An episode number without a season
- **GIVEN** an entry named "Show Ep 2" linking to an `.mp4` file
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: One show, two ways of writing it
- **GIVEN** entries named "Show S01E01", "Show 1x02" and "Show Season 2 Episode 1"
- **WHEN** the playlist loads
- **THEN** there is one series "Show" with season 1 episodes 1 and 2 and season 2 episode 1
