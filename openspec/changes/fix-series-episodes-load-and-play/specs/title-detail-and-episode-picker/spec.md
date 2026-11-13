## MODIFIED Requirements

### Requirement: When details or episodes do not load
The system SHALL say which part of the page failed to load, with Retry, and SHALL still let a movie whose details failed be played and added to My list. Each failure SHALL be kept in the device log with a reason, such as the server's status, the network error code or where the answer stopped making sense, and never with an address, login or the answer itself.

#### Scenario: The provider fails
- **GIVEN** the provider fails to answer for the details or the episodes
- **WHEN** the page is showing
- **THEN** the part that failed reads "Could not load details" or "Could not load episodes", or the offline message when that is the cause, with Retry
- **AND** a movie whose details failed can still be played and added to My list

#### Scenario: Offline with a provider login
- **GIVEN** the device has no network
- **WHEN** a series page from a provider with a login asks for its episodes
- **THEN** the page shows the offline message, not "Could not load episodes"

#### Scenario: The reason is kept
- **GIVEN** the provider answers a series with an error status or an answer that cannot be read
- **WHEN** the page shows "Could not load episodes"
- **THEN** the device log says why, with no address, login or answer text in it

#### Scenario: A login not on this device
- **GIVEN** a title whose source login has not reached this device
- **WHEN** the page shows or the user presses Play
- **THEN** it shows "<source>: waiting for its login to sync from iCloud" with Retry, and Play plays nothing

#### Scenario: A slow provider
- **WHEN** the provider is slow
- **THEN** the name and poster show at once, and only the details and episodes wait
