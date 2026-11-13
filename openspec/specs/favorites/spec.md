# favorites Specification

## Purpose
Keeps the user's short list of favorite channels in their own iCloud account and shows it in a Favorites tab on iPhone, iPad and Mac, so it survives source reloads. On those devices the user adds and removes favorites from a channel's menu, a swipe on the channel list or the player's star. On Apple TV the list is the Favorites group of the channel overlay, changed by holding select on a channel or with the overlay's star. It serves the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

## Requirements

### Requirement: Favorites reference stable channel ids
The system SHALL produce the same channel id for a channel when its source reloads with unchanged content, for M3U entries and for Xtream streams. For M3U entries the id SHALL also stay the same when the links, the login in them or the order of entries change, and SHALL never hold the stream link.

#### Scenario: Reload with unchanged content
- **GIVEN** a favorite for a channel from an M3U entry, or from an Xtream stream
- **WHEN** the same source is reloaded with unchanged content
- **THEN** the same channel id is produced, so the favorite still refers to it

#### Scenario: Positional M3U ids
- **GIVEN** a favorite for an M3U entry, with or without `tvg-id`
- **WHEN** the playlist order changes, or the provider changes the password in every link
- **THEN** the favorite still refers to that channel, because M3U ids no longer depend on position or link

#### Scenario: The synced favorite holds no login
- **GIVEN** an M3U playlist whose links carry the provider's username and password
- **WHEN** the user adds one of its channels to Favorites
- **THEN** the favorite that syncs through iCloud holds neither the link, the username nor the password

### Requirement: Favorites sync between devices
The system SHALL sync favorites through the user's private iCloud account to every device signed into it, each favorite with its profile. This is checked by hand on two devices.

#### Scenario: Second device
- **GIVEN** a favorite saved on device A
- **WHEN** device B, an iPhone, iPad or Mac signed into the same iCloud account, is online
- **THEN** the favorite appears in device B's Favorites group in Live

#### Scenario: Another profile on the second device
- **GIVEN** Dad saved a favorite on device A
- **WHEN** device B is on Kids
- **THEN** the favorite is not in device B's Favorites group until Dad is chosen there

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

### Requirement: Favorites belong to a profile
The system SHALL keep each favorite for the profile that added it, list only the current profile's favorites, and SHALL count favorites made before the user had more than one profile as the first profile's.

#### Scenario: Two profiles
- **GIVEN** Dad favorited Sport One and Kids favorited Cartoon Club
- **WHEN** Kids opens the Favorites group
- **THEN** only Cartoon Club is listed

#### Scenario: Favorites from before profiles
- **GIVEN** favorites saved while there was one profile
- **WHEN** the user adds a second profile
- **THEN** those favorites stay with the first profile, now named "Main", and the new profile has none

### Requirement: Favorites saved before the id change carry over
The system SHALL rewrite each favorite and own-group channel saved with an M3U channel's earlier id to its new id the first time its playlist loads on a device, keeping its place, profile and group, and SHALL keep a channel that ends up listed twice in Favorites or one own group only once.

#### Scenario: First launch after the update
- **GIVEN** a favorite of an M3U channel saved by an earlier version, whose id holds the stream link
- **WHEN** its playlist loads
- **THEN** the favorite stays in Favorites at the same place, and the stored favorite no longer holds the link

#### Scenario: Another device
- **GIVEN** the favorite was rewritten on one device
- **WHEN** a second device running this version syncs it and loads the same playlist
- **THEN** the favorite is listed once and the second device writes nothing more for it

#### Scenario: Two devices rewrite at once
- **GIVEN** two devices that rewrite the same favorite before either sees the other's change, or a favorite saved twice with the old and the new id
- **WHEN** the changes sync
- **THEN** the channel is listed once in Favorites

#### Scenario: Playlist not loaded on this device
- **GIVEN** a favorite with an earlier id whose playlist has not loaded on this device, fails to load, or was deleted
- **WHEN** Favorites is shown
- **THEN** the favorite is kept as it is, and is rewritten when its playlist next loads

#### Scenario: A channel the playlist no longer lists
- **GIVEN** a favorite with an earlier id whose channel is no longer in the playlist
- **WHEN** the playlist loads
- **THEN** the favorite is kept unchanged, as any favorite of a missing channel is

#### Scenario: Own groups
- **GIVEN** a channel in one of the user's own groups saved with an earlier id
- **WHEN** its playlist loads
- **THEN** it stays in that group at the same place, under its new id
