## ADDED Requirements

### Requirement: Languages are added when their listing is ready
The system SHALL publish the site in English, and SHALL publish another language only when its App Store listing is ready, with every page in that language, its screenshots in that language, and a way to switch between the published languages on every page. Arabic SHALL read right to left.

#### Scenario: English only
- **GIVEN** only English is published
- **WHEN** a visitor whose browser prefers Swedish opens the site
- **THEN** the English site shows, with no language switch

#### Scenario: Swedish is added
- **GIVEN** the Swedish store listing is ready and the Swedish site is published
- **WHEN** a visitor picks Svenska in the language switch
- **THEN** the same page shows in Swedish with Swedish screenshots, at an address that starts with `/sv/`

#### Scenario: A language not yet published
- **GIVEN** only English and Swedish are published
- **WHEN** someone opens an address that starts with `/de/`
- **THEN** "Page not found" shows with a not-found status

#### Scenario: Arabic is added
- **GIVEN** the Arabic site is published
- **WHEN** a visitor opens it
- **THEN** text, navigation and the order of sections run right to left, and screenshots are the Arabic store set
