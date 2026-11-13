## MODIFIED Requirements

### Requirement: Sources that fail, are empty or wait for a login
The system SHALL list the channels that loaded under a banner naming each failed source with Try again and dismiss, SHALL replace the list with one message on the shared empty and error layout when no source loaded channels, with Try again, and Open Settings first unless the device is offline, and SHALL never show a source's own error text.

#### Scenario: Some sources failed
- **GIVEN** at least one source failed to load, has no channels, or has no login on this device yet
- **WHEN** the user opens Live
- **THEN** the channels that did load are listed under a banner naming each failed source, with Try again and a dismiss button
- **AND** Try again reloads only those sources while the channel keeps playing

#### Scenario: Nothing loaded
- **GIVEN** no source loaded any channels
- **WHEN** the user opens Live
- **THEN** a message with Open Settings and Try again takes the list's place
- **AND** the picture area shows no placeholder of its own while the message shows
- **AND** the source's own error text is never shown

#### Scenario: Loading, offline, empty or waiting
- **GIVEN** sources are loading, the device is offline, sources loaded with no channels, or a login has not arrived from iCloud
- **WHEN** the user opens Live
- **THEN** the list shows each source loading in turn, says the device is offline, shows "No channels yet" with Open Settings and Try again, or names the source as waiting for its login
