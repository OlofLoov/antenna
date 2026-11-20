## Purpose

Shows live viewers the channels their providers added lately, in a New group on every device, so a channel that appeared since the last refresh is easy to find without scrolling All channels.

## ADDED Requirements

### Requirement: A New group lists channels added lately
The system SHALL show a New group after Recents and before All channels on iPhone, iPad, Mac and in the Apple TV channel overlay, listing the channels this device first saw in the last seven days, newest first, and SHALL hide the group when there are none.

#### Scenario: A provider adds channels
- **GIVEN** a source that had 400 channels yesterday
- **WHEN** it refreshes with three channels it did not have before
- **THEN** a New group with those three appears after Recents and before All channels, newest first
- **AND** VoiceOver reads it as "New, 3 channels"

#### Scenario: A week later
- **GIVEN** a channel first seen eight days ago
- **WHEN** the user looks at the New group
- **THEN** the channel is no longer in it, and with nothing left the group is not shown

#### Scenario: Apple TV overlay
- **GIVEN** the channel overlay on Apple TV with a New group
- **WHEN** the user moves focus onto New
- **THEN** its channels list beside it, and playing one keeps the user's current group as playing from Recents does

### Requirement: A new source starts with nothing new
The system SHALL treat every channel of a source's first load on this device as already known, so a source added or seen for the first time never fills the New group.

#### Scenario: Adding a source
- **GIVEN** the user adds a playlist with 1,200 channels
- **WHEN** it loads for the first time
- **THEN** there is no New group for it

#### Scenario: A new device
- **GIVEN** an Apple TV set up today with a source the user has had for a year
- **WHEN** the source loads
- **THEN** no channel is new until a later refresh brings one

### Requirement: What New remembers stays on the device
The system SHALL keep which channels it has seen on the device only, holding no stream link or login, and SHALL forget a source's channels when the source is deleted. When what it kept is lost, the next load SHALL count as a first load.

#### Scenario: Deleting a source
- **GIVEN** a source with channels in New
- **WHEN** the source is deleted on this device or another
- **THEN** its channels leave New

#### Scenario: Lost memory
- **GIVEN** the system cleared the app's caches
- **WHEN** the sources load again
- **THEN** no channel is new until a later refresh brings one

#### Scenario: A playlist with logins in its links
- **GIVEN** a playlist whose channel links carry a username and password
- **WHEN** its channels are remembered
- **THEN** what is kept holds no link, username or password

### Requirement: Renamed and moved channels are not new
The system SHALL count a channel as new only when its identity is new, not when it changes name, group or number.

#### Scenario: A renamed channel
- **GIVEN** a channel that changes its name and group in a refresh but keeps its identity
- **WHEN** the source refreshes
- **THEN** it is not in New
