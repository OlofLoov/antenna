# Spec Delta

## Purpose

Gives anyone with more channels and titles than they can scroll through one field that finds a channel by name or number, a programme now or in the coming week, and a movie or series, and plays or opens what they pick.

## ADDED Requirements

### Requirement: Find things the way you type them
The system SHALL match a query against channel names and groups, programme titles and movie and series titles ignoring case and accents, SHALL require every word to appear in the same field, and SHALL say when a channel matched only by its group.

#### Scenario: Case and accents
- **GIVEN** channels "Northern News" and "Nordic One" (group "Northern Report"), a programme "True North" and a movie "Northbound"
- **WHEN** the user types "north" or "NÖRTH"
- **THEN** all four are found

#### Scenario: Every word in the same name
- **GIVEN** the same channels, programme and movie
- **WHEN** the user types "north news"
- **THEN** only "Northern News" is found

#### Scenario: Matched by group
- **GIVEN** a channel found only by its group
- **WHEN** its result shows
- **THEN** it says "Matches" and the group's name

#### Scenario: A single letter
- **GIVEN** the field is empty
- **WHEN** the user types one letter
- **THEN** no results show yet

#### Scenario: Duplicate names across sources
- **GIVEN** two sources have a channel with the same name or number
- **WHEN** a search matches them
- **THEN** both show

### Requirement: Find a channel by its number
The system SHALL find channels whose number starts with typed digits, ignoring leading zeros, and SHALL match digits against titles as text.

#### Scenario: Digits that match a title and a number
- **GIVEN** channel 104, a movie "1917" and a programme titled "104"
- **WHEN** the user types "19"
- **THEN** the movie "1917" is found and channel 104 is not

#### Scenario: A channel number
- **GIVEN** the same channel, movie and programme
- **WHEN** the user types "104"
- **THEN** channel 104 and every channel whose number starts with 104 are found, ignoring leading zeros
- **AND** the programme "104" is found by its title

### Requirement: Results grouped, best first
The system SHALL show results under Channels, In the guide, and Movies & series in that order, each with its count, leave out empty sections, put names starting with the query first, order programmes by start, and highlight the matched letters.

#### Scenario: Results of every kind
- **GIVEN** results of every kind
- **WHEN** the user looks at them
- **THEN** they appear under Channels, In the guide, and Movies & series, in that order, each with its count, and a section with nothing in it is left out
- **AND** channels whose names start with what was typed come first, programmes run in start order so what is on now leads, and titles starting with what was typed come first
- **AND** the matched letters are highlighted in every row

#### Scenario: The same programme on two channels
- **GIVEN** a programme on air on one channel and later on another
- **WHEN** it is found
- **THEN** it shows twice, on-air first

#### Scenario: Large text and VoiceOver
- **GIVEN** a large text size or VoiceOver
- **WHEN** results show
- **THEN** rows grow and highlights follow the text
- **AND** VoiceOver reads section headers as headings and each result as its section, name and second line

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user searches
- **THEN** search covers everything already loaded, and missing logos and posters get their stand-ins

### Requirement: Pick a channel or title to watch
The system SHALL play a picked channel full screen on Apple TV and in Live elsewhere, switching to All channels when it is outside the current group and keeping the search for later, and SHALL play a picked movie or series as the Movies section does.

#### Scenario: Picking a channel
- **GIVEN** a channel in the results
- **WHEN** the user picks it
- **THEN** it starts playing, full screen on Apple TV and in Live elsewhere
- **AND** the current group becomes All channels if the channel is not in it
- **AND** the search is kept for when the user comes back

#### Scenario: Picking a movie or series
- **GIVEN** a movie or series in the results
- **WHEN** the user picks it
- **THEN** it plays as it does from the Movies or Series section

### Requirement: Pick a programme
The system SHALL play the channel of a picked programme that is on now and open the guide at a picked later programme on every device. Watching a later programme from there on iPhone, iPad or Mac SHALL play its channel and show the programme as "Later" under what is on next until the channel changes or the programme ends.

#### Scenario: A programme on now
- **GIVEN** a programme on now in the results
- **WHEN** the user picks it
- **THEN** its channel plays as when picking a channel

#### Scenario: A later programme
- **GIVEN** a later programme in the results on any device
- **WHEN** the user picks it
- **THEN** the guide opens at that programme with its details showing

#### Scenario: Watching a later programme from the guide
- **GIVEN** the guide opened at a later programme from Search on iPhone, iPad or Mac
- **WHEN** the user taps Watch
- **THEN** its channel plays in Live and the programme shows as "Later" with its day, time and title beneath what is on next
- **AND** the line stays until the user changes channel or the programme ends

### Requirement: Narrow to one kind
The system SHALL show only one kind of result when the user taps its chip on iPad, Mac or iPhone, listing every guide match, with counts on each chip and a total on All, a grayed-out "0" chip when empty, and Movies and Series chips only when those sections exist.

#### Scenario: Tapping a chip
- **GIVEN** results on iPad, Mac or iPhone
- **WHEN** the user taps the Channels, Guide, Movies or Series chip
- **THEN** only that kind of result shows, with every guide match listed
- **AND** each chip shows its count and All shows the total

#### Scenario: An empty chip and All
- **GIVEN** a kind with no results
- **WHEN** the chips show
- **THEN** its chip is grayed out and reads "0"
- **AND** All brings every section back

#### Scenario: No movies or series
- **GIVEN** the user has no Movies or Series sections
- **WHEN** the chips show
- **THEN** there are no Movies or Series chips

### Requirement: Recent searches
The system SHALL remember a search when the user picks one of its results, list the ten latest newest first with case-only differences merged, show them with an empty field on iPhone and Apple TV and at all times on iPad and Mac, and run a recent search again when picked.

#### Scenario: More than ten searches
- **GIVEN** the user has searched and picked a result more than ten times
- **WHEN** the field is empty on iPhone or Apple TV, or at any time on iPad and Mac
- **THEN** the ten latest searches are listed newest first, with searches that differ only in case listed once

#### Scenario: Picking a recent search
- **GIVEN** recent searches are listed
- **WHEN** the user picks one
- **THEN** it runs again

### Requirement: Clear the field
The system SHALL empty the field and keep it ready for typing when the user taps clear on iPhone, iPad or Mac, and iPhone SHALL show recent searches again.

#### Scenario: Tapping clear
- **GIVEN** a search with results on iPhone, iPad or Mac
- **WHEN** the user taps clear
- **THEN** the field empties and stays ready for typing
- **AND** iPhone shows recent searches again

### Requirement: Nothing found
The system SHALL tell the user nothing was found for their query, with a hint, when a search finds nothing after every source has loaded, and SHALL say when sources are still loading.

#### Scenario: No results
- **GIVEN** a search that finds nothing after every source has loaded
- **WHEN** the user looks at the results
- **THEN** they read "No results for “<query>”" with the hint "Check the spelling or try a channel number."

#### Scenario: Sources still loading
- **GIVEN** no source has loaded, or some have not, or the guide is loading
- **WHEN** the user searches
- **THEN** Search says "Channels are still loading", or the no-results message adds "Some sources are still loading.", or the guide section says it is loading

#### Scenario: A source finishes loading
- **GIVEN** Search is open
- **WHEN** a source or its guide finishes loading
- **THEN** the next keystroke includes it

#### Scenario: A source without its login
- **GIVEN** a source's login has not reached this device
- **WHEN** the user searches
- **THEN** it adds no channels or titles

### Requirement: Seven days of guide
The system SHALL find only programmes on now or starting within seven days, each marked "NOW" or with its day and start time, its channel, and a catch-up mark when the provider offers catch-up.

#### Scenario: Programmes in and out of range
- **GIVEN** programmes that have ended, programmes in the next seven days, and programmes further out
- **WHEN** the user searches for them
- **THEN** only programmes on now or starting within seven days are found
- **AND** each is marked "NOW" or with its day and start time, its channel, and a catch-up mark when the provider offers catch-up

#### Scenario: A programme starts or ends
- **GIVEN** results are open
- **WHEN** a programme starts or ends
- **THEN** its result updates within a few seconds

### Requirement: Search with a keyboard
The system SHALL put the cursor in the field on Command-F, move into and between results with the arrows, pick the focused result on Return, and on Escape clear the field, or move to recent searches when it is empty.

#### Scenario: Keys on Mac or iPad
- **GIVEN** a Mac, or an iPad with a keyboard
- **WHEN** the user presses Command-F, the arrow keys, Return or Escape
- **THEN** Command-F puts the cursor in the field
- **AND** the down arrow moves into the results and the arrows move between them
- **AND** Return picks the focused result
- **AND** Escape clears the field, or with an empty field moves to the recent searches

### Requirement: Very long result lists
The system SHALL cap the Channels section in the All view with a note giving how many are shown of the total, keep the full count in its header, and show the first few guide matches with "See all", while Apple TV lists every programme.

#### Scenario: 600 channels and many programmes
- **GIVEN** a search with 600 matching channels and more than four matching programmes
- **WHEN** the user looks at the results in the All view
- **THEN** Channels lists the first several hundred and ends with "Showing <shown> of <total>" while its count shows the total
- **AND** In the guide shows the first few with "See all n", which lists the rest in place

#### Scenario: Apple TV
- **GIVEN** the same search on Apple TV
- **WHEN** the results show
- **THEN** every programme is listed
