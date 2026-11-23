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
The system SHALL play the channel that was playing when the user left on iPhone, iPad and Mac once Live shows: at once when it was saved for launch, otherwise once its source has loaded.

#### Scenario: Return to Live
- **GIVEN** a channel was playing on iPhone, iPad or Mac when the user left
- **WHEN** they open Antenna and go to Live, and the channel was saved for launch or its source has loaded
- **THEN** that channel plays again and is highlighted in its list once the list shows

#### Scenario: Offline or slow at launch
- **GIVEN** the user opens Antenna offline, or with a slow or very large source, and the channel was not saved for launch
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
The system SHALL never store a stream link in Recents or the session, SHALL keep no username or password from a stream link in Recents, the session or what is saved for launch, and SHALL add M3U channels to Recents and save them for restore like any other channel. A channel whose internal id still contains a stream link SHALL be neither added nor saved, with no error shown.

#### Scenario: An M3U channel
- **GIVEN** a channel from an M3U playlist whose links carry a username and password
- **WHEN** the user watches it for ten seconds
- **THEN** it is added to Recents and saved as the channel to restore, Recents holds no link, and none of these stored values holds the username or the password

#### Scenario: An M3U channel with a stream link in its id
- **GIVEN** a channel whose internal id (Antenna's own reference to the channel) still contains a stream link
- **WHEN** the user watches it
- **THEN** it is neither added to Recents nor saved as the channel to restore, and no error is shown

#### Scenario: Xtream channels
- **GIVEN** a channel from an Xtream source
- **WHEN** the user watches it for ten seconds
- **THEN** it is added to Recents and saved as the channel to restore

### Requirement: The last channel does not wait for bookkeeping
The system SHALL tune the restored channel as soon as its source's channels are loaded, before it records which channels the device has seen, on every platform. The New group SHALL show what that record finds once it is written.

#### Scenario: A very large source at launch
- **GIVEN** the last channel belongs to a source with 50 000 channels
- **WHEN** the app launches and the source loads
- **THEN** the channel starts without waiting for the seen-channel record to be read or written

#### Scenario: New channels after the record
- **GIVEN** a source that gained channels since its last load
- **WHEN** it loads and the record is written
- **THEN** the New group shows the gained channels, as before

### Requirement: The last channel starts before its source loads
The system SHALL tune the last channel at launch from what the device saved of it, without waiting for its source's channel list, on iPhone, iPad, Mac and Apple TV, when the channel came from an Xtream source, an M3U playlist, an imported playlist file or a Channels DVR server and its source's login is on the device. The channel list and the guide SHALL load as they do without it.

#### Scenario: A large source at launch
- **GIVEN** the last channel belongs to an Xtream source whose channel list takes 20 seconds to download
- **WHEN** the user opens Antenna and Live shows, or Apple TV reaches full screen
- **THEN** the channel starts tuning before the list has loaded, and the list and the guide load behind it

#### Scenario: A source whose channels are not saved
- **GIVEN** the last channel belongs to a Stalker portal or a Jellyfin server
- **WHEN** the user opens Antenna
- **THEN** the channel plays once its source has loaded, as before

#### Scenario: The login is not on this device
- **GIVEN** the last channel's source is waiting for its login to sync
- **WHEN** the user opens Antenna
- **THEN** nothing is tuned from what was saved, and the channel plays once its source loads

#### Scenario: Another channel picked first
- **GIVEN** the saved channel started at launch
- **WHEN** the user picks another channel before the list arrives
- **THEN** the picked channel plays, and the list arriving changes nothing

### Requirement: The fresh list decides
The system SHALL check the channel it started from what was saved against the source's list once the list loads, and follow the list.

#### Scenario: The same stream
- **GIVEN** the saved channel is playing and the list arrives with the same channel and the same link
- **WHEN** the list loads
- **THEN** the channel plays on without loading again, and its number, catch-up and guide come from the list

#### Scenario: The link changed
- **GIVEN** the saved channel is playing and the list arrives with a different link for that channel
- **WHEN** the list loads
- **THEN** the channel is tuned again from the list's link

#### Scenario: The channel is gone
- **GIVEN** the saved channel is playing and the list no longer has it
- **WHEN** the list loads
- **THEN** on iPhone, iPad and Mac the channel stops and nothing plays, and on Apple TV the first channel of the first source to load plays instead

#### Scenario: The saved stream failed
- **GIVEN** the saved channel failed to start, for example because the provider changed its server
- **WHEN** the list loads with that channel
- **THEN** the channel is tuned again from the list's link

#### Scenario: The list fails to load
- **GIVEN** the saved channel is playing
- **WHEN** its source fails to load
- **THEN** the channel plays on and the source shows its error as before

### Requirement: What is saved for launch holds no login
The system SHALL save the channel for launch only on this device, per profile, outside iCloud and device backups, with every username and password taken out of its links, and SHALL put them back at launch from where the app keeps the source's login. A channel whose link keeps a part the app cannot take out SHALL not be saved, with no error shown.

#### Scenario: An Xtream channel
- **GIVEN** a channel from an Xtream source with username alice and password s3cr3t
- **WHEN** its stream loads and the device saves it for launch
- **THEN** nothing saved holds alice or s3cr3t, and at the next launch the link with both is rebuilt from the Keychain

#### Scenario: An M3U channel with a login in its links
- **GIVEN** a playlist link with a username and password whose channel links carry the same login
- **WHEN** the channel is saved for launch
- **THEN** nothing saved holds the username or the password

#### Scenario: A link the app cannot clean
- **GIVEN** a channel link with a login before the host, or a query value named like a token or a password that is not the source's login
- **WHEN** its stream loads
- **THEN** it is not saved for launch, no error shows, and at the next launch it plays once its source loads

#### Scenario: The password changed
- **GIVEN** the source's password was changed on another device and the new one synced
- **WHEN** the user opens Antenna
- **THEN** the saved channel is tuned with the new password

#### Scenario: A deleted source or profile
- **GIVEN** a channel saved for launch
- **WHEN** its source or its profile is deleted
- **THEN** it is no longer saved and is not tuned at the next launch
