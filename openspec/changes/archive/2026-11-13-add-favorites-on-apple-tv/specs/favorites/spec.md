## ADDED Requirements

### Requirement: Favorites on Apple TV
The system SHALL list the current profile's favorites on Apple TV as the Favorites group of the channel overlay, in the order the Favorites group has on iPhone, iPad and Mac, leaving out channels in locked groups, and SHALL play a favorite when the user selects it. The Guide on Apple TV SHALL show the Favorites rows when the user last tuned from Favorites.

#### Scenario: Favorites from an iPhone
- **GIVEN** favorites saved on an iPhone signed into the same iCloud account and the same profile
- **WHEN** the user opens the channel overlay on Apple TV
- **THEN** Favorites is the first group, with the same channels in the same order as on the iPhone

#### Scenario: Playing a favorite
- **GIVEN** Favorites is shown in the overlay
- **WHEN** the user selects a channel in it
- **THEN** that channel plays and channel up and down move through Favorites

#### Scenario: Another profile
- **GIVEN** two profiles with different favorites
- **WHEN** the user switches profile on Apple TV and opens the overlay
- **THEN** Favorites lists only the current profile's favorites

#### Scenario: A favorite in a locked group
- **GIVEN** a favorite whose channel is in a locked group and the locks are closed
- **WHEN** the overlay opens
- **THEN** Favorites leaves that channel out and its count does not include it

#### Scenario: The Guide after tuning from Favorites
- **GIVEN** the user tuned a channel from Favorites in the overlay
- **WHEN** the user opens the Guide tab
- **THEN** the grid shows one row per favorite in the Favorites order

#### Scenario: No favorites
- **GIVEN** the current profile has no favorites
- **WHEN** Favorites is shown in the overlay
- **THEN** the group is still listed with a count of zero and the channel column says to hold select on a channel to add it

### Requirement: Hold select to favorite on Apple TV
The system SHALL open a menu with "Add to Favorites" for a channel that is not a favorite, and "Remove from Favorites" for one that is, when the user holds select on a channel row in the Apple TV channel overlay or on the Apple TV Guide grid. In the Guide the menu SHALL act on the highlighted programme's channel. Choosing it SHALL add or remove the channel for the current profile without tuning and without taking the user off the screen they are on.

#### Scenario: Adding from the overlay
- **GIVEN** the overlay is open on a group other than Favorites, with a channel highlighted that is not a favorite
- **WHEN** the user holds select and chooses "Add to Favorites"
- **THEN** the channel is a favorite, the Favorites count goes up by one, the playing channel keeps playing and the same row stays highlighted

#### Scenario: Removing while viewing Favorites
- **GIVEN** Favorites is shown with a channel highlighted
- **WHEN** the user holds select and chooses "Remove from Favorites"
- **THEN** the channel leaves the list and the highlight moves to a neighbor, or to the Favorites group when none is left

#### Scenario: A short press still tunes
- **GIVEN** a channel row is highlighted in the overlay
- **WHEN** the user presses select briefly
- **THEN** the channel plays as before and no menu opens

#### Scenario: The Guide grid
- **GIVEN** the Guide grid on Apple TV with a programme highlighted
- **WHEN** the user holds select and chooses "Add to Favorites"
- **THEN** that programme's channel is a favorite, nothing is tuned and the same programme stays highlighted

#### Scenario: Removing the last row in the Guide
- **GIVEN** the Guide shows Favorites with one row
- **WHEN** the user removes that channel from Favorites by holding select
- **THEN** the grid says the group has no channels and the highlight moves to the day chips

#### Scenario: Menu closes the menu
- **GIVEN** the menu is open
- **WHEN** the user presses Menu
- **THEN** the menu closes and nothing changes

#### Scenario: VoiceOver on Apple TV
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a channel row in the overlay or to the Guide grid
- **THEN** the actions offered include "Add to Favorites" or "Remove from Favorites", whichever the channel's state calls for

## MODIFIED Requirements

### Requirement: Favorites sync between devices
The system SHALL sync favorites through the user's private iCloud account to every device signed into it. This is checked by hand on two devices.

#### Scenario: Second device
- **GIVEN** a favorite saved on device A
- **WHEN** device B, an iPhone, iPad or Mac signed into the same iCloud account, is online
- **THEN** the favorite appears in device B's Favorites tab

#### Scenario: Apple TV as the second device
- **GIVEN** a favorite saved on an iPhone, iPad or Mac
- **WHEN** an Apple TV signed into the same iCloud account is online
- **THEN** the favorite appears in the Favorites group of its channel overlay, and one added on the Apple TV appears on the other device

## REMOVED Requirements

### Requirement: Apple TV shows no favorites
**Reason**: Apple TV lists favorites in the channel overlay and changes them from the overlay's star and from a held select in the overlay and the Guide.
**Migration**: "Favorites on Apple TV" and "Hold select to favorite on Apple TV" describe favorites on Apple TV.
