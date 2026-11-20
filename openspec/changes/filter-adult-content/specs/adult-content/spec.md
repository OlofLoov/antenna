# Spec Delta

## ADDED Requirements

### Requirement: Adult groups are found by name
The system SHALL treat a channel group, or a movie or series category, as adult when its name holds an adult word or phrase as a whole word, in English, Swedish, German, Spanish, French, Portuguese or Arabic or a common provider spelling, ignoring case and accents, and SHALL NOT treat a name as adult when a harmless phrase such as "Adult Swim" or "Young adult" is the only reason.

#### Scenario: Provider spellings
- **GIVEN** groups named "XXX", "VIP | XXX ADULTS", "For adults", "(18+)", "+18", "Erotik", "Vuxen", "Erwachsene", "Adultos", "Adultes" and "للبالغين"
- **WHEN** the channels load
- **THEN** each of these groups is adult

#### Scenario: Harmless names
- **GIVEN** groups named "Adult Swim", "Young Adult", "Adult Contemporary", "Junge Erwachsene", "Adulthood", "XXL Sport" and "Sky Sports 18"
- **WHEN** the channels load
- **THEN** none of them is adult

#### Scenario: A harmless phrase next to an adult word
- **GIVEN** a group named "Adult Swim XXX"
- **WHEN** the channels load
- **THEN** it is adult

### Requirement: The provider's adult flag counts
The system SHALL treat a channel, movie or series as adult when its source marks it, or its category or genre, as adult: an Xtream `is_adult` flag of 1 or true, a Stalker `censored` flag of 1, or a Jellyfin rating of XXX or AO. A group whose every channel is flagged SHALL be adult as a whole.

#### Scenario: One flagged channel in a news group
- **GIVEN** a group "News" where the provider flags one channel adult
- **WHEN** a profile that hides adult content opens the group
- **THEN** that channel is left out and the rest of News shows with its numbers

#### Scenario: A flagged category
- **GIVEN** a provider category "Night Shows" flagged adult, with no adult word in its name
- **WHEN** the channels or titles load
- **THEN** every channel or title in it is adult

#### Scenario: Ratings that are not adult content
- **GIVEN** a Jellyfin channel rated NC-17, R or TV-MA
- **WHEN** the channels load
- **THEN** it is not adult

### Requirement: Hidden everywhere by default
The system SHALL leave adult content out for a profile that does not show it, which every profile starts as: channel lists, groups, the Groups sheet, the guide, numbers and number entry, Movies and Series with their banner and rows, Continue watching, My list, Recently watched, New, Search with its people, multi-view pickers, Top Shelf, Siri and Shortcuts. It SHALL NOT change any other channel's number, and SHALL NOT show an adult group anywhere, not even with a lock.

#### Scenario: A first launch
- **GIVEN** a provider with a group "XXX" holding channels 201 and 202, and a news channel 101
- **WHEN** the user opens Live in a new profile
- **THEN** no group "XXX" and none of its channels shows, in the list, the Groups sheet, the guide or Search
- **AND** typing 201 tunes nothing, and the news channel keeps number 101

#### Scenario: Movies and series
- **GIVEN** a movie in a category named "XXX Movies" and a series the provider flags adult
- **WHEN** the user opens Movies, Series or Search
- **THEN** neither title shows in the banner, a row, the grid or the results, and their cast lead to no person page

#### Scenario: Watched before
- **GIVEN** the user watched part of an adult movie while adult content was shown and added it to My list
- **WHEN** adult content is hidden again
- **THEN** Continue watching, My list and Recently watched leave it out, and its progress is kept

#### Scenario: Siri, Shortcuts and Top Shelf
- **GIVEN** a profile that hides adult content
- **WHEN** Shortcuts suggests channels or titles, Siri is asked for an adult channel by name, or Top Shelf shows favorites and Continue watching
- **THEN** no adult channel or title is offered or named, and Siri says the profile hides adult content

#### Scenario: Locked and adult
- **GIVEN** an adult group that is also locked
- **WHEN** a profile that hides adult content browses with the locks closed
- **THEN** the group shows nowhere, without a lock

### Requirement: Show adult content with the passcode
The system SHALL offer "Show adult content" in Settings for the current profile, ask for the group passcode before turning it on, ask the user to set a passcode first when none exists, turn it off without asking, and keep it on for that profile until it is switched off.

#### Scenario: Turning it on
- **GIVEN** a passcode is set and the profile hides adult content
- **WHEN** the user turns on Show adult content and enters the right passcode
- **THEN** adult groups, channels and titles show in this profile on every device
- **AND** the wrong passcode leaves it off, with the same slowing down after several wrong entries as the group locks

#### Scenario: No passcode yet
- **GIVEN** no passcode has been set on this iCloud account
- **WHEN** the user turns on Show adult content
- **THEN** they set four digits twice, the passcode the group locks use, and adult content shows

#### Scenario: Cancelling
- **GIVEN** the passcode prompt for Show adult content
- **WHEN** the user cancels it
- **THEN** the switch stays off

#### Scenario: Turning it off
- **GIVEN** the profile shows adult content
- **WHEN** the user turns the switch off
- **THEN** no passcode is asked and adult content is hidden at once

#### Scenario: Reopening the app
- **GIVEN** the profile shows adult content
- **WHEN** the app is closed and reopened, or left alone long enough for the locks to close
- **THEN** the profile still shows adult content

#### Scenario: Apple TV
- **GIVEN** an Apple TV
- **WHEN** the user selects Show adult content
- **THEN** the full-screen passcode prompt shows, entered with the remote, with no reset on Apple TV

### Requirement: Correct a group
The system SHALL let the user mark any provider group or own group as adult or not adult on the Groups screen, and SHALL let that mark win over the name rules and the provider's flags on every device of the account. Adult groups SHALL be listed on the Groups screen only while the profile shows adult content.

#### Scenario: A group the app missed
- **GIVEN** a group "Late Night" that holds adult channels and that the app did not find
- **WHEN** the user turns on Adult content for it
- **THEN** every profile that hides adult content stops showing it

#### Scenario: A group the app got wrong
- **GIVEN** a profile that shows adult content and a group the app found adult that is not
- **WHEN** the user turns off Adult content for it
- **THEN** it shows in every profile, and its flagged channels show too

#### Scenario: The Groups screen while adult content is hidden
- **GIVEN** a profile that hides adult content
- **WHEN** the user opens the Groups screen
- **THEN** adult groups are not listed, and a note says how to show them in Settings

### Requirement: Links to hidden content ask first
The system SHALL ask for the passcode when a link, the channel restored at launch, a reminder, Top Shelf or Siri tunes an adult channel that the profile hides, and the right passcode SHALL turn on Show adult content for the profile and play it. Siri and Shortcuts SHALL refuse an adult movie or series the profile hides, without naming it.

#### Scenario: The channel restored at launch
- **GIVEN** the last channel watched was an adult channel and the profile hides adult content
- **WHEN** the app opens
- **THEN** the passcode prompt covers the paused channel
- **AND** the right passcode turns on Show adult content and plays it, while closing the prompt plays the first channel the profile may watch

#### Scenario: A title from Siri
- **GIVEN** a profile that hides adult content
- **WHEN** Siri or a Shortcut asks to play an adult movie
- **THEN** Siri says the profile hides adult content, names no title, and nothing opens

### Requirement: Adult content that is playing stops
The system SHALL pause adult content that is playing when the profile stops showing it, from this device or another, and cover it with the passcode prompt, as a channel that gets locked does; a movie or episode SHALL close.

#### Scenario: Switched off on another device
- **GIVEN** an adult channel plays on Apple TV in Dad's profile
- **WHEN** Dad turns off Show adult content on his iPhone
- **THEN** the Apple TV pauses the channel and shows the passcode prompt
- **AND** closing the prompt plays the first channel the profile may watch, or closes the player

#### Scenario: A movie
- **GIVEN** an adult movie plays
- **WHEN** the profile stops showing adult content
- **THEN** the player closes
