# up-next Specification

## Purpose
Lets people binging a series go from one episode to the next without leaving the player: a button near the end, a short countdown that plays the next episode on its own, a way to cancel, and a check that someone is still watching.

## Requirements

### Requirement: Next episode near the end
The system SHALL show a Next episode button over the bottom right corner of a playing episode from 60 seconds before its end, when the episode is at least 5 minutes long and has a next episode. The button SHALL not pause or cover the middle of the picture, and pressing it SHALL play the next episode in the same player.

#### Scenario: The last minute
- **GIVEN** a 45-minute episode playing with a next episode
- **WHEN** it reaches 44:00
- **THEN** a Next episode button shows in the bottom right corner while the episode keeps playing
- **AND** pressing it plays the next episode in the same player, without going back to the series page

#### Scenario: The last 30 seconds
- **GIVEN** the Next episode button showing from a minute before the end
- **WHEN** the episode reaches its last 30 seconds
- **THEN** the button stays where it is until the Up next card replaces it 15 seconds before the end

#### Scenario: Earlier in the episode
- **GIVEN** an episode playing more than 60 seconds before its end
- **WHEN** the viewer looks at the picture
- **THEN** no Next episode button shows

#### Scenario: The controls show
- **GIVEN** the Next episode button showing on iPhone, iPad or Mac
- **WHEN** the viewer taps and the controls show
- **THEN** the button moves up clear of the scrubber and stays pressable

### Requirement: Up next counts down
The system SHALL replace the button with an Up next card from 15 seconds before the end, with the next episode's picture, code and title, a countdown from 10 while the episode plays, Play now and Cancel, and SHALL play the next episode in the same player at zero or on Play now. An episode shorter than 5 minutes, or with no length from the stream, SHALL show the card when it ends.

#### Scenario: The countdown runs out
- **GIVEN** a 45-minute episode playing with a next episode
- **WHEN** it reaches 44:45
- **THEN** the Up next card shows "S2 E5 · The Long Night" and "Next episode in 10", counting down once a second
- **AND** at zero the next episode starts in the same player, from where the viewer stopped in it or from the start

#### Scenario: Play now
- **GIVEN** the Up next card showing
- **WHEN** the viewer presses Play now
- **THEN** the next episode starts at once

#### Scenario: Paused
- **GIVEN** the Up next card counting down
- **WHEN** the viewer pauses
- **THEN** the count stops and goes on from the same number when they play again

#### Scenario: No picture from the provider
- **GIVEN** a next episode the provider sent no picture for
- **WHEN** the card shows
- **THEN** a tile with the episode's number takes the picture's place, as in the episode list

#### Scenario: The episode ends during the count
- **GIVEN** the card counting down
- **WHEN** the episode ends before the count reaches zero
- **THEN** the next episode starts at once

#### Scenario: A short episode or no length
- **GIVEN** a 3-minute episode, or an episode whose stream gives no length
- **WHEN** it plays and then ends
- **THEN** no button or card shows while it plays
- **AND** when it ends, the card shows over the last frame with "Next episode in 10" and the next episode starts at zero

#### Scenario: Moving back
- **GIVEN** the Next episode button or the Up next card showing
- **WHEN** the viewer skips or scrubs back to more than 60 seconds before the end
- **THEN** both go away, and the count starts again from 10 if the episode reaches the last 15 seconds again

#### Scenario: VoiceOver
- **GIVEN** VoiceOver on
- **WHEN** the card shows
- **THEN** it reads "Up next, Season 2 Episode 5, The Long Night, next episode in 10 seconds", then Play now and Cancel

### Requirement: Which episode is next
The system SHALL take the next episode in the season picker's order: the following episode in the same season, else the first episode of the next season. A special SHALL lead only to the next special, and an episode with no season only to the next one with no season. The last episode SHALL have no next. The order SHALL come from the series' episode list already loaded for its page or poster, asked of the provider once when it is not loaded yet.

#### Scenario: The end of a season
- **GIVEN** a series with seasons 1 and 2 and specials
- **WHEN** the last episode of Season 1 nears its end
- **THEN** the card offers Season 2 Episode 1
- **AND** the last episode of Season 2 offers nothing, and no special follows it

#### Scenario: The last episode
- **GIVEN** the last episode of a series playing
- **WHEN** it ends
- **THEN** no button or card shows, and the viewer is back on the series page

#### Scenario: The list cannot load
- **GIVEN** an episode started from Continue watching whose series' episode list fails to load
- **WHEN** it ends
- **THEN** no button or card shows, and it ends as an episode with no next one does

#### Scenario: No extra calls
- **GIVEN** a series whose episode list loaded for its page
- **WHEN** three episodes play one after another
- **THEN** the provider is not asked for the episode list again

### Requirement: Cancel keeps watching
The system SHALL hide the button and the card for the rest of the episode when the viewer presses Cancel, or Back on Apple TV while the card has focus. The episode SHALL play to its end and then go back to the series page, or to where it was started from.

#### Scenario: Watch the credits
- **GIVEN** the Up next card counting down
- **WHEN** the viewer presses Cancel
- **THEN** the card goes, the episode plays on to its end with no button or card, and then the series page shows with that episode in view

#### Scenario: Cancel after the end
- **GIVEN** the card showing over the last frame of an ended episode
- **WHEN** the viewer presses Cancel
- **THEN** the series page shows

### Requirement: Still watching
The system SHALL ask "Still watching?" instead of counting down once three episodes in a row have started from the countdown with no press, tap, click or key from the viewer. The question SHALL offer Keep watching and Cancel and SHALL not count down. When the episode ends with the question unanswered, the picture SHALL stop and the question stay until answered. Any input SHALL start the run again from zero.

#### Scenario: Three episodes on their own
- **GIVEN** the viewer started Episode 1 and nobody touched the remote while Episodes 2, 3 and 4 started from the countdown
- **WHEN** Episode 4 reaches its last 20 seconds
- **THEN** the card asks "Still watching?" with Keep watching and Cancel, and nothing counts down
- **AND** when Episode 4 ends, the picture stops and the question stays
- **AND** Keep watching plays Episode 5, and Cancel goes back to the series page

#### Scenario: Someone pressed something
- **GIVEN** two episodes started from the countdown
- **WHEN** the viewer pauses, skips, taps, or presses Play now
- **THEN** the run starts again, and the next three episodes count down as usual

### Requirement: Progress follows the next episode
The system SHALL mark the episode that was playing as watched when the next one starts, from the button, the card or the countdown, and SHALL save the next episode's place as it plays, so Continue watching, the series page's UP NEXT mark and its Play button move on. Going back to the series page SHALL show the season of the episode that played last with that episode in view.

#### Scenario: Back on the page after two episodes
- **GIVEN** the viewer played Season 1 Episode 8 from the page and the countdown started Season 2 Episode 1
- **WHEN** they leave Season 2 Episode 1 part-way
- **THEN** the series page shows Season 2 with Episode 1 in view, its bar and "Resume S2 E1"
- **AND** Season 1 Episode 8 shows Watched, even when the viewer pressed Next episode 60 seconds before its end
- **AND** Continue watching shows Season 2 Episode 1

### Requirement: Turn autoplay off
The system SHALL offer "Autoplay next episode" in Settings on every platform, on until the viewer switches it off. The choice SHALL stay on that device and SHALL not sync to other devices. With it off, no button or card SHALL show and an episode SHALL end as one with no next does.

#### Scenario: Off on the iPhone
- **GIVEN** the viewer switched "Autoplay next episode" off on their iPhone
- **WHEN** an episode with a next one plays to its end there
- **THEN** no button or card shows, and the series page shows when it ends
- **AND** on their Apple TV with the same Apple Account the next episode still counts down

### Requirement: Up next on the Siri Remote
The system SHALL let the viewer reach the Next episode button and the Up next card on Apple TV by swiping or clicking down, before the bar's Audio and Subtitles button, while clicks left and right skip 10 seconds, play/pause pauses and a slide shows the bar. When the card shows, it SHALL take focus on Play now. Back with focus on the button or the card SHALL put focus back on the picture and, on the card, cancel it. Back with focus on the picture SHALL still close the episode.

#### Scenario: Reaching the button
- **GIVEN** an episode in its last minute on Apple TV with the Next episode button showing
- **WHEN** the viewer swipes down
- **THEN** the button takes focus and grows, and select plays the next episode
- **AND** Back puts focus back on the picture and the button stays

#### Scenario: Past the button to audio and subtitles
- **GIVEN** the Next episode button has focus
- **WHEN** the viewer swipes down again
- **THEN** the bar shows and its Audio and Subtitles button takes focus
- **AND** swiping up from it goes back to the Next episode button

#### Scenario: The card takes focus
- **GIVEN** an episode playing on Apple TV
- **WHEN** the Up next card shows
- **THEN** Play now has focus, select plays the next episode, and clicking left or right still skips 10 seconds
- **AND** Back cancels the card and the episode plays on
