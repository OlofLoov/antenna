# store-listing Specification

## Purpose
What Antenna's App Store listing says in each language the app ships, the
limits it stays within, what it never claims or names, and the screenshots
taken for it.

## Requirements

### Requirement: Every app language has a listing
The repo MUST hold an App Store listing for each language the app ships:
name, subtitle, description, keywords, promotional text, what's new, and
the privacy and support addresses. English MUST be the primary listing.
Spanish MUST have a listing for Spain and one for Mexico, and French one
for France and one for Canada. A language added to the app without a
listing MUST fail the check.

#### Scenario: A language the app ships
- **GIVEN** the app ships in Swedish
- **WHEN** the check runs
- **THEN** it finds a Swedish listing with every field filled

#### Scenario: A language without a listing
- **GIVEN** someone adds Italian to the app's languages and no Italian listing
- **WHEN** the check runs
- **THEN** it fails and names the missing Italian listing

#### Scenario: A field left empty
- **GIVEN** the German listing has an empty subtitle
- **WHEN** the check runs
- **THEN** it fails and names the German subtitle

### Requirement: The listing fits App Store Connect
Each field MUST stay within App Store Connect's limit: 30 characters for
the name and the subtitle, 100 for keywords, 170 for promotional text, and
4000 for the description and what's new. Keywords MUST be separated by
commas with no space around them, MUST NOT repeat a keyword, and MUST NOT
repeat a word from the name or subtitle. The addresses MUST be https
addresses on Antenna's site.

#### Scenario: A subtitle one character too long
- **GIVEN** a French subtitle of 31 characters
- **WHEN** the check runs
- **THEN** it fails and names the French subtitle, its length and the limit

#### Scenario: Keywords with spaces after the commas
- **GIVEN** Swedish keywords written as "m3u, epg, live"
- **WHEN** the check runs
- **THEN** it fails, since each space takes one of the 100 characters

#### Scenario: A keyword already in the subtitle
- **GIVEN** an English subtitle with "player" and "player" in the English keywords
- **WHEN** the check runs
- **THEN** it fails, since the App Store already searches the subtitle's words

### Requirement: The listing promises no content
The listing in every language MUST say that Antenna comes with no channels
and that the user adds their own source, and MUST say that a purchase is
required to use it. It MUST NOT name a TV provider, broadcaster, channel,
league, streaming service or competing player, MUST NOT promise free
channels or any amount of content, and MUST NOT carry a web address other
than Antenna's own.

#### Scenario: Reading the description
- **WHEN** someone reads the listing in any language
- **THEN** it says the app has no channels of its own and needs a purchase

#### Scenario: A broadcaster in the copy
- **GIVEN** a Spanish description that mentions a sports broadcaster by name
- **WHEN** the check runs
- **THEN** it fails and names the Spanish description and the word

#### Scenario: A link in the copy
- **GIVEN** a promotional text with the address of a playlist site
- **WHEN** the check runs
- **THEN** it fails

### Requirement: A language's listing waits for its review
A language whose app text is held back from releases MUST keep its listing
in the repo, checked like every other, and MUST be reported as held, so it
is neither uploaded nor photographed until the language ships. English is
never held.

#### Scenario: Arabic before it ships
- **GIVEN** Arabic is in the app but not yet reviewed for release
- **WHEN** someone asks which listings are ready
- **THEN** every listing but Arabic is ready, and Arabic is held

#### Scenario: Arabic ships
- **WHEN** Arabic is added to the reviewed languages
- **THEN** the Arabic listing is ready and the next store screenshot run takes Arabic pictures

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
