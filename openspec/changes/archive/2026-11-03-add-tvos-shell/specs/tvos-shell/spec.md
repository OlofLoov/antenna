## Purpose

The frame every other Apple TV screen sits in. Opening the app goes straight to the channel last watched, full screen; Menu dims the picture and shows a tab bar along the top, and Menu again goes back to the picture. It serves the living-room viewer who wants "to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable", and the viewer who wants "the app to come back to the channel I was watching".

## ADDED Requirements

### Requirement: The tabs, in order
The system SHALL show a tab bar holding, from left to right, the Antenna mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, with exactly one tab marked as the current one. Movies and Series SHALL appear only when a source offers them.

#### Scenario: Sources with movies
- **GIVEN** the user has sources and at least one offers movies
- **WHEN** the tab bar shows
- **THEN** it holds the mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, in that order, with exactly one tab marked current

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the tab bar shows
- **THEN** it is read as a group of tabs, and the clock and the mark as plain text

### Requirement: Back to the last channel on launch
The system SHALL play the channel last watched on this Apple TV full screen at launch once its source has loaded. If it no longer exists, or its source has not loaded within 10 seconds, the first channel of the first source to load SHALL play instead.

#### Scenario: Last channel available
- **GIVEN** the user watched a channel on this Apple TV before
- **WHEN** they open Antenna and its source has loaded
- **THEN** that channel plays full screen

#### Scenario: Last channel gone or late
- **GIVEN** the last channel no longer exists, or its source has not loaded within 10 seconds
- **WHEN** the user opens Antenna
- **THEN** the first channel of the first source to load plays instead

#### Scenario: Later sources and coming back
- **GIVEN** a channel is already playing
- **WHEN** another source finishes loading, or the app returns from the background
- **THEN** the channel does not change

### Requirement: Menu shows the tab bar over the picture
The system SHALL dim the picture and show the tab bar with Live highlighted when the user presses Menu over a full-screen channel with nothing else on screen, keeping the video playing, or failed.

#### Scenario: Menu over full screen
- **GIVEN** a channel is playing full screen with no overlay, info bar or channel-number box showing
- **WHEN** the user presses Menu
- **THEN** the picture dims and keeps playing (or stays failed), and the tab bar shows with Live highlighted

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the user presses Menu over full screen
- **THEN** the dimming and the tab bar appear without animation

### Requirement: Back to full screen from the tab bar
The system SHALL hide the tab bar and carry on with the same stream full screen when the user presses Menu, swipes down or selects Live from the bar over the dimmed picture. Selecting Live SHALL load a failed stream again.

#### Scenario: Menu, swipe down or Live
- **GIVEN** the tab bar shows over the dimmed picture
- **WHEN** the user presses Menu, swipes down, or selects Live
- **THEN** the tab bar goes away and the same stream carries on full screen

#### Scenario: Failed stream
- **GIVEN** the stream had failed
- **WHEN** the user selects Live
- **THEN** the stream is loaded again

### Requirement: The video pauses behind Movies, Series and Search
The system SHALL pause the video after 30 seconds with Movies, Series or Search open, and SHALL resume it without restarting the channel when the user goes back to Live or Guide.

#### Scenario: Thirty seconds behind a tab
- **GIVEN** Movies, Series or Search is open and a channel is playing behind it
- **WHEN** 30 seconds pass without the user going back to Live or Guide
- **THEN** the video pauses, and resumes without restarting the channel when the user goes back to Live or Guide

### Requirement: Menu from the top of a tab reaches the tab bar
The system SHALL move the highlight to the open tab in the bar, keeping the tab open, when the user presses Menu at the top level of a tab or swipes up from the topmost item on Movies, Series or Search.

#### Scenario: Menu at the top level
- **GIVEN** the user is at the top level of a tab
- **WHEN** they press Menu, or swipe up from the topmost item on Movies, Series or Search
- **THEN** the highlight moves to that tab in the bar, the tab stays open, and on Guide the bar appears over the guide

### Requirement: Menu from the tab bar goes back to Live
The system SHALL open Live full screen when the user presses Menu with the highlight in the bar and another tab open, resuming a paused video without restarting it. Menu SHALL never leave the app from inside the shell.

#### Scenario: Menu from the bar
- **GIVEN** the highlight is in the tab bar and a tab other than Live is open
- **WHEN** the user presses Menu
- **THEN** Live is open full screen, and a video paused behind the tab resumes without restarting

### Requirement: A loading screen at launch
The system SHALL show a loading screen listing each source by name with its progress while no source has finished loading, and Menu SHALL still reach the tab bar and Settings.

#### Scenario: Nothing loaded yet
- **GIVEN** the user has sources and none has finished loading
- **WHEN** they open Antenna
- **THEN** a loading screen lists each source by name with how far it has got, and Menu reaches the tab bar and Settings

#### Scenario: Late password
- **GIVEN** a source whose password or record arrives after launch
- **WHEN** the app returns to the foreground or the user presses Retry
- **THEN** that source loads, and the loading screen never appears while a channel plays

### Requirement: An empty screen with Retry
The system SHALL show a "No channels yet" screen naming each source that added nothing and why, once every source has finished, failed or is waiting for its password without any channels. Retry SHALL load those sources again behind the loading screen.

#### Scenario: Nothing to play
- **GIVEN** every source has finished, failed or is waiting for its password, and none has any channels
- **WHEN** Live is shown
- **THEN** "No channels yet" names each source and why, Retry loads them again and shows the loading screen, and Menu shows the tab bar so the user can reach Settings

#### Scenario: Offline at launch
- **GIVEN** the device is offline at launch
- **WHEN** every source fails
- **THEN** the empty screen shows, with Retry and Settings as the ways on

### Requirement: Open Settings
The system SHALL open Settings over the current screen without touching the video when the user selects the Settings button.

#### Scenario: Settings button
- **GIVEN** the tab bar shows
- **WHEN** the user selects the Settings button
- **THEN** Settings opens over what was there and the video is not touched

### Requirement: Moving along the bar does not switch tabs
The system SHALL keep the current tab while the highlight moves along the bar, until the user selects a tab.

#### Scenario: Highlight on Search
- **GIVEN** the tab bar shows over the dimmed picture with Live highlighted
- **WHEN** the user moves the highlight to Search without pressing select
- **THEN** Live stays the current tab and the picture stays dimmed behind the bar

### Requirement: Other screens can send the user somewhere
The system SHALL let other screens send the user to Search, to the Guide at a given programme, or to Live after tuning, closing the channel overlay first.

#### Scenario: Requests from other screens
- **GIVEN** any tab or the channel overlay is showing
- **WHEN** another screen asks for Search, for the Guide at a given programme, or for Live after tuning
- **THEN** the overlay closes, that tab opens with the Guide told which programme to show, and Live is full screen with no tab bar
