## ADDED Requirements

### Requirement: Report a failed stream
The system SHALL offer "Report this problem" on the error screen of a channel, movie or episode on every platform, next to Try again, opening the Report a problem form with the topic set to Playback and the error as the last playback error, and SHALL return to the error screen when the form closes.

#### Scenario: From a failed channel
- **GIVEN** the error screen for a channel that returned 404
- **WHEN** the user chooses "Report this problem"
- **THEN** the form opens with Topic set to Playback, an empty text, and "Last playback error: Stream not found (404)" in the "What will be sent" list
- **AND** the channel name, the source name and the stream address are not in the form or the list

#### Scenario: Apple TV focus
- **GIVEN** the error screen on Apple TV
- **WHEN** it appears
- **THEN** Try again keeps focus, "Report this problem" sits to its right, and swiping up or down still changes channel

#### Scenario: Back to the error
- **GIVEN** the form opened from the error screen
- **WHEN** the user sends the report and chooses Done, or closes the form
- **THEN** the error screen shows again with Try again
