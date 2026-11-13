# Spec Delta

## Purpose

Lets anyone whose provider sends hundreds of channel groups, and parents who share the TV with children, hide, lock, rename and reorder groups and build their own from several playlists, with every change synced to their other devices.

## ADDED Requirements

### Requirement: Hide groups you never watch
The system SHALL remove a hidden group and its channels from the channel lists, keep it on the Groups screen marked hidden, keep its favorite channels in Favorites, and SHALL NOT change any other channel's number.

#### Scenario: A hidden provider group
- **GIVEN** the user has hidden one of the provider's groups
- **WHEN** they look through the channel lists
- **THEN** that group and its channels are gone
- **AND** the Groups screen still lists it marked hidden
- **AND** its channels that are favorites stay in Favorites, and no other channel's number changes

#### Scenario: Searching hidden groups
- **GIVEN** a hidden group
- **WHEN** the user searches
- **THEN** its channels are left out unless the user has turned on searching hidden groups on this device

### Requirement: Locked channels stay out of reach
The system SHALL show a lock on a locked group while locks are closed on this device, and SHALL NOT show, count, number or play any of its channels, while every other channel keeps its number.

#### Scenario: Browsing with locks closed
- **GIVEN** a locked group and locks closed on this device
- **WHEN** the user browses, searches, opens the guide, flips channels or types a channel number
- **THEN** the group shows a lock
- **AND** none of its channels is shown, counted, numbered or played
- **AND** every other channel keeps its number

#### Scenario: A locked channel in Favorites or an own group
- **GIVEN** a locked channel that is also a favorite or in the user's own group
- **WHEN** locks are closed
- **THEN** it stays out of reach everywhere

#### Scenario: Play requests from outside the lists
- **GIVEN** locks are closed
- **WHEN** the channel restored at launch, the lock screen or Control Center asks to play a locked channel
- **THEN** the passcode prompt shows instead

### Requirement: Give a group your own name
The system SHALL show a group's new name on every screen once the user renames it, keeping its favorites, order and whether it is being watched.

#### Scenario: Renaming
- **GIVEN** a provider's group or one of the user's own groups
- **WHEN** the user gives it a new name
- **THEN** every screen shows the new name
- **AND** favorites, order and the group being watched stay as they were

#### Scenario: An empty name
- **GIVEN** a group is being renamed
- **WHEN** the user clears the name
- **THEN** a provider group gets the provider's name back, and the user's own group refuses it

### Requirement: Put groups in your order
The system SHALL list groups on every screen in the order the user sets, with Favorites and All channels first, and keep channels inside a provider's group in provider numbering, then playlist order.

#### Scenario: Moving a group
- **GIVEN** the Groups screen
- **WHEN** the user moves a group, by dragging on iPhone, iPad and Mac, or with Move up and Move down on Apple TV
- **THEN** every screen lists groups in the new order with Favorites and All channels first
- **AND** the channels inside a provider's group keep the provider's numbering, then playlist order

### Requirement: Lock a group with a passcode
The system SHALL ask for four digits twice the first time the user locks a group, lock it on every device of the account while leaving it open on this device for now, and SHALL NOT save, sync or log the digits.

#### Scenario: The first lock
- **GIVEN** no passcode has been set on this iCloud account
- **WHEN** the user locks a group and types the same four digits twice
- **THEN** the group is locked on every device of the account and stays open on this device for now
- **AND** the digits are not saved, synced or written to any log

#### Scenario: Two different entries
- **GIVEN** the user is setting the first passcode
- **WHEN** the two entries differ
- **THEN** nothing is locked and the user starts again

#### Scenario: Two offline devices
- **GIVEN** two offline devices each set a first passcode
- **WHEN** they sync
- **THEN** the earlier one wins, and the other device says the passcode was changed elsewhere

#### Scenario: Changing the passcode
- **GIVEN** a passcode is set
- **WHEN** the user changes it
- **THEN** they enter the current passcode first

### Requirement: Unlock with the passcode
The system SHALL show the passcode prompt when the user picks a locked group with locks closed, and the right passcode SHALL open the locks on this device and show the group's channels while playback continues.

#### Scenario: Picking a locked group
- **GIVEN** locks closed on this device and a locked group
- **WHEN** the user picks that group in a channel list
- **THEN** the passcode prompt appears
- **AND** the right passcode opens the locks on this device and shows the group's channels while whatever is playing keeps playing

#### Scenario: Other places that ask first
- **GIVEN** locks are closed and a group is locked
- **WHEN** the user opens the Groups screen, opens the guide on a locked group, or locks another group
- **THEN** the passcode prompt comes first

#### Scenario: The passcode has not synced yet
- **GIVEN** a group was locked on another device and the passcode has not reached this one
- **WHEN** the prompt shows
- **THEN** it says it is waiting for iCloud and shows no digit keys

### Requirement: Guessing the passcode is slow
The system SHALL refuse input for a while after several wrong passcodes in a row, lengthen the wait with each further run of wrong entries, and SHALL NOT cut the wait short when the app is closed and reopened.

#### Scenario: Repeated wrong entries
- **GIVEN** the passcode prompt
- **WHEN** a wrong passcode is entered several times in a row
- **THEN** the prompt refuses input for a while
- **AND** each further run of wrong entries makes the wait longer
- **AND** closing and reopening the app does not cut it short

### Requirement: Locks close again on their own
The system SHALL close the locks on this device on Lock now, when the app is reopened, and after the app or an idle Apple TV has been left alone for a while.

#### Scenario: Closing the locks
- **GIVEN** the user has opened the locks on this device
- **WHEN** they choose Lock now, the app is reopened, or the app or an idle Apple TV has been left alone for a while
- **THEN** the locks close and locked channels are out of reach again

### Requirement: Reset a forgotten passcode
The system SHALL let the user on iPhone, iPad or Mac set a new passcode after confirming with the device's own passcode, login password, Face ID or Touch ID, keep every lock, and open the locks there, and SHALL offer no reset on Apple TV.

#### Scenario: Forgot passcode on iPhone, iPad or Mac
- **GIVEN** the passcode prompt on iPhone, iPad or Mac
- **WHEN** the user chooses Forgot passcode and confirms with the device's passcode or Mac login password, Face ID or Touch ID
- **THEN** they set a new passcode
- **AND** every locked group stays locked and the locks open on this device

#### Scenario: Apple TV
- **GIVEN** the passcode prompt on Apple TV
- **WHEN** the user looks for a reset
- **THEN** the prompt says to reset it on an iPhone, iPad or Mac and offers no reset

### Requirement: A channel that gets locked stops playing
The system SHALL pause a playing channel and cover it with the passcode prompt when it becomes locked while locks are closed, resume on the right passcode, and on closing the prompt switch to the first channel the user may watch or close the player.

#### Scenario: Locked while playing
- **GIVEN** a channel is playing and locks are closed
- **WHEN** that channel becomes locked, from this device, from another device, or because the locks closed
- **THEN** playback pauses and the passcode prompt covers the video
- **AND** the right passcode resumes it

#### Scenario: Closing the prompt
- **GIVEN** the prompt covers a locked channel
- **WHEN** the user closes it
- **THEN** the first channel the user may watch plays, or the player closes when there is none

#### Scenario: The current group disappears
- **GIVEN** the user is watching from a group
- **WHEN** that group is hidden, locked or deleted
- **THEN** the current group falls back to the first visible unlocked group, else Favorites, never one that needs the prompt

### Requirement: Build your own group from any playlist
The system SHALL show a group the user creates from channels of any playlists like any other group in the channel lists and the guide, in the user's chosen order, leaving out channels that are not loaded.

#### Scenario: A group from two playlists
- **GIVEN** channels from two playlists
- **WHEN** the user creates a group, names it and picks channels from both playlists
- **THEN** the channel lists and the guide show it like any other group, with its channels in the order the user chose
- **AND** any channel that is not currently loaded is left out

#### Scenario: Deleting a playlist
- **GIVEN** the user's own group holds channels from a playlist
- **WHEN** that playlist is deleted
- **THEN** its channels leave the user's group, and the group stays

### Requirement: Settings for groups that are gone
The system SHALL list settings for groups that no longer exist in any loaded playlist, each with Remove, and SHALL neither apply nor list settings for playlists that are loading, failed or waiting for their login.

#### Scenario: The provider renames a category
- **GIVEN** the user had settings for a provider group
- **WHEN** the provider renames the category
- **THEN** the old settings appear in the list of groups that no longer exist, with Remove
- **AND** the renamed group starts with no settings

#### Scenario: A playlist not loaded
- **GIVEN** a playlist is still loading, failed, or waiting for its login to sync
- **WHEN** the Groups screen shows
- **THEN** its groups are absent, and its group settings are neither applied nor offered for removal

### Requirement: Changes follow you to every device
The system SHALL sync hidden, renamed, locked and user-made groups to every device on the same iCloud account, and the locks on each device SHALL stay closed until the passcode is entered there.

#### Scenario: A second device
- **GIVEN** the user hides one group, renames another, locks a third and creates their own group on one device
- **WHEN** their other device, signed into the same iCloud account, is online
- **THEN** it shows all four changes
- **AND** its locks stay closed until the passcode is entered there

#### Scenario: Offline or signed out
- **GIVEN** the device is offline or signed out of iCloud
- **WHEN** the user changes group settings
- **THEN** the changes apply on this device and sync once it is back

#### Scenario: The subscription ends
- **GIVEN** the user has group settings
- **WHEN** the subscription ends
- **THEN** the paywall replaces these screens and every setting is kept
