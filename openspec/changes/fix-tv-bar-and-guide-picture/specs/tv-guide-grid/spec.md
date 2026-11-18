## ADDED Requirements

### Requirement: The small picture follows the highlight
The system SHALL tune the small picture to the highlighted row's channel once the highlight rests on that row for about three quarters of a second, in place of the stream it had, without making it the last channel until the user picks it. Select or Watch SHALL keep it playing without a reload, and leaving the guide any other way SHALL tune back to the channel from before.

#### Scenario: Resting on a row
- **GIVEN** the guide is open with Channel 1 in the small picture
- **WHEN** the user moves the highlight down to Channel 2 and stops there
- **THEN** after about three quarters of a second the small picture plays Channel 2, its caption names Channel 2 and its row is marked as playing
- **AND** Channel 1's stream stops, so one stream plays at a time

#### Scenario: Scrolling past rows
- **GIVEN** the guide is open
- **WHEN** the user swipes quickly down past several rows and stops on one
- **THEN** only the row the highlight stops on is tuned
- **AND** moving left or right along that row tunes nothing more

#### Scenario: Watching the channel in the picture
- **GIVEN** the small picture plays Channel 2 because the highlight rests on its row
- **WHEN** the user selects a programme on now, or Watch
- **THEN** Channel 2 carries on full screen with the info bar, without starting again
- **AND** Channel 2 is the channel the app comes back to at launch

#### Scenario: Leaving without picking
- **GIVEN** Channel 1 played when the guide opened and the small picture now plays Channel 2
- **WHEN** the user presses Back and picks Live, or another tab, from the bar
- **THEN** Channel 1 plays again, and the channel to come back to at launch is still Channel 1

#### Scenario: Nothing played before the guide
- **GIVEN** no channel had been tuned when the guide opened
- **WHEN** the small picture has followed the highlight and the user leaves the guide
- **THEN** the channel in the small picture stays tuned

## MODIFIED Requirements

### Requirement: The channel keeps playing in a small picture
The system SHALL keep the playing or paused stream going in a small picture with the channel's number and name when the user opens the Guide tab, resuming a paused stream and never restarting it, until the highlight rests on another channel's row.

#### Scenario: Opening the guide while watching
- **GIVEN** a channel is playing, or was paused when the user left full screen
- **WHEN** the user opens the Guide tab
- **THEN** the same stream plays in the small picture with the channel's number and name
- **AND** it resumes if it was paused, without restarting

#### Scenario: The stream is loading or failed
- **GIVEN** the stream is loading or has failed
- **WHEN** the guide shows
- **THEN** the small picture shows the background color with the caption
- **AND** Watch tunes again

#### Scenario: Nothing tuned yet
- **GIVEN** no channel has been tuned since launch
- **WHEN** the user opens the guide
- **THEN** the small picture is empty and Watch tunes
