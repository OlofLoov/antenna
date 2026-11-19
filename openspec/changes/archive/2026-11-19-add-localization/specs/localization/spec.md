# Spec Delta

## Purpose

Which languages Antenna speaks and how its own words, plurals, times, dates
and numbers follow the user's language and region on iPhone, iPad, Mac and
Apple TV, while text from the user's sources is shown as it arrives.

## ADDED Requirements

### Requirement: The app speaks the user's language
The app MUST show its own words in the first language in the user's
preferred list that it supports: English, Swedish, German, Spanish, French,
Portuguese (Brazil) or Arabic. A per-app language set in the system Settings
MUST win over the device language. Any other language MUST get English.
Portuguese (Portugal) MUST get the Brazilian text.

#### Scenario: A Swedish iPhone
- **GIVEN** an iPhone set to Swedish
- **WHEN** the user opens Antenna
- **THEN** tabs, buttons, headings, empty states and errors are in Swedish

#### Scenario: A per-app language
- **GIVEN** a Mac set to English with Antenna's own language set to German in System Settings
- **WHEN** the user opens Antenna
- **THEN** Antenna is in German and the rest of the Mac stays in English

#### Scenario: An unsupported language
- **GIVEN** an iPad set to Japanese with no other preferred language
- **WHEN** the user opens Antenna
- **THEN** Antenna is in English

#### Scenario: Portuguese from Portugal
- **GIVEN** an iPhone set to Portuguese (Portugal)
- **WHEN** the user opens Antenna
- **THEN** Antenna is in Portuguese, using the Brazilian translation

#### Scenario: Apple TV follows its own setting
- **GIVEN** an Apple TV set to Spanish and an iPhone set to English on the same iCloud account
- **WHEN** the household uses both
- **THEN** the Apple TV shows Antenna in Spanish and the iPhone in English, with the same sources, favorites and progress

### Requirement: No screen shows a key or a blank label
Every word the app shows MUST have text in the current language, or the
English text when a translation is missing. A screen MUST NOT show a
translation key, a format placeholder or an empty label in its place.

#### Scenario: A string added without a translation
- **GIVEN** a build where one new label has English text but no French
- **WHEN** a French user opens the screen
- **THEN** the label reads in English, not as a key or a blank

### Requirement: Counts use the language's plural forms
A count shown with a noun (channels, programmes, groups, days, minutes,
episodes, seasons, sources) MUST use the plural form the language needs for
that number, including Arabic's forms for zero, one, two, few and many.

#### Scenario: One channel and two channels in English
- **WHEN** a group has 1 channel, and another has 2
- **THEN** they read "1 channel" and "2 channels"

#### Scenario: Arabic dual and few
- **GIVEN** the app is in Arabic
- **WHEN** one source has 2 channels and another has 5
- **THEN** each count uses the Arabic form for that number, not the same word for both

#### Scenario: Zero
- **WHEN** a guide entry has no programmes
- **THEN** its count reads as the language's phrase for none, not "0 programmes" in English word order

### Requirement: Times and dates follow the user's region
Clock times, weekday names, dates and relative days MUST follow the user's
region and calendar settings, including a 24-hour clock where the user has
one. Guide times MUST stay in the guide's time zone as today.

#### Scenario: A 24-hour clock
- **GIVEN** an Apple TV with the region set to Sweden
- **WHEN** the viewer opens the guide
- **THEN** programme times read "21:00", not "9:00 PM"

#### Scenario: Weekday chips
- **GIVEN** the app is in French
- **WHEN** the viewer looks at the guide's day chips
- **THEN** they read "Aujourd'hui" and the French short weekday names

#### Scenario: The user forces a 12-hour clock
- **GIVEN** a German iPhone with the 24-hour setting turned off
- **WHEN** the user opens the guide
- **THEN** times use the 12-hour clock in German

### Requirement: Durations follow the user's language
Remaining time, runtimes, skip amounts and reminder lead times MUST be
written in the user's language with its unit words or abbreviations.

#### Scenario: Time left in a programme
- **GIVEN** the app is in Spanish
- **WHEN** the zap bar shows a programme with 25 minutes left
- **THEN** the remaining time is written in Spanish

#### Scenario: A film's runtime
- **GIVEN** the app is in German
- **WHEN** the viewer opens a film that runs 1 hour 52 minutes
- **THEN** the runtime is written with German units

### Requirement: Numbers use the region's digits and separators
Counts, sizes and percentages MUST use the digits, grouping and decimal
separators of the user's region. Channel numbers MUST use the same digits
without grouping, and typing a channel number MUST accept them.

#### Scenario: A large count in German
- **GIVEN** the app is in German with a German region
- **WHEN** a source has 12500 channels
- **THEN** the count reads "12.500"

#### Scenario: Arabic digits
- **GIVEN** the app is in Arabic with a region whose default digits are Arabic-Indic
- **WHEN** a channel row shows channel 105 and its programme times
- **THEN** the number and the times use Arabic-Indic digits in their normal order

#### Scenario: Typing a channel number on Apple TV
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer types a channel number on the on-screen pad
- **THEN** the pad and the number pill show the same digits and the right channel tunes

### Requirement: Source text is shown as it arrives
Channel names, programme titles and descriptions, group names, film and
series titles, plots, cast and track names from a source MUST be shown
exactly as the source sends them, in every app language.

#### Scenario: An English channel in a Swedish app
- **GIVEN** the app is in Swedish and a playlist names a channel "Sky Sports News"
- **WHEN** the channel list shows it
- **THEN** it reads "Sky Sports News"

#### Scenario: A provider group named in Arabic
- **GIVEN** the app is in English and a group is named in Arabic
- **WHEN** the group chips show it
- **THEN** the name shows in Arabic, right to left within its chip

### Requirement: Built-in names follow the language
Names the app makes up itself, such as the Favorites and All channels
groups, the ungrouped bucket and the track names it derives from language
codes, MUST be shown in the current language and MUST change when the
language changes, also on devices that share the same iCloud data.

#### Scenario: Changing the language
- **GIVEN** the app was used in English and the user switches the device to French
- **WHEN** the user opens Live
- **THEN** the built-in groups have their French names and the user's own groups keep their names

#### Scenario: An audio track from a language code
- **GIVEN** the app is in German and a stream offers an audio track tagged "fra"
- **WHEN** the viewer opens the track picker
- **THEN** the track reads "Französisch"

### Requirement: Mixed scripts keep their own direction
Source text in a left-to-right script MUST read left to right inside an
Arabic screen, and Arabic source text MUST read right to left inside a
left-to-right screen. A sentence that wraps a source name MUST keep the
name whole and in its own direction.

#### Scenario: A Latin title inside an Arabic sentence
- **GIVEN** the app is in Arabic
- **WHEN** a reminder banner says that "Champions League Live" starts in 5 minutes
- **THEN** the Arabic sentence reads right to left and the title inside it reads left to right, in one piece

### Requirement: System prompts and Siri speak the language
The local network permission prompt, the Top Shelf captions on Apple TV, the
Siri and Shortcuts phrases and the names of the app's shortcuts MUST be in
the user's language.

#### Scenario: Local network permission
- **GIVEN** an iPhone in Spanish
- **WHEN** the system asks to let Antenna reach the local network
- **THEN** the reason under the prompt is in Spanish

#### Scenario: A Siri phrase in French
- **GIVEN** an iPhone in French with Antenna set up
- **WHEN** the user opens Shortcuts and looks at Antenna's shortcuts
- **THEN** the shortcut names and the example phrases are in French

#### Scenario: Top Shelf in Swedish
- **GIVEN** an Apple TV in Swedish with Antenna in the top row
- **WHEN** the viewer focuses Antenna on the Home Screen
- **THEN** the section titles and captions above the tiles are in Swedish

### Requirement: Every language is complete before release
A pull request that adds or changes a word the app shows MUST include its
text in every shipped language, and CI MUST fail when a string has no
translation in one of them. A release build MUST NOT include a language
until a native speaker has reviewed it.

#### Scenario: A pull request adds a label in English only
- **WHEN** CI checks a pull request whose new label has no Arabic text
- **THEN** the check fails and names the label and the language

#### Scenario: A language not yet reviewed
- **GIVEN** the French text has been machine translated but not reviewed
- **WHEN** a user with a French iPhone installs that release from the App Store
- **THEN** Antenna is in English
