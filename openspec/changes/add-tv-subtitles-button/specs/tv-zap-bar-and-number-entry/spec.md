## ADDED Requirements

### Requirement: The info bar names the hold
The system SHALL show on the info bar, under the catch-up and browse line, a line with the captions bubble saying that holding select opens info, audio and subtitles, on every channel and while the picture is behind live.

#### Scenario: A channel change
- **GIVEN** a channel playing full screen on Apple TV
- **WHEN** the viewer changes channel and the info bar shows
- **THEN** its footer reads "Hold for info, audio and subtitles" under the catch-up and browse line

#### Scenario: Behind live
- **GIVEN** the viewer paused live TV on a channel that records
- **WHEN** the info bar shows the rewind row
- **THEN** it still reads "Hold for info, audio and subtitles" under "Hold play/pause for live"

#### Scenario: Holding select
- **GIVEN** the info bar shows
- **WHEN** the viewer holds select
- **THEN** the info bar hides and the info panel opens, as it does from the picture alone

## MODIFIED Requirements

### Requirement: Catch-up hint
The system SHALL name the channel's catch-up days in the first line of the bar's footer when the channel offers catch-up, and otherwise SHALL show only the hint to browse channels on that line.

#### Scenario: Catch-up with a number of days
- **GIVEN** the channel offers catch-up for 7 days
- **WHEN** the bar shows
- **THEN** the footer's first line reads "Catch-up 7 days"

#### Scenario: Catch-up without a number
- **GIVEN** the channel offers catch-up and the provider gives no number of days
- **WHEN** the bar shows
- **THEN** the footer's first line reads "Catch-up"

#### Scenario: No catch-up
- **GIVEN** the channel has no catch-up
- **WHEN** the bar shows
- **THEN** the footer's first line only says "Press to browse channels"
