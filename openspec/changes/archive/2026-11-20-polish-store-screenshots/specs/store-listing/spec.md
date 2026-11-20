## MODIFIED Requirements

### Requirement: Store screenshots in every ready language
The screenshot run MUST take the store set on an iPhone, an iPad, a Mac and
an Apple TV at sizes App Store Connect accepts, once per ready language,
with the app in that language and region, and MUST file each picture under
every App Store locale of that language. Channel names, programme titles,
posters and backdrops in the pictures MUST come from made-up fixtures, and
the times the app shows MUST agree with the 9:41 on the status bar.

#### Scenario: German pictures
- **WHEN** the store screenshot run finishes
- **THEN** the German folder holds iPhone, iPad, Mac and Apple TV pictures whose tabs and buttons read in German

#### Scenario: One Spanish run, two store locales
- **WHEN** the run takes the Spanish pictures
- **THEN** the same pictures are filed under Spain and Mexico

#### Scenario: A held language
- **GIVEN** Arabic is held
- **WHEN** the nightly run takes the store set
- **THEN** there is no Arabic folder, unless someone asked for Arabic when starting the run by hand

#### Scenario: Mac pictures
- **WHEN** the store screenshot run finishes
- **THEN** each language's folder holds Mac pictures of the app's window at 1440 by 900 points, which is 2880 by 1800 pixels on a Retina screen

#### Scenario: Movies with art
- **WHEN** the store set shows Movies and a movie playing
- **THEN** every title has a made-up poster, the banner has a made-up backdrop, and none of them shows a real title, person, logo or brand

#### Scenario: The time matches the status bar
- **WHEN** the store set shows Live, the guide or the player
- **THEN** the programme on now, the guide's now line and the player's clock read about 9:41, the time on the status bar

#### Scenario: The fixtures stay out of the shipped app
- **WHEN** the app is built for release
- **THEN** the store clip, the posters and the backdrops are not in the app
