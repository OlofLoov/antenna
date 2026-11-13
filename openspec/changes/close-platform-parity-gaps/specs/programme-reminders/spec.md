## MODIFIED Requirements

### Requirement: Remind me appears only before a programme starts
The system SHALL offer a Remind me button on programmes that have not started, in the Apple TV guide, on the next programmes in the Apple TV channel overlay, in a programme's details in the guide on iPhone, iPad and Mac, and on guide results in Search on every platform, and nowhere else.

#### Scenario: A future programme
- **GIVEN** the user is looking at a programme in the Apple TV guide, a next programme in the Apple TV channel overlay, a programme's details in the guide on iPhone, iPad or Mac, or a guide result in Search
- **WHEN** the programme has not started yet
- **THEN** a Remind me button is offered, reachable with the remote on Apple TV

#### Scenario: A later programme in Search on Apple TV
- **GIVEN** a guide result in Search on Apple TV for a programme that starts later
- **WHEN** the user moves focus right from the result
- **THEN** focus lands on its bell, and pressing select sets the reminder without leaving Search

#### Scenario: Current, past and empty slots
- **GIVEN** a programme on now, a past programme, or an empty slot
- **WHEN** the user looks at it in any of those places
- **THEN** no Remind me button is offered
