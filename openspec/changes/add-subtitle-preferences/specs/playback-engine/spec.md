## ADDED Requirements

### Requirement: Subtitles start by the subtitle setting
The system SHALL start a stream's subtitles by the Subtitles setting and the device's languages in their order: with Auto, subtitles start off when the sound is in one of those languages and otherwise in the first of them the stream has; with Always, in the first of them the stream has; with Off, off. A language last picked on the channel on this device wins. This extends "Audio and subtitle languages" for live TV, catch-up, movies and episodes.

#### Scenario: Auto with sound the user understands
- **GIVEN** the device's languages are English then Swedish, the setting is Auto, and a channel has English sound and English and Swedish subtitles
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: Auto with sound in another language
- **GIVEN** the device's languages are English then Swedish, the setting is Auto, and a channel has German sound and German, Swedish and English subtitles
- **WHEN** the channel starts
- **THEN** English subtitles show

#### Scenario: Auto when the stream has none of the user's languages
- **GIVEN** the setting is Auto, the device's language is English, and a channel has German sound and only German subtitles
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: Sound with no language
- **GIVEN** the setting is Auto and the playing sound has no language tag
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: Always
- **GIVEN** the setting is Always, the device's languages are Swedish then English, and a channel has English sound and English subtitles only
- **WHEN** the channel starts
- **THEN** English subtitles show

#### Scenario: Off
- **GIVEN** the setting is Off and a channel has German sound and English subtitles, with English as the device's language
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: A pick on the channel wins
- **GIVEN** the setting is Auto, the sound is in the user's language, and the user turned Swedish subtitles on for this channel last time
- **WHEN** the user comes back to the channel
- **THEN** Swedish subtitles show
- **AND** a channel where the user turned subtitles off starts with them off, even with Always

#### Scenario: A movie
- **GIVEN** the setting is Auto, the device's language is English, and a movie has French sound and English subtitles
- **WHEN** the movie starts
- **THEN** English subtitles show

#### Scenario: Changing the setting while watching
- **GIVEN** a channel is playing
- **WHEN** the user changes the Subtitles setting
- **THEN** the playing channel keeps its subtitles and the next channel starts by the new setting

### Requirement: Forced subtitles in your language show
The system SHALL report forced subtitle tracks, the ones that translate only foreign speech or signs, with the other subtitles, name them as forced, and show a forced track in the user's first language that has one whenever no full subtitles are on, whatever the setting.

#### Scenario: Forced subtitles with subtitles off
- **GIVEN** the device's language is English, a movie has English sound, English subtitles and forced English subtitles, and the setting is Auto
- **WHEN** the movie starts
- **THEN** the forced English subtitles show and full subtitles stay off

#### Scenario: Forced subtitles in the list
- **GIVEN** a stream with forced subtitles
- **WHEN** the user opens the subtitle list
- **THEN** the forced track reads "English (Forced)", or "Forced" when it has no language

#### Scenario: Full subtitles replace forced ones
- **GIVEN** the setting starts full subtitles in the user's language
- **WHEN** the stream also has forced subtitles in that language
- **THEN** only the full subtitles show

### Requirement: Picture subtitles in broadcast streams
The system SHALL list the picture subtitles that broadcast MPEG-TS streams carry (DVB subtitles) as subtitle tracks with their languages, start them by the same rule as text subtitles, and draw each picture over the video in its place, scaled with the picture, at its time and for its duration, on every platform. Teletext subtitles are not listed.

#### Scenario: A broadcast channel with picture subtitles
- **GIVEN** a raw MPEG-TS channel with German sound and DVB subtitles in German and English, and English as the device's language with the setting on Auto
- **WHEN** the channel starts
- **THEN** the subtitle list shows German and English, English is on, and its pictures appear over the video at their times

#### Scenario: Scaled with the picture
- **GIVEN** picture subtitles are on
- **WHEN** the picture shows in the small player or in full screen
- **THEN** the subtitles keep their place on the picture and scale with it

#### Scenario: A subtitle clears
- **GIVEN** a picture subtitle is on screen
- **WHEN** its display time ends, or the broadcaster sends an empty page
- **THEN** it disappears

#### Scenario: Teletext
- **GIVEN** a raw MPEG-TS channel whose only subtitles are teletext
- **WHEN** the user opens the subtitle list
- **THEN** it says there are no subtitles in this stream
