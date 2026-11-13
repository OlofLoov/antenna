# local-m3u-file-import Specification

## Purpose
Lets people whose provider sends a playlist file instead of a link, or who build their own, bring that file into Antenna on iPhone, iPad or Mac and watch its channels on every device, Apple TV included.

## Requirements

### Requirement: Bring a file in
The system SHALL open the import sheet for a playlist file the user picks with "Import a file", shares to Antenna, or opens with Antenna from Finder, on iPhone, iPad and Mac.

#### Scenario: Pick, share or open a file
- **GIVEN** Settings or onboarding on iPhone, iPad or Mac, or a playlist file in another app
- **WHEN** the user picks a file with "Import a file", or shares it to Antenna, or opens it with Antenna from Finder
- **THEN** the import sheet opens for that file

#### Scenario: A second file while the sheet is open
- **GIVEN** the import sheet open for one file
- **WHEN** a second file arrives
- **THEN** it is ignored

#### Scenario: Shared while the paywall is up
- **GIVEN** the paywall is up
- **WHEN** a file is shared to Antenna
- **THEN** the sheet waits until the app is unlocked

### Requirement: Drop a file on the window
The system SHALL accept a playlist or text file dragged onto the window on iPad and Mac, showing a drop target during the drag and opening the import sheet for the first file dropped.

#### Scenario: Drag and drop
- **GIVEN** Settings, onboarding's welcome or the add-source sheet on iPad or Mac
- **WHEN** the user drags a playlist or text file over the window and drops it
- **THEN** a drop target appears during the drag and the import sheet opens for the first file dropped

#### Scenario: Something that is not a file
- **WHEN** the user drags an image, text or a web link over the window
- **THEN** no drop target shows

### Requirement: See what's in the file before importing
The system SHALL read a file before importing it and show how many channels and groups it holds, whether a guide link was found and how many entries were skipped, with the name and guide link filled in.

#### Scenario: A typical file
- **GIVEN** a playlist file with 412 channels in 18 groups, a guide link and 3 entries that are not links
- **WHEN** the import sheet has read it
- **THEN** it says "412 channels in 18 groups", that a guide link was found, and that 3 entries were skipped, with the name and guide link filled in

#### Scenario: A file name imported before
- **GIVEN** a file whose name was imported before
- **WHEN** the sheet has read it
- **THEN** it asks whether to replace that source or import it as new

#### Scenario: An old Windows encoding
- **GIVEN** a file whose text is in an old Windows encoding
- **WHEN** the sheet reads it
- **THEN** it imports, and names may show a replacement character

### Requirement: Import and watch
The system SHALL save an imported file's contents as a source whose channels appear in Live without a relaunch, matching the summary's count, with no network request for the playlist itself.

#### Scenario: Tap Import
- **GIVEN** the import sheet showing a file's summary
- **WHEN** the user taps Import
- **THEN** the source is saved with the file's contents, its channels appear in Live without a relaunch and match the summary's count, its guide downloads like any playlist's, and no network request is made for the playlist itself

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user imports a file
- **THEN** the import works fully, and only the guide download waits for the network

#### Scenario: No Refresh
- **GIVEN** a file source
- **WHEN** the user refreshes all sources
- **THEN** the file source is skipped and changes only when re-imported

#### Scenario: Not signed in to iCloud
- **GIVEN** the device is not signed in to iCloud, or its iCloud storage is full
- **WHEN** the user imports a file
- **THEN** the source works on this device only

### Requirement: A file too large is refused before it is read
The system SHALL refuse a file larger than 16 MB, saying how big it is and what the limit is, and save nothing.

#### Scenario: A 20 MB file
- **GIVEN** a file larger than 16 MB
- **WHEN** the user picks, shares or drops it
- **THEN** the sheet says how big the file is and that the limit is 16 MB, suggests splitting it or hosting it as a link, and nothing is saved

### Requirement: A file that is not a channel list is explained
The system SHALL refuse a file with no channel entries, a plain list of links, a single video stream or unreadable contents, saying which it is and what to do instead.

#### Scenario: Refused contents
- **GIVEN** a file with no channel entries, a plain list of links, a single video stream, or one that cannot be read
- **WHEN** the sheet has checked it
- **THEN** the sheet says which of these it is and what to do instead, and Import stays disabled

#### Scenario: A web page named .m3u
- **GIVEN** a file named `.m3u` that holds a web page
- **WHEN** the sheet checks it
- **THEN** it is refused as not a channel list, because content decides

#### Scenario: A file with one link
- **GIVEN** a file holding exactly one link
- **WHEN** the sheet checks it
- **THEN** it offers to add that link as a source

### Requirement: Re-import onto the same source
The system SHALL replace a file source's channels with a newer copy of the file while keeping its name, its place in the list and the favorites of channels still in the file.

#### Scenario: Re-import a newer copy
- **GIVEN** a file source with favorites
- **WHEN** the user re-imports a newer copy of the file
- **THEN** the source keeps its name and place in the list, its channels are replaced, and favorites of channels still in the file keep working

#### Scenario: A changed password
- **GIVEN** a file source whose provider changed the password
- **WHEN** the user plays a channel
- **THEN** streams fail until the file is re-imported

#### Scenario: Two devices re-import at once
- **GIVEN** two devices re-importing the same source at the same time
- **WHEN** both copies sync
- **THEN** one copy wins and the other is lost without notice

### Requirement: Channels reach Apple TV
The system SHALL sync an imported file's contents to every device on the same iCloud account, showing the source as waiting for iCloud until they arrive, so its channels play on Apple TV without the file.

#### Scenario: A file without logins
- **GIVEN** a file whose links carry no login, imported on iPhone
- **WHEN** an Apple TV signed into the same iCloud account is on
- **THEN** the source shows as waiting for iCloud until the contents arrive, then its channels appear and play there without a relaunch, without the Apple TV ever touching the file

#### Scenario: A file with logins on Apple TV
- **GIVEN** a file whose links carry a login
- **WHEN** its source reaches an Apple TV
- **THEN** the source shows as waiting for its login and its channels do not play there, until Antenna offers a way to sign in on Apple TV

#### Scenario: A login not yet synced
- **GIVEN** a login from the links that has not reached another iPhone, iPad or Mac yet
- **WHEN** that device shows the source
- **THEN** it shows as waiting for its login

#### Scenario: An older app version
- **GIVEN** an older version of Antenna on another device
- **WHEN** the file source syncs to it
- **THEN** it shows the source in Settings with no channels and does not crash

### Requirement: No import on Apple TV
The system SHALL offer no import control on Apple TV and SHALL not register the Apple TV app as a handler for playlist files.

#### Scenario: Browse the Apple TV app
- **GIVEN** the app on Apple TV
- **WHEN** the user moves through any screen
- **THEN** no import control appears, and the app is not offered as a handler for playlist files

### Requirement: Import during onboarding
The system SHALL let the user import a file from onboarding's playlist form and continue to onboarding's loading step.

#### Scenario: Import a file instead
- **GIVEN** onboarding's playlist form
- **WHEN** the user chooses "Import a file instead" and imports a file
- **THEN** onboarding continues to its loading step with the playlist row naming the file

### Requirement: Deleting removes everything
The system SHALL remove a deleted file source's contents, its guide and any login moved from its links.

#### Scenario: Delete a file source
- **GIVEN** a file source
- **WHEN** the user deletes it
- **THEN** its contents, its guide and any login moved from its links are gone

### Requirement: Logins in stream links stay private
The system SHALL move every username and password found in a file's stream links to the Keychain before anything syncs, so channels still play and no login reaches the synced store or a log.

#### Scenario: Links with logins
- **GIVEN** a playlist whose stream links carry a username and password, in the query, in the path or before the host
- **WHEN** the user imports it
- **THEN** the logins are moved to the Keychain before anything syncs, channels still play, and no login reaches the synced store or a log
- **AND** the synced copy holds the links without their logins
