# Spec Delta

## Purpose

Lets people who watch movies and series on more than one device resume where they stopped, keep one My list, and see the same recent searches on every device on their iCloud account, by storing those records and settling disagreements between devices the same way everywhere.

## ADDED Requirements

### Requirement: Progress is saved and read back
The system SHALL store one progress entry per title holding the latest saved position and length, on a device with or without a network or iCloud, and SHALL store no link, username or password with it.

#### Scenario: Save and read progress
- **GIVEN** a movie or episode from a source, on a device with or without a network or iCloud
- **WHEN** the screen saves the user's position, and later saves a new one
- **THEN** asking for that title's progress returns the latest position and length, and the store holds one entry for the title
- **AND** nothing stored holds a link, username or password

#### Scenario: A failed save
- **GIVEN** a save that fails
- **WHEN** the screen reads progress again
- **THEN** the failed change does not show and no error reaches the screen

#### Scenario: Years of history
- **GIVEN** thousands of titles with progress
- **WHEN** time passes
- **THEN** nothing is pruned by age

### Requirement: Devices that disagree settle on the same answer
The system SHALL resolve copies of progress, My list entries or recent searches that disagree between devices into one answer that is the same on every device.

#### Scenario: Two copies arrive
- **GIVEN** two devices saved different progress for one title, added the same title to My list, or recorded the same search, before syncing
- **WHEN** both copies arrive on a device
- **THEN** the screens see one answer, the same on every device: the most recently saved progress, one My list entry, and one recent search with the latest spelling

#### Scenario: A save after reading
- **GIVEN** a device that read progress from another device with a later clock
- **WHEN** it saves a new position for that title
- **THEN** the new position replaces what it read

#### Scenario: Damaged records from sync
- **GIVEN** damaged or incomplete records arrive from sync
- **WHEN** the screens read
- **THEN** those records are ignored, never deleted, and never crash the app

### Requirement: In progress and watched mean the same everywhere
The system SHALL classify a title as in progress or watched, and pick where it resumes, from the share of its length watched, the same way on every device.

#### Scenario: Thresholds
- **GIVEN** a title with a known length
- **WHEN** the screen asks whether it is in progress or watched, and where to resume
- **THEN** under 2% watched is neither and resumes at the start, from 2% up to 95% is in progress and resumes at the saved position, and 95% or more is watched and resumes at the start

#### Scenario: No known length
- **GIVEN** a title the player reports no length for
- **WHEN** the screen asks
- **THEN** it is never in progress or watched and resumes at the start

#### Scenario: Watching a finished title again
- **GIVEN** a watched title
- **WHEN** the user watches it again and a new position is saved
- **THEN** it is in progress again

### Requirement: A series shows progress for each of its episodes
The system SHALL return the progress of every episode of a series, most recent first, when asked for that series.

#### Scenario: Progress within a series
- **GIVEN** progress saved for a movie and for two episodes of one series
- **WHEN** the screen asks for the progress within that series
- **THEN** it gets both episodes, most recent first, and not the movie

### Requirement: Deleting a source removes its progress and list entries
The system SHALL remove a source's progress and My list entries on every device when the user deletes that source on one device, and SHALL keep recent searches.

#### Scenario: Delete one of two sources
- **GIVEN** progress and My list entries from two sources, and some recent searches
- **WHEN** the user deletes one source on this device
- **THEN** that source's progress and My list entries are removed on every device once synced, the other source's are untouched, and recent searches stay

#### Scenario: Deleted on another device
- **GIVEN** a source deleted on another device
- **WHEN** its removals sync here
- **THEN** this device shows them removed and removes nothing on its own

#### Scenario: Re-adding a source
- **GIVEN** a source that was deleted and added again
- **WHEN** the screen asks for its progress
- **THEN** it starts fresh

### Requirement: Progress waits for a source that has not synced yet
The system SHALL keep progress and My list entries that arrive before their source or title list, so the history is there once the source arrives.

#### Scenario: Records before their source
- **GIVEN** progress and My list entries arrived from iCloud before the source they belong to
- **WHEN** the screens read them, or save progress for another title
- **THEN** nothing is thrown away, so the user's history is there once the source arrives

#### Scenario: Login not yet synced
- **GIVEN** a source whose login has not synced yet
- **WHEN** the screen asks for its progress and list entries
- **THEN** they are returned

### Requirement: Add and remove from My list
The system SHALL add a title to My list and remove it again, including every duplicate copy from another device.

#### Scenario: Add then remove
- **GIVEN** a title from a source that is not in My list
- **WHEN** the screen adds it, and later removes it
- **THEN** the title is in My list after the first and gone after the second, including any duplicate copies from another device

### Requirement: My list shows movies and series separately
The system SHALL return My list movies and My list series as separate lists, most recently added first, keeping entries of other kinds out of both without deleting them.

#### Scenario: Ask by kind
- **GIVEN** My list holds movies, series and entries of other kinds
- **WHEN** the screen asks for the movies, or for the series
- **THEN** each list holds only that kind, most recently added first, and entries of other kinds are kept but appear in neither

### Requirement: Recent searches stay short and tidy
The system SHALL keep the ten newest recent searches, newest first, treating searches that differ only in case or accents as one, ignoring blank searches and cutting long ones to 100 characters.

#### Scenario: Record a search
- **GIVEN** the user has searched before
- **WHEN** a new search is recorded
- **THEN** recent searches list it first, treat the same words in different case or accents as one search keeping the latest spelling, ignore blank searches, cut very long ones to 100 characters, and keep only the ten newest

### Requirement: Recent searches from an earlier build carry over
The system SHALL move recent searches that an earlier build kept on the device into the synced list once, in their old order, merged with any from other devices and capped at ten.

#### Scenario: First start with the synced store
- **GIVEN** a device that kept recent searches locally from an earlier build
- **WHEN** the app starts with this store for the first time
- **THEN** those searches join the synced list in their old order, merged with any that arrived from other devices and capped at ten
- **AND** they are moved only once, even if the app was killed halfway

### Requirement: Changes from another device show up without reopening the screen
The system SHALL tell every screen watching the store when anything is saved, on this device or arriving from another.

#### Scenario: A change arrives
- **GIVEN** a screen is watching the store for changes
- **WHEN** anything is saved, on this device or arriving from another
- **THEN** the screen is told, reading again shows the change, and every screen watching is told

### Requirement: Progress follows the iCloud account
The system SHALL show the same progress, My list and recent searches on every online device signed in to one iCloud account, and SHALL keep a signed-out device working with its own data.

#### Scenario: Three devices and a signed-out iPad
- **GIVEN** an iPhone, an Apple TV and a Mac on one iCloud account, and an iPad signed out of iCloud
- **WHEN** a film is half watched on the iPhone, a title added to My list and a search typed, and the devices are online
- **THEN** the Apple TV and the Mac show the same progress, list and recent searches once they are online, including writes the iPhone made offline after it reconnects
- **AND** the iPad keeps working with its own data and syncs nothing

#### Scenario: Apple TV profiles
- **GIVEN** an Apple TV with several profiles
- **WHEN** each profile watches and searches
- **THEN** each profile has its own progress, list and searches
