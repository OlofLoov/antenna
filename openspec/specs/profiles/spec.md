# profiles Specification

## Purpose
Lets the people sharing one subscription each keep their own favorites, history and hidden groups, on every device, while adding the sources and logins once.

## Requirements

### Requirement: Who's watching at launch
The system SHALL open a "Who's watching?" screen at launch when the user has two or more profiles, listing every profile with its color, initial and name in the user's order, and SHALL open on the profile chosen. With one profile it SHALL open as before, showing no profile name or profile button; only Settings offers a way to add a profile.

#### Scenario: Two or more profiles
- **GIVEN** the profiles Dad, Mum and Kids
- **WHEN** the user opens Antenna
- **THEN** the "Who's watching?" screen lists Dad, Mum and Kids, each with its color and initial, before any channel plays
- **AND** choosing Kids opens Antenna on Kids's favorites, last channel and history

#### Scenario: One profile
- **GIVEN** a single profile
- **WHEN** the user opens Antenna
- **THEN** no "Who's watching?" screen appears and no profile name or button is shown
- **AND** Settings lists Profiles with "Add a profile"

#### Scenario: Focus on Apple TV
- **GIVEN** the "Who's watching?" screen on Apple TV
- **WHEN** it appears
- **THEN** focus is on the profile last used on this Apple TV, or the first profile when none was
- **AND** Back on this screen goes to the Apple TV Home Screen, since there is nothing behind it

#### Scenario: The focused circle shows whole
- **GIVEN** the "Who's watching?" screen, or the profile button at the top of Settings, on Apple TV
- **WHEN** a profile circle has focus and lifts
- **THEN** the whole circle and its shadow show, with nothing cut from its sides

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** a profile tile is focused
- **THEN** it reads the profile's name and "profile"

### Requirement: Switching profile
The system SHALL let the user switch profile from the top of Settings on Apple TV, from the profile button on iPhone, and from Settings on every device, and SHALL then show the new profile's favorites, hidden groups, last channel and history.

#### Scenario: Switching on Apple TV
- **GIVEN** two or more profiles and the tab bar raised
- **WHEN** the user selects the profile button and chooses another profile
- **THEN** Live opens on that profile's last channel on this Apple TV, or as at launch when it has none
- **AND** the channel overlay and Favorites show that profile's favorites

#### Scenario: Switching from the profile button on iPhone
- **GIVEN** two or more profiles, on iPhone or in a narrow iPad window
- **WHEN** the user taps the profile button at the top right, chooses Switch profile and picks another profile
- **THEN** what played stops, and every tab shows that profile's favorites, hidden groups and history

#### Scenario: Switching on iPhone, iPad or Mac
- **GIVEN** two or more profiles
- **WHEN** the user opens Settings, selects Profiles and chooses another profile
- **THEN** every tab shows that profile's favorites, hidden groups and history

#### Scenario: Which profile a device is on
- **GIVEN** the Apple TV is on Kids and the iPhone on Dad
- **WHEN** either is opened again later
- **THEN** the Apple TV's "Who's watching?" screen starts on Kids and the iPhone's on Dad
- **AND** choosing a profile on one device never changes the other

### Requirement: Adding a profile
The system SHALL let the user add a profile with a name, one of eight colors and one of five accents from Manage profiles, reached from the "Who's watching?" screen or from Profiles in Settings, up to eight profiles. A new profile's accent SHALL start as Blue.

#### Scenario: The second profile
- **GIVEN** a single profile and no profile shown anywhere
- **WHEN** the user adds a profile named Kids from Settings
- **THEN** the existing profile is named "Main" and Kids is added after it
- **AND** the next launch shows the "Who's watching?" screen

#### Scenario: A name is needed
- **GIVEN** the user is adding a profile
- **WHEN** the name is empty or only spaces
- **THEN** the profile cannot be saved

#### Scenario: Eight profiles
- **GIVEN** eight profiles
- **WHEN** the user looks for a way to add another
- **THEN** there is none, and Manage profiles says eight is the most

#### Scenario: Picking an accent for a new profile
- **GIVEN** the user is adding a profile named Kids
- **WHEN** they pick Amber under Accent and save
- **THEN** Kids is added with the Amber accent, and the app shows Amber whenever Kids is the current profile

### Requirement: Editing and deleting a profile
The system SHALL let the user rename, recolor, change the accent of and delete a profile, SHALL ask before deleting and say that its favorites and history go with it, and SHALL NOT delete the last profile. A changed accent SHALL show at once if the profile is current.

#### Scenario: Deleting a profile
- **GIVEN** the profiles Dad and Kids
- **WHEN** the user deletes Kids and confirms
- **THEN** Kids, its favorites, hidden groups, watch progress, My list, recent searches and recently watched are removed on every device
- **AND** Dad is unchanged and the next launch shows no "Who's watching?" screen

#### Scenario: The last profile
- **GIVEN** a single profile
- **WHEN** the user edits it
- **THEN** it can be renamed, recolored and given another accent but not deleted

#### Scenario: A device on a deleted profile
- **GIVEN** the Apple TV is on Kids
- **WHEN** Kids is deleted on the iPhone
- **THEN** the Apple TV shows the "Who's watching?" screen, or opens on the only profile left

#### Scenario: Changing the accent of the current profile
- **GIVEN** the iPhone is on Dad, whose accent is Blue
- **WHEN** the user edits Dad, picks Violet and saves
- **THEN** progress bars, links, badges and system controls show Violet without a restart

### Requirement: Sources and logins are shared
The system SHALL show every source and use every login to every profile, and adding, editing or deleting a source SHALL change it for all of them.

#### Scenario: A source added on one profile
- **GIVEN** the profiles Dad and Kids
- **WHEN** Dad adds a source
- **THEN** Kids sees its channels too, without signing in again

### Requirement: What each profile keeps
The system SHALL keep favorites, hidden groups, watch progress, My list, recent searches, recently watched and whether adult content shows per profile and sync them per profile, and SHALL keep the last channel and the sound and subtitle picks per channel per profile on each device. A new profile SHALL start with adult content hidden.

#### Scenario: Favorites apart
- **GIVEN** Dad favorited Sport One and Kids favorited Cartoon Club
- **WHEN** each opens Favorites, or the overlay's Favorites group
- **THEN** Dad sees only Sport One and Kids only Cartoon Club

#### Scenario: Hidden groups apart
- **GIVEN** Kids hid every group but Kids
- **WHEN** Dad opens the channel list
- **THEN** Dad sees every group

#### Scenario: Last channel apart
- **GIVEN** Dad last watched News 24 and Kids last watched Cartoon Club on this Apple TV
- **WHEN** Kids is chosen at launch
- **THEN** Cartoon Club plays

#### Scenario: Language picks apart
- **GIVEN** Dad picked German sound on Sport One on this device
- **WHEN** Kids tunes Sport One on the same device
- **THEN** it starts by Kids's preferences, not with German sound

#### Scenario: Adult content apart
- **GIVEN** Dad turned on Show adult content with the passcode
- **WHEN** the Apple TV switches to Kids, or a new profile is added
- **THEN** that profile hides adult content
- **AND** Dad's other devices show adult content in Dad's profile without asking again

### Requirement: Profiles sync between devices
The system SHALL sync profiles, their names, colors, accents and order through the user's private iCloud account, and SHALL keep which profile is current on each device on that device only. A profile with no accent stored, or one this version does not know, SHALL show Blue.

#### Scenario: A profile added on the iPhone
- **GIVEN** the Apple TV and the iPhone use the same iCloud account
- **WHEN** Kids is added on the iPhone
- **THEN** the Apple TV lists Kids on its next "Who's watching?" screen

#### Scenario: A new device before profiles arrive
- **GIVEN** a device signed into iCloud whose profiles have not synced yet
- **WHEN** the user opens Antenna
- **THEN** it opens as with one profile, and shows the "Who's watching?" screen at the next launch after the profiles arrive

#### Scenario: The same profile made on two devices
- **GIVEN** the first extra profile is added on two devices before they sync
- **WHEN** they sync
- **THEN** each device lists one "Main" profile, not two, and both new profiles

#### Scenario: An accent picked on the iPhone
- **GIVEN** the Apple TV and the iPhone use the same iCloud account and both are on Dad
- **WHEN** Dad's accent is changed to Teal on the iPhone
- **THEN** the Apple TV shows Teal on Dad once the change arrives

#### Scenario: Profiles from before accents
- **GIVEN** profiles made before accents existed
- **WHEN** the user updates Antenna
- **THEN** every profile shows Blue until someone picks another accent
