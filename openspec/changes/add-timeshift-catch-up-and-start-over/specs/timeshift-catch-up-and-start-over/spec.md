# Spec Delta

## Purpose

Lets anyone, sports fans most of all, pause live TV, rewind up to an hour, scan, and jump back to live, and start the programme on now from its beginning through the provider's catch-up or the app's own recording.

## ADDED Requirements

### Requirement: Catch-up asks the provider the way it expects
The system SHALL request a programme's start and length in the channel's catch-up style, in the provider's time zone where given, and SHALL request nothing when details are missing, malformed, beyond the kept days, or the login or time zone is not yet known.

#### Scenario: Each supported style
- **GIVEN** channels with each supported catch-up style (default, append, shift, flussonic, xc, Xtream archive)
- **WHEN** Start over plays catch-up for the current programme
- **THEN** the app requests the programme's start and length in that style, in the provider's time zone where it gives one

#### Scenario: Details missing or unknown
- **GIVEN** catch-up details that are missing, malformed or out of the kept days, or a login or time zone not yet known
- **WHEN** Start over is chosen
- **THEN** no catch-up request is made and Start over falls back to the buffer

#### Scenario: A provider in another time zone
- **GIVEN** an M3U `xc` channel from a provider in another time zone without a correction in the playlist
- **WHEN** catch-up plays
- **THEN** it plays the wrong hour, and a correction in the playlist puts it right

#### Scenario: Daylight saving
- **GIVEN** a programme across a daylight saving change
- **WHEN** its catch-up address is built
- **THEN** times stay absolute and date parts use the named zone

### Requirement: Pause live TV and pick up where you left off
The system SHALL freeze the picture on pause while recording continues, show the paused time, how far behind live it is and a marker between the buffer's start and now, and continue from the frozen frame on play with no reload.

#### Scenario: Pause and play
- **GIVEN** a live channel playing at now on a stream that can be recorded
- **WHEN** the user presses pause (remote, on-screen button or lock-screen control), waits, and presses play
- **THEN** the picture freezes while recording goes on
- **AND** the bar or strip shows the paused time, "<n> min behind" rounded up, and a marker between the start of the buffer and now, visible while paused
- **AND** play continues from the frozen frame with no reload

#### Scenario: The programme shown
- **GIVEN** the picture is paused or playing behind live
- **WHEN** the bar or strip shows a programme
- **THEN** it is the one at the picture's time

#### Scenario: Recording stalls
- **GIVEN** the source stalls or goes offline while recording
- **WHEN** data returns
- **THEN** the gap shows on the scrubber and recording resumes without a new buffer

#### Scenario: Pause during catch-up
- **GIVEN** a catch-up programme is playing
- **WHEN** the user pauses and plays
- **THEN** the catch-up stream pauses and resumes, with no buffer and no notice

#### Scenario: The overlay over a pause
- **GIVEN** the user paused live TV on Apple TV
- **WHEN** they open the overlay, or another screen comes and goes
- **THEN** the pause stays

### Requirement: Skip, scan and drag
The system SHALL skip 15 seconds back or 30 forward on a click, tap or arrow key, scan at 60 times real time while held, seek once when a hold or drag ends, never go before the buffer's start, and return to live on reaching now.

#### Scenario: Clicks, holds, taps and drags
- **GIVEN** a channel playing ten minutes behind live
- **WHEN** the user clicks left or right on the Apple TV remote, holds left or right, taps the skip buttons, drags the marker, or presses the arrow keys with the player focused
- **THEN** a click or tap moves 15 seconds back or 30 forward
- **AND** holding scans at 60 times real time and seeks once on release
- **AND** dragging moves the shown time with the finger and seeks once on release
- **AND** nothing goes before the start of the buffer, and reaching now returns to live

#### Scenario: Other screens on Apple TV
- **GIVEN** the overlay, number entry or guide is open on Apple TV
- **WHEN** the user clicks left or right
- **THEN** left and right keep their usual meaning

#### Scenario: VoiceOver on the scrubber
- **GIVEN** VoiceOver is on, on iPhone, iPad or Mac
- **WHEN** the user reaches the scrubber
- **THEN** it is read as an adjustable control with the time and "behind" text, and swiping up and down skips

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the marker moves or a notice appears
- **THEN** the marker jumps instead of sliding and notices appear without animation

### Requirement: Back to live
The system SHALL return to live when the user holds play/pause for half a second on Apple TV, taps LIVE elsewhere, or reaches now, and SHALL reload the live channel with a new buffer when leaving catch-up.

#### Scenario: Going live
- **GIVEN** a channel playing or paused behind live, or a catch-up programme playing
- **WHEN** the user holds play/pause for half a second on Apple TV, taps the LIVE badge elsewhere, or skips, scans or drags to now
- **THEN** the picture is live, the LIVE badge shows its red dot and the "behind" text is gone
- **AND** from catch-up the live channel reloads with a new buffer

#### Scenario: Behind live
- **GIVEN** a channel is playing behind live
- **WHEN** the controls show
- **THEN** the Apple TV zap bar hint reads "Hold play/pause for live", and the LIVE badge elsewhere can be tapped

### Requirement: When the buffer runs out
The system SHALL resume from the earliest kept point, with the marker at the left end and a notice, when a pause outlasts the hour or the storage cap pushes the buffer's start up to the paused point.

#### Scenario: Buffer full
- **GIVEN** a channel paused or playing behind live
- **WHEN** the pause outlasts the hour, or the storage cap pushes the start of the buffer up to the paused point
- **THEN** playback resumes from the earliest point still kept and the marker sits at the left end
- **AND** a notice says "Buffer full. Playing from the earliest point"

### Requirement: Start over shows only when it can work
The system SHALL show Start over for the playing channel's programme on now when a catch-up address can be built or the buffer reaches its start, hide it otherwise and for other channels, and update it within five seconds of a change.

#### Scenario: When Start over appears
- **GIVEN** the Apple TV overlay focused on the playing channel, or the touch control strip, and a programme on air now
- **WHEN** it is shown
- **THEN** Start over appears when a catch-up address can be built or the buffer reaches back to the programme's start

#### Scenario: When it is absent
- **GIVEN** no programme, no catch-up and too short a buffer, or a channel other than the one playing
- **WHEN** the overlay or strip shows
- **THEN** Start over is absent

#### Scenario: Something changes
- **GIVEN** Start over is shown or hidden
- **WHEN** the buffer, the programme, the login or the server time zone changes
- **THEN** it appears or disappears within five seconds

#### Scenario: No guide data
- **GIVEN** the channel has no guide data
- **WHEN** the bar shows
- **THEN** Start over is absent and the bar shows the zap bar's guide-missing text

### Requirement: Start the programme from the beginning
The system SHALL play the catch-up address with a CATCH-UP badge when catch-up is available, reloading it on skips and dropping the live buffer once it plays, otherwise jump the buffer to the programme's start, and SHALL return to live at the end or on a skip past now.

#### Scenario: With catch-up
- **GIVEN** Start over shown for programme P on a channel with catch-up
- **WHEN** the user selects it
- **THEN** the catch-up address plays and the bar shows a "CATCH-UP" badge and P's start time moving on
- **AND** skips reload the catch-up address at the new time
- **AND** the live buffer is dropped once catch-up plays

#### Scenario: Without catch-up
- **GIVEN** Start over shown for programme P on a channel without catch-up
- **WHEN** the user selects it
- **THEN** the buffer jumps to P's start with no reload

#### Scenario: The end of catch-up
- **GIVEN** catch-up is playing
- **WHEN** the stream ends, or the user skips past now
- **THEN** it returns to live by itself

#### Scenario: A slow catch-up start
- **GIVEN** the catch-up stream is slow to start
- **WHEN** the user waits
- **THEN** the CATCH-UP badge shows at the programme start with the player's spinner, and the live buffer is kept until catch-up plays

#### Scenario: Skipping back past the start
- **GIVEN** catch-up is playing
- **WHEN** the user skips back past the programme's start
- **THEN** playback lands on its start

### Requirement: When the provider's catch-up fails
The system SHALL bring back the live channel with its buffer when the catch-up stream fails to start, at the programme's start if the buffer holds it, otherwise saying Start over is not available.

#### Scenario: Catch-up fails with the start in the buffer
- **GIVEN** Start over through catch-up for programme P and the buffer reaches P's start
- **WHEN** the catch-up stream fails to start
- **THEN** the live channel returns with its buffer, at P's start

#### Scenario: Catch-up fails without the start in the buffer
- **GIVEN** Start over through catch-up for programme P and the buffer does not reach P's start
- **WHEN** the catch-up stream fails to start
- **THEN** the live channel returns with its buffer, saying "Start over isn't available for this programme"

### Requirement: Changing channel starts fresh
The system SHALL play a newly tuned channel at live with its own new buffer, delete the old buffer without slowing the change, and delete buffers left from an earlier run at launch without reading them.

#### Scenario: Changing channel
- **GIVEN** a channel paused or playing behind live
- **WHEN** the user changes channel by any means
- **THEN** the new channel plays at live with its own new buffer
- **AND** the old buffer is deleted without slowing the change

#### Scenario: Launch
- **GIVEN** buffers left over from an earlier run of the app
- **WHEN** the app launches
- **THEN** they are deleted without being read

#### Scenario: Trying a failed channel again
- **GIVEN** a channel failed
- **WHEN** the user tries it again
- **THEN** its buffer is kept

### Requirement: Leaving the app, calls and other interruptions
The system SHALL keep the place of a pause the user made through backgrounding, calls, sleep or other tabs, jump to live past a recording gap with a notice, return a channel that was at live to live with a fresh buffer, and continue a channel the user chose to watch behind live.

#### Scenario: A user pause across an interruption
- **GIVEN** the user paused a channel
- **WHEN** the app goes to the background without Picture in Picture or background audio, a call or Siri interrupts, the Mac sleeps, or another tab pauses playback
- **THEN** the pause keeps its place
- **AND** if the recording has a gap, the picture plays to the gap and then jumps to live with "Skipped ahead to live"

#### Scenario: A channel at live
- **GIVEN** a channel was playing at live
- **WHEN** an interruption ends
- **THEN** it comes back at live with a fresh buffer and no notice

#### Scenario: A channel behind live by choice
- **GIVEN** the user was watching behind live
- **WHEN** an interruption ends
- **THEN** it continues from where it was

#### Scenario: Recording keeps going
- **GIVEN** Picture in Picture or background audio is on, or a Mac window is only hidden
- **WHEN** the user leaves
- **THEN** recording just continues

#### Scenario: Other screens never resume
- **GIVEN** the user paused
- **WHEN** they move between tabs, the guide or the overlay
- **THEN** none of them resumes the pause

### Requirement: When the stream cannot be recorded
The system SHALL still freeze the picture on pause and return to live on play when a stream cannot be recorded, say once when storage is too short, return to live with a notice when recording fails partway, and have VoiceOver read every notice.

#### Scenario: Cannot record
- **GIVEN** a stream that cannot be recorded, or a device with too little free storage at tune time
- **WHEN** the user presses pause and then play
- **THEN** pause freezes the picture and play returns to live with no rewind row
- **AND** the first pause on a short device says "Not enough free storage to rewind live TV"

#### Scenario: A failure partway
- **GIVEN** a recording fails to write or read partway
- **WHEN** the failure happens
- **THEN** playback returns to live without stopping and says once "Storage is full. Back to live TV" or "Rewind stopped working. Back to live TV"
- **AND** the "Back to live TV" part is left out when already live

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** any notice appears
- **THEN** it is read aloud

### Requirement: Logins stay private
The system SHALL keep the username, password, catch-up template and stream and catch-up addresses out of every notice, label, identifier and log line, and SHALL keep the template, login, server time zone and hour correction out of every saved iCloud record.

#### Scenario: Playing and logging
- **GIVEN** an Xtream catch-up address, an M3U `xc` stream address and a catch-up template that all contain a username and password
- **WHEN** the app plays catch-up or live, shows a notice, sets an accessibility value or writes a log line
- **THEN** no notice, label, identifier or log line contains the username, password, template or either address
- **AND** logs carry only the redacted address, source id and error name

#### Scenario: Saved records
- **GIVEN** the same channels have played
- **WHEN** every saved iCloud record is read
- **THEN** none holds the template, the login, the Xtream server time zone or the hour correction
