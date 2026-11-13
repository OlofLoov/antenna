# Spec Delta

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Favorites list is read-only
**Reason**: Live on iPhone, iPad and Mac has a star for the playing channel, and this change adds a menu, a swipe and a full-screen star; the Favorites tab the requirement described is gone.
**Migration**: Favorites are added and removed through "Favorite from a channel's menu", "Swipe a channel into Favorites", "Favorite from full screen" and `live-tv-on-iphone-ipad-mac` "Star a channel".
