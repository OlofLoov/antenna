# favorites Specification

## Purpose
Keeps the user's short list of favorite channels in their own iCloud account and shows it in a Favorites tab on iPhone, iPad and Mac, so it survives source reloads. On those devices the user adds and removes favorites from a channel's menu, a swipe on the channel list or the player's star. On Apple TV the list is the Favorites group of the channel overlay, changed by holding select on a channel or with the overlay's star. It serves the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

## Requirements

### Requirement: Empty state
The system SHALL show a "No favorites" view with the line "Favorites sync across your devices." in the Favorites tab when the user has no favorites.

#### Scenario: No favorites
- **GIVEN** no favorites
- **WHEN** the Favorites tab is shown
- **THEN** the "No favorites" view is shown and no list is shown

### Requirement: List order
The system SHALL list favorites by their saved sort order, each row showing only its channel id, not the channel's name or logo.

#### Scenario: Out-of-order favorites
- **GIVEN** favorites with sort order 2, 0, 1
- **WHEN** the Favorites tab is shown
- **THEN** three rows appear in the order 0, 1, 2, each showing its channel id

#### Scenario: Duplicates and equal sort orders
- **GIVEN** two favorites for the same channel, or two favorites with the same sort order
- **WHEN** the Favorites tab is shown
- **THEN** duplicates are listed twice and favorites with equal sort order appear in an unspecified relative order

#### Scenario: Source deleted
- **GIVEN** a favorite whose source was deleted
- **WHEN** the Favorites tab is shown
- **THEN** it stays in the list as a bare channel id, because deleting a source keeps its favorites

### Requirement: Favorites reference stable channel ids
The system SHALL produce the same channel id for a channel when its source reloads with unchanged content, for M3U entries with a non-empty `tvg-id` and for Xtream streams.

#### Scenario: Reload with unchanged content
- **GIVEN** a favorite for a channel from an M3U entry with a non-empty `tvg-id`, or from an Xtream stream
- **WHEN** the same source is reloaded with unchanged content
- **THEN** the same channel id is produced, so the favorite still refers to it

#### Scenario: Positional M3U ids
- **GIVEN** a favorite for an M3U entry without `tvg-id`
- **WHEN** the playlist order changes
- **THEN** the favorite no longer refers to that channel, because those ids are positional

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

### Requirement: Favorite from a channel's menu
The system SHALL offer "Add to Favorites" for a channel that is not a favorite, and "Remove from Favorites" for one that is, in the menu that opens when the user touches and holds a channel, or right-clicks it on a Mac, in the Live channel list and in the Guide's channel column on iPhone, iPad and Mac. Choosing it SHALL add or remove the channel for the current profile without playing it.

#### Scenario: Adding from the Live list
- **GIVEN** a channel that is not a favorite and does not play
- **WHEN** the user touches and holds its row in Live and chooses "Add to Favorites"
- **THEN** the channel is listed in the Favorites group, the Favorites count goes up by one, and the channel that was playing keeps playing

#### Scenario: Removing from the menu
- **GIVEN** a channel that is a favorite
- **WHEN** the user opens its menu
- **THEN** the menu says "Remove from Favorites", and choosing it takes the channel out of Favorites

#### Scenario: The Guide's channel column
- **GIVEN** the Guide on iPhone, iPad or Mac
- **WHEN** the user touches and holds a channel's name, or right-clicks it on a Mac, and chooses "Add to Favorites"
- **THEN** the channel is a favorite and the Guide stays where it was

#### Scenario: Multi-view on a Mac
- **GIVEN** a Mac
- **WHEN** the user right-clicks a channel in the Live list
- **THEN** the menu lists the favorite item and, when multi-view can take the channel, its multi-view item

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the user focuses a channel in the Live list or the Guide's channel column
- **THEN** the actions offered include "Add to Favorites" or "Remove from Favorites", whichever the channel's state calls for

### Requirement: Swipe a channel into Favorites
The system SHALL show the favorite action when the user swipes a channel row in the Live list to the right on iPhone and iPad, and a full swipe SHALL run it.

#### Scenario: Full swipe
- **GIVEN** a channel that is not a favorite
- **WHEN** the user swipes its row all the way to the right
- **THEN** the channel is added to Favorites and the row slides back

#### Scenario: Swiping in Favorites
- **GIVEN** the Favorites group is open
- **WHEN** the user swipes a row to the right and taps "Remove from Favorites"
- **THEN** the row leaves the list and the Favorites count goes down by one

### Requirement: Favorite from full screen
The system SHALL show a star among the player controls while the picture fills the screen, filled when the playing channel is a favorite, and a tap SHALL add or remove that channel.

#### Scenario: iPhone turned sideways
- **GIVEN** a channel that is not a favorite plays full screen on an iPhone held sideways
- **WHEN** the user taps the picture and then the star
- **THEN** the star fills and the channel is in Favorites when full screen ends

#### Scenario: Not full screen
- **GIVEN** the picture sits above the list
- **WHEN** the controls show
- **THEN** they have no star, because the now-playing line or the details panel already has one

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
