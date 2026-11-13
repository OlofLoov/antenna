# favorites Specification

## Purpose
Keeps the user's short list of favorite channels in their own iCloud account and shows it in a Favorites tab on iPhone, iPad and Mac, so it survives source reloads. On those devices the user adds and removes favorites from a channel's menu, a swipe on the channel list or the player's star. Apple TV does not show the list. It serves the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

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

### Requirement: Apple TV shows no favorites
The system SHALL show no Favorites screen on Apple TV. Favorites synced from other devices stay stored there and are not changed.

#### Scenario: Favorites from an iPhone
- **GIVEN** favorites saved on an iPhone signed into the same iCloud account
- **WHEN** the user opens Antenna on Apple TV
- **THEN** no tab or screen lists them, and they are still listed on the iPhone

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
