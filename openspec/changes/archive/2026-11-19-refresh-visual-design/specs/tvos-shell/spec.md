## MODIFIED Requirements

### Requirement: A loading screen at launch
The system SHALL show a loading screen on Live while no channel plays and at least one source is still loading, and before the sources are read at launch. It SHALL list each source by name with "Loading channels", its channel count, "Offline", "Could not load channels" or "Waiting for its login to sync from iCloud". Menu SHALL still reach the tab bar and Settings.

#### Scenario: Nothing loaded yet
- **GIVEN** the user has sources and none has finished loading
- **WHEN** they open Antenna
- **THEN** a loading screen lists each source by name with how far it has got, and Menu reaches the tab bar and Settings

#### Scenario: One source done, one still loading
- **GIVEN** one source finished with no channels and another is still loading
- **WHEN** Live is shown
- **THEN** the loading screen stays, the finished source reads "0 channels" and the other "Loading channels"

#### Scenario: Before the sources are read
- **GIVEN** the app has just launched and has not read the stored sources yet
- **WHEN** Live is shown
- **THEN** the loading screen shows, never the empty screen

#### Scenario: Late password
- **GIVEN** a source whose password or record arrives after launch
- **WHEN** the app returns to the foreground or the user presses Try again
- **THEN** a source waiting for its password loads once the password is on this Apple TV, and the loading screen never appears while a channel plays

### Requirement: An empty screen with Retry
The system SHALL show a "No channels yet" screen naming each source that added nothing and why ("no channels", "offline", "could not load its channels" or "waiting for its login to sync from iCloud"), once no source is loading and no channel plays, on the shared empty and error layout with Open Settings and Try again as its buttons. Open Settings SHALL take focus when the screen appears and open Sources and Settings. Try again SHALL load those sources again behind the loading screen and give the last channel another 10 seconds.

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
