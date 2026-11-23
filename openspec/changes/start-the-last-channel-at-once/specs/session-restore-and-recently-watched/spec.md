## ADDED Requirements

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

## MODIFIED Requirements

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
