## ADDED Requirements

### Requirement: The splash tunes in
While the app waits for the App Store's first answer at launch, the splash SHALL show the Antuna a playing Tuning on the dark ground, on iPhone, iPad, Mac and Apple TV.

#### Scenario: A first launch with a slow App Store
- **GIVEN** a device that remembers no purchase
- **WHEN** the app opens and the App Store has not answered yet
- **THEN** the splash shows the a with its antennae leaning, until the paywall or the app replaces it

### Requirement: A restored purchase ends with Got it
When Restore purchase finds a purchase, the paywall SHALL show the Antuna mark playing Got it once as "Welcome back" appears, and SHALL otherwise show the still mark.

#### Scenario: Restore finds a purchase
- **GIVEN** a purchase made on another device
- **WHEN** the user chooses Restore purchase and it is found
- **THEN** the mark flicks its tail and squints once as "Welcome back" appears, then stands still while Continue waits

#### Scenario: The offer
- **WHEN** the paywall shows the products
- **THEN** the mark at its top stands still
