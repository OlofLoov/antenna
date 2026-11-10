# Spec Delta

## Purpose

Gives someone flipping channels on Apple TV a short glance at which channel this is and what is on, lets them step through a group with up and down, and lets a keyboard user jump straight to a channel number.

## ADDED Requirements

### Requirement: The bar appears on every channel change
The system SHALL show the info bar with the new channel and what is on as soon as the channel changes by any means, and SHALL hide it five seconds after the last channel change.

#### Scenario: A channel change
- **GIVEN** a channel is playing with the bar hidden
- **WHEN** the channel changes by any means
- **THEN** the bar shows the new channel and what is on straight away
- **AND** it hides five seconds after the last channel change

#### Scenario: Fast flipping
- **GIVEN** the user changes channel several times quickly
- **WHEN** each change happens
- **THEN** the bar updates in place and hides five seconds after the last change

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the bar or the number box appears
- **THEN** it appears without animation

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the bar appears
- **THEN** the channel, programme and time left are read once

### Requirement: Play/pause shows the bar
The system SHALL show the bar when the user presses play/pause during full-screen live TV, or keep it five more seconds if already showing, while the video keeps playing.

#### Scenario: Play/pause with the bar hidden or showing
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses play/pause
- **THEN** the bar shows, or stays five more seconds if it was already showing
- **AND** the video keeps playing

#### Scenario: A half-typed number
- **GIVEN** the number box shows digits
- **WHEN** the user presses play/pause
- **THEN** the typed digits are dropped first and the bar shows

### Requirement: Menu hides the bar
The system SHALL hide the bar on Menu, keep the video playing full screen, and SHALL NOT also take the user out of the player.

#### Scenario: Menu with the bar showing
- **GIVEN** the bar is showing
- **WHEN** the user presses Menu
- **THEN** the bar hides and the video keeps playing full screen
- **AND** the press does not also take the user out of the player

#### Scenario: Select with the bar showing
- **GIVEN** the bar is showing
- **WHEN** the user presses select
- **THEN** the bar hides and the channel overlay opens

### Requirement: Which channel this is
The system SHALL show in the bar the channel's logo or initials, number, name, and the current group with the channel's position in it, naming Favorites or All channels when that is the current list.

#### Scenario: A channel in a group
- **GIVEN** channel 104 "Sport One" is the fourth of 42 in the group Sport
- **WHEN** the bar shows
- **THEN** it shows the logo (or initials), "104", "Sport One" and "Sport · 4 of 42"

#### Scenario: Favorites or All channels
- **GIVEN** the current list is Favorites or All channels
- **WHEN** the bar shows
- **THEN** it names that list in place of the group

#### Scenario: Tuned outside the current group
- **GIVEN** the user tuned by number, search, guide or onboarding to a channel outside the current group, or the playing channel left its group after a refresh
- **WHEN** the bar shows
- **THEN** it counts the channel within All channels

### Requirement: What is on and what is next
The system SHALL show in the bar the current programme's title, times and progress, the next programme's time and title, and time left, and SHALL show the guide grid's wording with no progress when there is no current programme, the guide is loading, or it failed.

#### Scenario: A programme on now
- **GIVEN** the guide has a programme on now for the channel
- **WHEN** the bar shows
- **THEN** it shows the programme's title, start and end times, how far in it is, and the next programme's time and title
- **AND** time left reads like "26 min left" or "1 h 34 min left", or "Ends now" in its last minute

#### Scenario: No programme, loading or failed
- **GIVEN** the guide has nothing for now, is still loading, or failed
- **WHEN** the bar shows
- **THEN** the bar reads "No programme information", "Loading guide…" or "Guide unavailable"
- **AND** it shows no progress or next programme

#### Scenario: A programme ends while the bar shows
- **GIVEN** the bar is showing a programme
- **WHEN** that programme ends
- **THEN** the bar moves on to the next one

### Requirement: Picture and sound quality
The system SHALL show a LIVE badge only while the stream plays and, once the player reports them, the picture size and the sound format, and SHALL show none of these while buffering or after a failure.

#### Scenario: A playing stream
- **GIVEN** a channel is playing
- **WHEN** the bar shows
- **THEN** a LIVE badge shows
- **AND** once the player reports them, the picture size (4K, 1080p, 720p) and the sound (for example "AAC 5.1") show

#### Scenario: Buffering or failed
- **GIVEN** the stream is buffering or has failed
- **WHEN** the bar shows
- **THEN** it still shows the channel and programme
- **AND** the LIVE and quality badges are absent

### Requirement: Catch-up hint
The system SHALL name the channel's catch-up days in the bar's footer when the channel offers catch-up, and otherwise SHALL show only the hint to browse channels.

#### Scenario: Catch-up with a number of days
- **GIVEN** the channel offers catch-up for 7 days
- **WHEN** the bar shows
- **THEN** the footer reads "Catch-up 7 days"

#### Scenario: Catch-up without a number
- **GIVEN** the channel offers catch-up and the provider gives no number of days
- **WHEN** the bar shows
- **THEN** the footer reads "Catch-up"

#### Scenario: No catch-up
- **GIVEN** the channel has no catch-up
- **WHEN** the bar shows
- **THEN** the footer only says "Press to browse channels"

### Requirement: Swipe up and down to change channel
The system SHALL move to the next or previous channel in the current group when the user swipes up or down, wrapping round at either end.

#### Scenario: Swiping up
- **GIVEN** the fourth of 42 channels in the current group is playing
- **WHEN** the user swipes up
- **THEN** the fifth channel plays and the bar reads "5 of 42"

#### Scenario: Wrapping round
- **GIVEN** the last channel in the group is playing
- **WHEN** the user swipes past the end
- **THEN** the first channel in the group plays

#### Scenario: A group with one channel
- **GIVEN** the current group has one channel
- **WHEN** the user swipes
- **THEN** the bar shows again for the same channel

#### Scenario: Swiping while loading or typing
- **GIVEN** a channel is still loading, or the number box shows
- **WHEN** the user swipes
- **THEN** a loading channel is skipped straight to the next one, and an open number box closes first

### Requirement: Typing a number shows the match
The system SHALL hide the bar when the user types a digit on a hardware keyboard and show a small box with the digits typed and the name of the matching channel, while the video keeps playing.

#### Scenario: Typing a digit
- **GIVEN** a channel is playing and a hardware keyboard is connected
- **WHEN** the user types a digit
- **THEN** the bar hides
- **AND** a small box shows the digits typed and the name of the channel they match, blank when nothing matches
- **AND** the video keeps playing

#### Scenario: Overlay or guide open
- **GIVEN** the channel overlay or the guide is open
- **WHEN** the user types digits
- **THEN** nothing happens

### Requirement: The typed channel tunes
The system SHALL tune to the typed channel two seconds after the last digit, or at once on Return or select, close the box and show the bar for the new channel.

#### Scenario: A matching number
- **GIVEN** the box shows "104" and channel 104 exists
- **WHEN** two seconds pass without another digit, or the user presses Return or select
- **THEN** channel 104 plays, the box goes away, and the bar shows the new channel

#### Scenario: Leading zeros
- **GIVEN** the user typed "0104"
- **WHEN** the number is used
- **THEN** it finds channel 104

### Requirement: No channel with that number
The system SHALL show "No channel" with the typed number for one second when no channel matches, then close the box and keep the same channel playing.

#### Scenario: No match
- **GIVEN** the box shows "999" and no channel has that number
- **WHEN** two seconds pass or the user presses Return or select
- **THEN** the box reads "No channel 999" for a second and goes away
- **AND** the same channel keeps playing

#### Scenario: No channels at all
- **GIVEN** the user has no channels
- **WHEN** they type a number n
- **THEN** it ends as "No channel n"

### Requirement: Correct or cancel a number
The system SHALL remove the last digit on Backspace and give two more seconds, close an emptied box, and close the box without tuning or leaving the player on Menu or Escape.

#### Scenario: Backspace
- **GIVEN** the box shows "10"
- **WHEN** the user presses Backspace
- **THEN** the last digit is removed and the user gets two more seconds
- **AND** a box left empty goes away

#### Scenario: Menu or Escape
- **GIVEN** the box shows digits
- **WHEN** the user presses Menu or Escape
- **THEN** the box closes without tuning or leaving the player
