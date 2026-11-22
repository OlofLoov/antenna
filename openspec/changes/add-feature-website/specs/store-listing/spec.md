## ADDED Requirements

### Requirement: The listing links to the site's pages
The repo MUST give every listing a support address that opens the site's support page, a privacy address that opens the Privacy Policy, and a marketing address that opens the home page, all on Antenna's domain.

#### Scenario: Checking the addresses
- **WHEN** the check runs
- **THEN** each language's support address ends in `/support`, its privacy address in `/privacy`, and its marketing address is the site's home page

#### Scenario: A support address left on the Terms
- **GIVEN** the Swedish support address still opens the Terms of Use
- **WHEN** the check runs
- **THEN** it fails and names the Swedish support address
