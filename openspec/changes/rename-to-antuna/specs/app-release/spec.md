## ADDED Requirements

### Requirement: The app is called Antuna wherever a person sees it
The system SHALL name the app Antuna, untranslated, under its icon on iPhone,
iPad, Mac and Apple TV, in the Mac menu bar and Finder, in the App Store
listing of every language, and on the website, and SHALL keep the identifiers
an installed build reads, so a device that updates from a build named Antenna
keeps its sources, logins, favorites and settings.

#### Scenario: The name under the icon
- **GIVEN** a device set to any app language
- **WHEN** the person looks at the Home Screen, the Apple TV home screen, the Mac's Applications folder or the Mac menu bar
- **THEN** the app is called Antuna

#### Scenario: The store listing
- **WHEN** someone reads the App Store listing in any of its languages
- **THEN** its name is Antuna and its support and privacy addresses are on antuna.app

#### Scenario: Updating from a build named Antenna
- **GIVEN** a device with sources, logins and favorites set up in a build named Antenna
- **WHEN** the build named Antuna is installed over it
- **THEN** the sources, logins, favorites and settings are all still there
