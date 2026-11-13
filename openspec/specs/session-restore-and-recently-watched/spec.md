# session-restore-and-recently-watched Specification

## Purpose
Brings viewers back to the few channels they keep returning to: a Recents group of channels watched lately on each device, iPhone, iPad and Mac reopening on the same tab, group and channel, and Apple TV swipes for the previous channel and for Recents.

## Requirements

### Requirement: Recents keep the newest first, each channel once
The system SHALL keep Recents as at most 20 channels, newest first, each channel once, moving a channel watched again to the top.

#### Scenario: A full list
- **GIVEN** a full Recents list of 20 channels
- **WHEN** the user watches a channel already in the list, and then one that is not
- **THEN** the first moves to the top without a duplicate, the second goes on top and the oldest falls off, and the list never holds more than 20

#### Scenario: Damaged stored data
- **GIVEN** stored recents that cannot be read
- **WHEN** Antenna starts
- **THEN** it starts with empty recents and no restore, without an error

#### Scenario: The paid unlock lapses
- **GIVEN** recents on a device
- **WHEN** the paid unlock lapses and later returns
- **THEN** the recents are kept and come back

### Requirement: A channel counts as watched after ten seconds
The system SHALL add a channel to Recents only after it has played without interruption for ten seconds.

#### Scenario: Ten seconds of playback
- **GIVEN** the user has tuned to a channel
- **WHEN** it plays without interruption for ten seconds
- **THEN** it appears at the top of Recents

#### Scenario: Interrupted before ten seconds
- **GIVEN** the user has tuned to a channel
- **WHEN** they switch channel, play a movie, leave the app, or the stream stalls before ten seconds
- **THEN** it does not count until it plays ten more uninterrupted seconds

### Requirement: Deleting a source clears its channels
The system SHALL remove a deleted source's channels from Recents and from what is restored at launch, whether the source was deleted on this device or another.

#### Scenario: A source is deleted
- **GIVEN** recents and a saved session that include channels from a source
- **WHEN** that source is deleted, on this device or on another one through iCloud
- **THEN** its channels leave Recents, its channel is no longer restored at launch, a group from that source is no longer restored, and channels from other sources are untouched

### Requirement: Recents sits between Favorites and All channels
The system SHALL show Recents after Favorites and before All channels on every device, listing only channels that still exist, and SHALL hide it when there is nothing to list.

#### Scenario: Recents in the group list
- **GIVEN** the user has watched at least one channel that still exists in a loaded source
- **WHEN** they look at the groups on iPhone, iPad, Mac or in the Apple TV channel overlay
- **THEN** Recents appears after Favorites and before All channels, lists only channels that still exist, newest first

#### Scenario: Nothing to list
- **GIVEN** no watched channel that still exists in a loaded source
- **WHEN** the user looks at the groups
- **THEN** Recents is not shown at all

#### Scenario: A channel changes identity
- **GIVEN** a channel in Recents whose provider changes its identity, or two channels sharing one identity in one source
- **WHEN** the catalogue loads
- **THEN** that channel is not listed in Recents

#### Scenario: Spoken label
- **GIVEN** VoiceOver is on
- **WHEN** focus reaches the Recents group
- **THEN** it reads "Recents, n channels"

### Requirement: The list holds still while you use it
The system SHALL keep the rows of an open Recents list in their order while the user plays from it, and reorder only the next time it opens.

#### Scenario: Play from Recents
- **GIVEN** the Recents list is on screen
- **WHEN** the user plays a channel from it and keeps watching past ten seconds
- **THEN** the rows stay in the order they had, with the new channel highlighted
- **AND** the next time Recents is opened, that channel is on top

### Requirement: Playing from Recents keeps your group on Apple TV
The system SHALL keep the user's current group on Apple TV when they play a channel from Recents.

#### Scenario: Play from Recents in the overlay
- **GIVEN** the user was in group G on Apple TV and opens Recents in the channel overlay
- **WHEN** they play a channel from Recents
- **THEN** G stays the current group, so swiping up and down in full screen still steps through G

### Requirement: Reopen on the same tab and group
The system SHALL reopen iPhone, iPad and Mac on the tab and Live group the user last had open.

#### Scenario: Reopen the app
- **GIVEN** the user last had a tab and a channel group open on iPhone, iPad or Mac
- **WHEN** they open Antenna again
- **THEN** the same tab is shown, and Live shows the same group

#### Scenario: A tab that is not restored
- **GIVEN** the user was last on Search or Settings, or on Movies or Series with no source that has them
- **WHEN** they open Antenna again
- **THEN** Antenna opens on Live

#### Scenario: The group is gone or still loading
- **GIVEN** the restored group no longer exists, or its source is still loading
- **WHEN** Live opens
- **THEN** All channels shows, and a group that arrives later is selected unless the user picked one meanwhile

#### Scenario: The group disappears while on screen
- **GIVEN** Live on screen with a group selected
- **WHEN** that group disappears
- **THEN** All channels is shown and the playing channel carries on

### Requirement: The last channel plays again
The system SHALL play the channel that was playing when the user left, once its source has loaded, on iPhone, iPad and Mac.

#### Scenario: Return to Live
- **GIVEN** a channel was playing on iPhone, iPad or Mac when the user left
- **WHEN** they open Antenna and go to Live, and the channel's source has loaded
- **THEN** that channel plays again and is highlighted in its list

#### Scenario: Offline or slow at launch
- **GIVEN** the user opens Antenna offline, or with a slow or very large source
- **WHEN** Live opens
- **THEN** the restore waits, and completes once the source loads or the user retries after reconnecting

#### Scenario: The channel cannot be played
- **GIVEN** the restored channel cannot be found, or its source failed or is waiting for its login to sync
- **WHEN** Live opens
- **THEN** nothing plays, and the channel plays once its source loads unless the user picked another channel first

### Requirement: Restore survives the system closing the app
The system SHALL restore the tab, group and channel after the system has closed Antenna in the background, as after a normal quit.

#### Scenario: Closed in the background
- **GIVEN** the user was watching a channel in a group with another tab open
- **WHEN** the system closes Antenna in the background and the user opens it again
- **THEN** the tab, the group and the channel come back

### Requirement: Swipe left for the previous channel
The system SHALL play the most recent other channel in Recents when the user swipes left during full-screen playback on Apple TV.

#### Scenario: Swipe left
- **GIVEN** full-screen playback on Apple TV with nothing else on screen and at least one other channel in Recents
- **WHEN** the user swipes left
- **THEN** the most recent other channel plays and its name shows in the zap bar
- **AND** swiping left again goes back

#### Scenario: No other channel
- **GIVEN** full-screen playback on Apple TV with no other channel in Recents
- **WHEN** the user swipes left
- **THEN** nothing happens

### Requirement: Swipe right opens the channel list on Recents
The system SHALL open the channel overlay on Recents, with its first row highlighted, when the user swipes right during full-screen playback on Apple TV.

#### Scenario: Swipe right
- **GIVEN** full-screen playback on Apple TV with nothing else on screen
- **WHEN** the user swipes right
- **THEN** the channel overlay opens with Recents selected and its first row highlighted, playback carries on, and the current group is unchanged

#### Scenario: No Recents
- **GIVEN** Recents is not shown
- **WHEN** the user swipes right
- **THEN** the overlay opens as usual

### Requirement: Links with passwords are never stored
The system SHALL never store a stream link in Recents or in what is saved for restore, and SHALL add M3U channels to Recents and save them for restore like any other channel. A channel whose internal id still contains a stream link SHALL be neither added nor saved, with no error shown.

#### Scenario: An M3U channel
- **GIVEN** a channel from an M3U playlist whose links carry a username and password
- **WHEN** the user watches it for ten seconds
- **THEN** it is added to Recents and saved as the channel to restore, and neither stored value holds the link, the username or the password

#### Scenario: An M3U channel with a stream link in its id
- **GIVEN** a channel whose internal id (Antenna's own reference to the channel) still contains a stream link
- **WHEN** the user watches it
- **THEN** it is neither added to Recents nor saved as the channel to restore, and no error is shown

#### Scenario: Xtream channels
- **GIVEN** a channel from an Xtream source
- **WHEN** the user watches it for ten seconds
- **THEN** it is added to Recents and saved as the channel to restore
