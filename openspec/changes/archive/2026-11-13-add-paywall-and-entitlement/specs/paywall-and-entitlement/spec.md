# Spec Delta

## Purpose

Lets anyone who installs Antenna unlock it with one App Store purchase that works on every device on their Apple Account and for their Family Sharing group, restore it on a new device, and keep their data when access ends.

## ADDED Requirements

### Requirement: A purchase counts while it is paid up
The system SHALL treat the app as unlocked by a Lifetime purchase for good and by a Yearly subscription until its end date or through the App Store's billing grace period, and SHALL give a refunded purchase no weight.

#### Scenario: Decide from purchase records
- **GIVEN** purchase records for this Apple Account
- **WHEN** the app decides whether it is unlocked
- **THEN** Lifetime unlocks it for good
- **AND** Yearly unlocks it until its end date or through the App Store's billing grace period (the days Apple keeps a subscription active while it retries a failed payment)
- **AND** a refunded purchase counts for nothing, and owning both counts as Lifetime

#### Scenario: Offline with a remembered Yearly purchase
- **GIVEN** a remembered Yearly purchase and no network
- **WHEN** the end date passes
- **THEN** the app stays open up to 16 days past the end date, then locks

#### Scenario: The device clock runs ahead
- **GIVEN** a remembered Yearly purchase and a device clock set far ahead
- **WHEN** the app launches before the App Store answers
- **THEN** the app may lock early, until the App Store answers

### Requirement: Nothing works before the app is unlocked
The system SHALL show only the paywall until the app is unlocked, and SHALL contact no source, playlist or guide before then.

#### Scenario: First launch without a purchase
- **GIVEN** a device with no purchase on its Apple Account
- **WHEN** the app launches
- **THEN** the paywall is the only thing shown, and no source, playlist or guide is contacted

#### Scenario: A source waiting for its login
- **GIVEN** a user whose only source is still waiting for its login
- **WHEN** the app launches without a purchase
- **THEN** the user sees the same paywall as anyone else

### Requirement: A buyer goes straight in
The system SHALL open a device that has already seen a valid purchase straight to onboarding or the app, with no network and without showing the paywall.

#### Scenario: Launch offline after buying
- **GIVEN** a device that has already seen a valid purchase on this Apple Account
- **WHEN** the app launches without a network
- **THEN** onboarding or the app appears without the paywall ever showing

#### Scenario: The App Store already knows the purchase
- **GIVEN** a reinstall, a second device or a family member whose purchase the App Store already knows
- **WHEN** the app launches and the App Store answers slowly
- **THEN** the app opens without a tap and the paywall does not flash first

### Requirement: Prices come from the App Store
The system SHALL show each product with the price the App Store gives for the user's region, exactly as given, and describe a renewing subscription and any introductory offer.

#### Scenario: The products load
- **GIVEN** the App Store answers with the two products
- **WHEN** the paywall shows
- **THEN** each product shows the App Store's price for the user's region, exactly as given
- **AND** Yearly says it is per year and renews until canceled
- **AND** an introductory offer is described with its price and length

### Requirement: Buy once and you're in
The system SHALL leave the paywall for onboarding or the app as soon as the App Store confirms a purchase of either product.

#### Scenario: A confirmed purchase
- **GIVEN** the paywall with prices shown
- **WHEN** the user buys either product and the App Store confirms it
- **THEN** the paywall leaves and onboarding or the app appears

#### Scenario: Canceled or failed
- **WHEN** the user cancels a purchase, or it fails
- **THEN** a cancel leaves the paywall as it was, and a failure adds a line asking the user to try again

#### Scenario: One at a time
- **GIVEN** a purchase or restore running
- **WHEN** the user tries to start another
- **THEN** nothing else starts until it finishes

#### Scenario: Purchases turned off
- **GIVEN** purchases turned off by Screen Time
- **WHEN** the paywall shows
- **THEN** it says so and only Restore purchase works

### Requirement: Waiting for a parent's approval
The system SHALL say a purchase is waiting for approval and SHALL unlock without a tap when the approval arrives, also after a relaunch.

#### Scenario: Ask to Buy
- **GIVEN** a family member under Ask to Buy
- **WHEN** they buy a product and the purchase waits for approval
- **THEN** the paywall says it is waiting for approval
- **AND** the app unlocks without a tap as soon as the approval arrives, also when that happens after a relaunch

### Requirement: Restore your purchase
The system SHALL let the user restore a purchase made on another device or by a family member, and SHALL say what was found before opening the app.

#### Scenario: Restore finds a purchase
- **GIVEN** a purchase made on another device or by a family member
- **WHEN** the user chooses Restore purchase
- **THEN** the paywall says "Welcome back", names what was found and whether it came through Family Sharing, and Continue opens the app

#### Scenario: Restore finds nothing
- **WHEN** Restore purchase finds no purchase
- **THEN** the paywall says so and suggests checking purchase sharing in Family Sharing

#### Scenario: Restore finds an ended subscription
- **WHEN** Restore purchase finds only an ended subscription
- **THEN** the paywall says when it ended and shows the products

### Requirement: The App Store cannot be reached
The system SHALL tell the user when the App Store cannot be reached and nothing is remembered, offer Try again and Restore purchase, and replace that panel with the products when a late answer arrives.

#### Scenario: No network and nothing remembered
- **GIVEN** no network or an App Store that does not answer, and no remembered purchase
- **WHEN** the paywall loads
- **THEN** a panel says the App Store cannot be reached, with Try again and Restore purchase
- **AND** a late answer replaces the panel with the products

#### Scenario: Not sold in this region
- **WHEN** Antenna is not sold in the user's region
- **THEN** the panel says so and offers no Try again

### Requirement: When access ends, the app locks and keeps your data
The system SHALL lock the app at the next open or return after a subscription ends, a purchase is refunded or Family Sharing stops sharing it, and SHALL keep every source, favorite and login so that buying or restoring brings them back.

#### Scenario: Access ended
- **GIVEN** an unlocked app with sources, favorites and saved logins, and the App Store has reported that the subscription ended, the purchase was refunded, or Family Sharing stopped sharing it
- **WHEN** the app is opened or brought back to the front
- **THEN** playback does not resume, no source is contacted any more, and the paywall says "Antenna is locked again" with the reason and date
- **AND** it stays that way across relaunches and offline
- **AND** buying or restoring brings back everything as it was

#### Scenario: Access ends during a programme
- **GIVEN** a programme playing
- **WHEN** access ends
- **THEN** it keeps playing and the app locks at the next return to the app, never mid-programme

#### Scenario: An empty answer from the App Store
- **GIVEN** a remembered purchase and a user signed out of the Apple Account, or a new Apple TV that has not synced
- **WHEN** the App Store first answers with nothing
- **THEN** the app stays unlocked and locks only if the next launch also finds nothing

#### Scenario: A refund while the app was closed
- **WHEN** a purchase is refunded while the app is closed
- **THEN** it may take one more launch before the app locks

### Requirement: Honest paywall wording
The system SHALL name no provider, channel count or content on the paywall, SHALL say Antenna includes no channels, and SHALL link to the Terms of Use and Privacy Policy.

#### Scenario: Read the paywall
- **GIVEN** the paywall on any platform
- **WHEN** the user reads it
- **THEN** it names no provider, channel count or content, says Antenna includes no channels, and links to the Terms of Use and Privacy Policy
- **AND** on Apple TV, where there is no browser, the addresses are shown as text

### Requirement: One purchase on every device
The system SHALL unlock Antenna on every iPhone, iPad, Mac and Apple TV on the same Apple Account after one purchase, without buying or restoring again.

#### Scenario: Open on another device
- **GIVEN** a purchase on an iPhone
- **WHEN** the same Apple Account opens Antenna on an iPad, Mac or Apple TV
- **THEN** the app opens there without buying or restoring

### Requirement: Family members unlock without buying
The system SHALL unlock Antenna for every member of the buyer's Family Sharing group and SHALL never count devices or members.

#### Scenario: A family member opens Antenna
- **GIVEN** a purchase by the organizer of a Family Sharing group
- **WHEN** another member of the group opens Antenna
- **THEN** the app opens without a purchase, and nothing in the app counts devices or members
