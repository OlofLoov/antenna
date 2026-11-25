## ADDED Requirements

### Requirement: No empty state before the channels are listed
The system SHALL show the loading screen on Live while a source has channels and none plays yet, as while the launch waits for the page of the title watched last. The Guide SHALL read "Loading channels" in place of an empty group before the sources are read, while a source loads, and while the channels that loaded are not listed yet.

#### Scenario: The title watched last opens at launch
- **GIVEN** the profile last watched a movie on this Apple TV and its sources load before the movie's page opens
- **WHEN** Live shows while the page is on its way
- **THEN** the loading screen lists each source with its channel count, and "No channels yet" never shows

#### Scenario: The Guide while the sources load
- **GIVEN** the sources are still loading
- **WHEN** the user opens the Guide
- **THEN** the grid reads "Loading channels", and "No channels in" the group shows only once the channels are listed and the group has none

## MODIFIED Requirements

### Requirement: An empty screen with Retry
The system SHALL show a "No channels yet" screen naming each source that added nothing and why ("no channels", "offline", "could not load its channels" or "waiting for its login to sync from iCloud"), once no source is loading, no source has channels and no channel plays, with Open Settings, focused first, and Try again. Try again SHALL load those sources again behind the loading screen and give the last channel another 10 seconds.

#### Scenario: Nothing to play
- **GIVEN** every source has finished, failed or is waiting for its password, and none has any channels
- **WHEN** Live is shown
- **THEN** "No channels yet" names each source and why, with Open Settings focused and Try again beside it
- **AND** Open Settings opens Sources and Settings, Try again loads the sources again and shows the loading screen, and Menu shows the tab bar

#### Scenario: Offline at launch
- **GIVEN** the device is offline at launch
- **WHEN** every source fails
- **THEN** the empty screen shows each source as offline, with Open Settings and Try again as the ways on

#### Scenario: Offline compared with other failures
- **GIVEN** one source whose request fails because there is no connection or the connection dropped, and one that fails for any other reason
- **WHEN** both have finished
- **THEN** the first reads "offline" and the second "could not load its channels"

#### Scenario: No sources at all
- **GIVEN** the user has no sources
- **WHEN** Live is shown
- **THEN** "No channels yet" shows with no source lines, and Try again does nothing
