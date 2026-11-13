# app-intents Specification

## Purpose
Lets people who know what they want to watch tune a channel, play a title, open Search or change a favorite from Siri and Shortcuts on iPhone, iPad and Mac, without opening Antenna and browsing for it.

## Requirements

### Requirement: Shortcuts never hold a password
The system SHALL keep usernames, passwords and stream links out of every reference Shortcuts saves, every description of a channel or title, and every reply or failure an action gives.

#### Scenario: Sources with logins in their links
- **GIVEN** sources whose stream links, Xtream logins or even saved names contain a username and password
- **WHEN** the user picks one of their channels in Shortcuts, Siri describes it, or an action replies or fails
- **THEN** no reference saved in the user's library, no description and no reply contains the username, password or stream link
- **AND** a source named with a link is called "your source"

### Requirement: Ask for a channel by name or number
The system SHALL find the user's channels by name, ignoring case and accents, or by channel number, and ask "Which channel?" when nothing matches.

#### Scenario: Name or number
- **GIVEN** the user's channels
- **WHEN** they ask for a channel by name, in any case or with or without accents, or by its number
- **THEN** matching channels are offered, a single exact name match is used without a question, and a number finds channel numbers rather than names

#### Scenario: No match
- **WHEN** the user asks for a channel that matches nothing
- **THEN** Siri asks "Which channel?"

#### Scenario: A channel beyond the suggestions
- **GIVEN** a channel outside the suggested list
- **WHEN** the user types its name in Shortcuts or answers Siri's follow-up question
- **THEN** it is found

### Requirement: Siri asks which when two channels match
The system SHALL offer every channel that matches equally, each described so the user can tell them apart, and play the one the user chooses.

#### Scenario: Two Sport Ones
- **GIVEN** two sources each have a channel called Sport One, or a channel with the same number
- **WHEN** the user asks for it
- **THEN** Siri offers both, each described with its number, group and source, and plays the one they choose

### Requirement: Shortcuts suggests what you watch
The system SHALL suggest channels starting with the user's favorites and titles starting with those in progress, then My list, leaving out locked, hidden and missing items.

#### Scenario: Suggestions appear
- **GIVEN** the user is choosing a channel or a title in Shortcuts while Antenna has its library loaded
- **WHEN** the list of suggestions appears
- **THEN** channels start with the user's favorites in their order, followed by the other channels
- **AND** titles show those in progress, then My list, each once
- **AND** locked and hidden channels and titles that no longer exist are left out

### Requirement: Tune a channel by voice or shortcut
The system SHALL bring Antenna forward on Live with the requested channel highlighted and playing, and tune nothing when the system will not bring Antenna forward.

#### Scenario: Tune from anywhere
- **GIVEN** the user is unlocked with a source and asks for a channel that is available
- **WHEN** Siri or a shortcut runs "Tune Channel", with Antenna closed, in the background or already open
- **THEN** Antenna comes forward on Live with the channel highlighted and playing, switching to All channels if needed

#### Scenario: The system refuses to bring Antenna forward
- **WHEN** the system will not bring Antenna forward
- **THEN** nothing is tuned

#### Scenario: Before the first unlock after a restart
- **GIVEN** the device has restarted and not been unlocked yet
- **WHEN** the user tunes a channel or plays a title
- **THEN** the request works once Antenna comes forward

#### Scenario: Offline with the library loaded
- **GIVEN** Antenna is running offline with its library loaded
- **WHEN** the user tunes a channel
- **THEN** the request is matched and tuned, and playback then fails as the player does for offline

#### Scenario: A renamed channel
- **GIVEN** a saved shortcut for a channel the provider has since renamed
- **WHEN** the shortcut runs
- **THEN** it tunes that channel and shows its new name

### Requirement: Change a favorite without opening the app
The system SHALL add, remove or toggle a favorite for the playing or named channel while Antenna stays in the background, and reply with what it did.

#### Scenario: Add, remove or toggle
- **GIVEN** a channel is playing in Antenna, or the user names one
- **WHEN** they say "Add this channel to favorites in Antenna" or "Remove this channel from favorites in Antenna", or run Toggle Favorite
- **THEN** Add adds it at the end of Favorites, Remove removes it with any duplicates, and Toggle Favorite does whichever applies
- **AND** Siri replies "Added <channel> to favorites.", "Removed <channel> from favorites.", "<channel> is already a favorite." or "<channel> isn't a favorite."
- **AND** the app stays in the background

#### Scenario: Nothing playing
- **GIVEN** nothing is playing and no channel is named
- **WHEN** the user asks to change a favorite
- **THEN** Siri replies "Antenna isn't playing a channel right now. Say which channel instead."

#### Scenario: Before the first unlock after a restart
- **GIVEN** the device has restarted and not been unlocked yet
- **WHEN** the user changes a favorite
- **THEN** the reply asks the user to unlock once and try again

### Requirement: Play a movie or series
The system SHALL bring Antenna forward and resume the requested movie where it was left, or open the requested series on its next episode.

#### Scenario: Play by name
- **GIVEN** a movie or series from the user's sources
- **WHEN** they say "Play <title> in Antenna" or run "Play Title"
- **THEN** Antenna comes forward and the movie resumes where it was left, or the series opens on the episode series browsing picks

#### Scenario: Two Xtream sources on one host
- **GIVEN** two Xtream sources on the same host with a title of the same name
- **WHEN** the user picks one
- **THEN** the titles stay separate and the chosen source's title plays

### Requirement: Open Search
The system SHALL open Antenna on Search, with the given query typed and results showing, or with an empty field focused and recent searches listed.

#### Scenario: With or without a query
- **GIVEN** the user is unlocked with a source
- **WHEN** they say "Search Antenna" or run "Open Search" with or without a query
- **THEN** Antenna opens on Search, either with the query typed and results showing straight away, or with an empty field focused and recent searches listed
- **AND** a query of only spaces counts as none

### Requirement: Nothing works until Antenna is unlocked and set up
The system SHALL refuse every action, changing and opening nothing, while Antenna is not unlocked on the device or has no sources, and say which in a plain reply.

#### Scenario: Not unlocked or no sources
- **GIVEN** Antenna is not unlocked on this device, or has no sources
- **WHEN** any action runs, even when the system starts Antenna in the background to run it
- **THEN** it changes and opens nothing and replies "Antenna isn't unlocked on this device yet. Open Antenna to continue." or "Antenna has no sources yet. Open Antenna to add one."

#### Scenario: Sources not yet downloaded
- **GIVEN** sources synced through iCloud but not yet downloaded to this device
- **WHEN** any action runs
- **THEN** it treats the device as having no sources, until Antenna is opened

### Requirement: A clear reply when a channel or title cannot play
The system SHALL refuse a request for a channel or title it cannot reach, opening and changing nothing, and say why in one plain sentence naming the source or channel.

#### Scenario: Unreachable item
- **GIVEN** the channel or title the user asked for cannot be reached because its login has not synced to this device, the device is offline and Antenna has not loaded that source, the source is still loading or failed, the channel is in a locked group, or the channel, title or source is gone
- **WHEN** the action runs
- **THEN** it opens nothing and changes nothing, and Siri or Shortcuts says which in one plain sentence naming the source or channel, never a link, code or technical error

#### Scenario: The item comes back
- **GIVEN** a shortcut that names a missing channel or title, or a source whose login arrives after a failure
- **WHEN** the item or login comes back and the shortcut runs again
- **THEN** it succeeds

#### Scenario: A large source in the background
- **GIVEN** a source too large to load within 10 seconds in the background
- **WHEN** an action names one of its channels
- **THEN** it replies that Antenna is still loading until Antenna has loaded the source once

#### Scenario: A source deleted and added again
- **GIVEN** a shortcut that stored channels from a source that was later deleted and added again
- **WHEN** the shortcut runs
- **THEN** it replies that the channel's source is gone, and the user picks the channels again

### Requirement: Apple TV ships no actions
The system SHALL ship none of these actions or Siri phrases in the Apple TV app.

#### Scenario: Build the Apple TV app
- **GIVEN** the Apple TV app
- **WHEN** it is built
- **THEN** it contains none of these actions or phrases, so Siri on Apple TV offers nothing for Antenna

### Requirement: Shortcuts on the Mac
The system SHALL offer the four actions in the Shortcuts app on a Mac, bringing Antenna forward for tune, play and search, and changing a favorite only while a channel plays.

#### Scenario: Run each action on a Mac
- **GIVEN** a Mac with Antenna unlocked and one source
- **WHEN** the user runs Tune Channel, Play Title, Open Search and Toggle Favorite from the Shortcuts app, first with Antenna closed and then with a channel playing
- **THEN** the first three bring Antenna forward to the channel, title or Search
- **AND** Toggle Favorite says nothing is playing while Antenna is closed, and changes the favorite without bringing Antenna forward while a channel plays
