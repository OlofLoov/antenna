## MODIFIED Requirements

### Requirement: A failed stream says what went wrong
The system SHALL replace the picture of a failed channel with a title, a plain explanation naming the source, a "Try again" button and, on Live, a "Channels" button unless the groups are already on screen or "Sign in" takes its place, close any panel, picker or Picture in Picture window first, and keep the channel name visible on iPhone, iPad and Mac.

#### Scenario: The error screen
- **GIVEN** a channel whose playback has failed
- **WHEN** the player is shown
- **THEN** the picture is replaced by a title, a plain explanation naming the source, and a "Try again" button followed by a "Channels" button, apart from the cases "Go to another group from the error" names
- **AND** any open panel, picker or Picture in Picture window closes first
- **AND** on iPhone, iPad and Mac the channel name stays visible

#### Scenario: The error on Apple TV
- **GIVEN** a failed channel on Apple TV
- **WHEN** the error shows
- **THEN** "Try again" is focused with "Channels" or "Sign in" beside it, and a line names the source and when it was tried and says how to change channel
- **AND** swiping up or down still changes channel

#### Scenario: Behind another screen
- **GIVEN** the overlay, guide or another tab is open
- **WHEN** the stream fails
- **THEN** the error is drawn in the player behind them

#### Scenario: VoiceOver and large text
- **GIVEN** VoiceOver is on or the text size is large
- **WHEN** the error appears
- **THEN** VoiceOver reads its title and explanation once, and the explanation wraps

## ADDED Requirements

### Requirement: Go to another group from the error
The system SHALL open the channel list Live already uses, on the group the user was watching, when the user chooses "Channels" on the error, so they can move to another group and play a channel from it.

#### Scenario: Channels on Apple TV
- **GIVEN** the error on Apple TV
- **WHEN** the user moves right from "Try again" and presses select on "Channels"
- **THEN** the channel overlay opens with the highlight on the group the user was watching in the group column
- **AND** swiping up or down moves to the other groups, and picking a channel there plays it and the error goes

#### Scenario: Menu after Channels on Apple TV
- **GIVEN** the overlay opened from "Channels"
- **WHEN** the user presses Menu
- **THEN** the overlay closes and "Try again" has the focus again
- **AND** a second Menu shows the tab bar, as on the error before

#### Scenario: A login error on Apple TV
- **GIVEN** an error on Apple TV that offers "Sign in"
- **WHEN** the error shows
- **THEN** it offers "Try again" and "Sign in" and no "Channels"

#### Scenario: Channels on iPhone
- **GIVEN** the error on iPhone, in place or full screen
- **WHEN** the user taps "Channels"
- **THEN** full screen ends if it was on and the Groups sheet opens with the group the user was watching checked
- **AND** picking another group shows its channels under the picture, and tapping one plays it and the error goes

#### Scenario: Channels on iPad and Mac
- **GIVEN** the error on iPad or Mac, with the sidebar folded or in full screen
- **WHEN** the user chooses "Channels"
- **THEN** full screen ends if it was on and the sidebar shows its groups with the one the user was watching selected

#### Scenario: The groups already on screen
- **GIVEN** an iPad or Mac window wide enough to show the sidebar and the list next to the picture, out of full screen
- **WHEN** the error shows
- **THEN** it offers only "Try again", since the groups are already beside it
