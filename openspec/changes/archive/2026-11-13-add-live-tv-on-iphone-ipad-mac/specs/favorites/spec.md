# Spec Delta

## MODIFIED Requirements

### Requirement: Favorites sync between devices
The system SHALL sync favorites through the user's private iCloud account to every device signed into it. This is checked by hand on two devices.

#### Scenario: Second device
- **GIVEN** a favorite saved on device A
- **WHEN** device B, signed into the same iCloud account, is online
- **THEN** the favorite appears in device B's Favorites group in Live

#### Scenario: Apple TV as the second device
- **GIVEN** a favorite saved on an iPhone, iPad or Mac
- **WHEN** an Apple TV signed into the same iCloud account is online
- **THEN** the favorite appears in the Favorites group of its channel overlay, and one added on the Apple TV appears on the other device

## REMOVED Requirements

### Requirement: Empty state
**Reason**: On iPhone, iPad and Mac the Favorites tab becomes the Favorites group inside Live, which has its own empty message.
**Migration**: See `live-tv-on-iphone-ipad-mac`, requirement "Pick a group", scenario "Empty Favorites".

### Requirement: List order
**Reason**: The Favorites tab and its bare channel-id rows go away. The Favorites group in Live lists full channel rows.
**Migration**: Order and duplicates follow `channel-catalogue`, requirements "Favorites resolve to loaded channels" and "One row per favorite channel".
