# player-controls-and-playback-errors Specification

## Purpose
Lets anyone watching a channel change the language, see what is on and what the stream is, and understand in plain words why a stream stopped and what to try, on every platform.

## Requirements

### Requirement: See what's on without stopping the picture on Apple TV
The system SHALL open a panel over the still-playing picture when the user holds select on Apple TV, with the channel, the current programme, its progress and summary, the format badges and a stream line, and SHALL close it on Menu.

#### Scenario: Holding select
- **GIVEN** a channel playing full screen on Apple TV
- **WHEN** the user holds select
- **THEN** a panel opens over the top of the still-playing picture showing the channel number, name and source
- **AND** the current programme with its times, minutes left, a progress bar and its summary
- **AND** the format badges and a stream line such as "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player", or "Stream details not available yet" while loading

#### Scenario: Inside the panel
- **GIVEN** the panel is open
- **WHEN** the user swipes, presses play/pause, or presses Menu
- **THEN** swipes move within it and never change channel, play/pause does nothing, and Menu closes it

#### Scenario: No guide data
- **GIVEN** the channel has no guide data
- **WHEN** the panel opens
- **THEN** it shows the zap bar's guide status text in place of the programme

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the panel, picker or error appears
- **THEN** it appears without sliding or fading

### Requirement: Choose audio and subtitles
The system SHALL list audio and subtitle tracks with readable names and sound format, tick the current choice, switch on a pick while keeping the list open, offer "Off" first for subtitles, and update the list when tracks change.

#### Scenario: Picking a track
- **GIVEN** a channel with several audio tracks and subtitle tracks
- **WHEN** the user opens the Audio or Subtitles tab on Apple TV, or the audio-and-subtitles button on iPhone, iPad or Mac, and picks a track
- **THEN** each track shows a readable name ("English", "English (Commentary)", "Track 4" when it has no language, "Forced" for forced subtitles) with its sound format
- **AND** the current choice is ticked, and picking one switches to it and leaves the list open

#### Scenario: Subtitles
- **GIVEN** the subtitles list is open
- **WHEN** the stream has subtitles, or none
- **THEN** "Off" comes first, or the list says "No subtitles in this stream"

#### Scenario: Tracks change while open
- **GIVEN** the list is open
- **WHEN** the stream's tracks change
- **THEN** the list updates

#### Scenario: Grayed-out button
- **GIVEN** a channel on iPhone, iPad or Mac with one audio track and no subtitles
- **WHEN** the controls show
- **THEN** the audio-and-subtitles button is grayed out

#### Scenario: Changing channel
- **GIVEN** the user picked a language on one channel
- **WHEN** they change channel
- **THEN** the new channel starts fresh without carrying the choice over

### Requirement: Extra buttons on iPhone, iPad and Mac
The system SHALL add to the controls on iPhone, iPad and Mac the audio-and-subtitles button, an AirPlay button when the stream can go to AirPlay, and on Mac mute and a volume slider with keyboard shortcuts, each with a spoken label.

#### Scenario: The controls show
- **GIVEN** a channel playing on iPhone, iPad or Mac
- **WHEN** the controls are shown
- **THEN** they include the audio-and-subtitles button and an AirPlay button when the stream can go to AirPlay
- **AND** on Mac a mute button and volume slider
- **AND** each button has a spoken label

#### Scenario: A stream that cannot go to AirPlay
- **GIVEN** a stream Antenna reads itself rather than through Apple's player
- **WHEN** the user opens the picker
- **THEN** there is no AirPlay button and the picker footer says "AirPlay not available for this stream"

#### Scenario: Playing on AirPlay
- **GIVEN** the stream is playing on AirPlay
- **WHEN** the user looks at the video area
- **THEN** it says "Playing on AirPlay"

#### Scenario: Mac keys
- **GIVEN** a channel playing on a Mac
- **WHEN** the user presses M, Command-Up or Command-Down
- **THEN** M mutes, and Command-Up and Command-Down change the volume

### Requirement: The Mac remembers its volume
The system SHALL bring back the last volume on a Mac when the app is opened again, unmuted if it was muted.

#### Scenario: Quit and reopen
- **GIVEN** the volume or mute changed on a Mac
- **WHEN** the app is quit and opened again
- **THEN** the same volume comes back, unmuted if it was muted

### Requirement: A spinner while waiting, and a reason if it is slow
The system SHALL show a spinner over the picture once a channel has been loading or waiting for data for half a second, remove it when it plays, pauses or fails, and after ten seconds name the source as sending data slowly.

#### Scenario: Waiting for data
- **GIVEN** a channel loading or waiting for data for more than half a second
- **WHEN** the player is shown
- **THEN** a spinner appears over the picture and goes as soon as it plays, pauses or fails

#### Scenario: Slow for ten seconds
- **GIVEN** the spinner has shown for ten seconds
- **WHEN** the player is shown
- **THEN** a line under it says "Still buffering." and that the source is sending data slowly, naming the source

#### Scenario: Play/pause while spinning
- **GIVEN** the spinner shows on iPhone, iPad or Mac
- **WHEN** the user presses play/pause
- **THEN** it still works

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the spinner appears
- **THEN** VoiceOver says "Buffering"

### Requirement: A dropped stream shows that it is reconnecting
The system SHALL show the engine's reconnect count in place of the spinner while it reconnects, keep the last picture, and show an error only when the engine gives up or reports a failure reconnecting cannot fix.

#### Scenario: Reconnecting
- **GIVEN** a channel that drops while playing and the engine reconnecting
- **WHEN** the player is shown
- **THEN** it says "Reconnecting… attempt n of m" with the engine's count instead of the spinner
- **AND** the last picture stays

#### Scenario: Giving up
- **GIVEN** the engine is reconnecting
- **WHEN** it gives up or reports a failure reconnecting cannot fix
- **THEN** the error shows

### Requirement: A failed stream says what went wrong
The system SHALL replace the picture of a failed channel with a title, a plain explanation naming the source and a "Try again" button, close any panel, picker or Picture in Picture window first, and keep the channel name visible on iPhone, iPad and Mac.

#### Scenario: The error screen
- **GIVEN** a channel whose playback has failed
- **WHEN** the player is shown
- **THEN** the picture is replaced by a title, a plain explanation naming the source, and a "Try again" button
- **AND** any open panel, picker or Picture in Picture window closes first
- **AND** on iPhone, iPad and Mac the channel name stays visible

#### Scenario: The error on Apple TV
- **GIVEN** a failed channel on Apple TV
- **WHEN** the error shows
- **THEN** "Try again" is focused, and a line names the source and when it was tried and says how to change channel
- **AND** swiping up or down still changes channel

#### Scenario: Behind another screen
- **GIVEN** the overlay, guide or another tab is open
- **WHEN** the stream fails
- **THEN** the error is drawn in the player behind them

#### Scenario: VoiceOver and large text
- **GIVEN** VoiceOver is on or the text size is large
- **WHEN** the error appears
- **THEN** VoiceOver reads its title and explanation once, and the explanation wraps

### Requirement: Error messages for each reason
The system SHALL show one title and explanation for each failure reason the engine reports, naming the source, and SHALL NOT put the stream address, server name, username or password in any message, label, lock-screen field or log line.

#### Scenario: Offline
- **GIVEN** the device has no internet and the source is "Acme TV"
- **WHEN** the error shows
- **THEN** it reads "You're offline" and "Connect to the internet and try again. Playback resumes on its own when the connection returns."

#### Scenario: Unreachable or failed secure connection
- **GIVEN** the server cannot be reached, or the secure connection failed
- **WHEN** the error shows
- **THEN** it reads "Could not reach Acme TV" and "The connection failed (<reason>). Check the network, or a VPN if one is on.", or "The secure connection failed. Check the network, or a VPN if one is on."

#### Scenario: Login not on this device
- **GIVEN** the login has not reached this device
- **WHEN** the error shows on iPhone, iPad or Mac
- **THEN** it reads "Waiting for login" and "The login for Acme TV has not reached this device from iCloud Keychain yet."

#### Scenario: Login not on this Apple TV
- **GIVEN** the login is not on this Apple TV
- **WHEN** the error shows
- **THEN** it reads "Sign in needed" and "Sign in to Acme TV on this Apple TV to play its channels."

#### Scenario: Login rejected
- **GIVEN** the provider rejected the login
- **WHEN** the error shows
- **THEN** it reads "Sign-in refused" and "Acme TV rejected the login. Check the username and password in Settings, or ask the provider whether the account has expired."
- **AND** on Apple TV "Sign in again on this Apple TV" replaces the Settings sentence

#### Scenario: Not found, busy, server error or other refusal
- **GIVEN** the provider answered 404, said it is busy, answered with a server error code, or refused with another code
- **WHEN** the error shows
- **THEN** it reads "Stream not found" with "Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider.", or "Provider busy" with "Acme TV is busy right now. Try again in a moment.", or "Provider error" with "Acme TV returned <code>. Its server is having trouble. Try again in a moment.", or "Stream unavailable" with "Acme TV returned <code> for this channel."

#### Scenario: Nothing arrived or data stopped
- **GIVEN** nothing arrived for n seconds, or data stopped after playing
- **WHEN** the error shows
- **THEN** it reads "Stream stopped" with "Acme TV did not send any data for <n> seconds." or "Acme TV stopped sending data."

#### Scenario: Not a stream
- **GIVEN** the provider sent something that is not a playable stream
- **WHEN** the error shows
- **THEN** it reads "Stream could not be read" and "Acme TV sent data that is not a playable stream. The address may point to a web page or an empty file."

#### Scenario: Unsupported codec or no decoder free
- **GIVEN** the stream uses a codec the device cannot play, or no decoder is free
- **WHEN** the error shows
- **THEN** it reads "Format not supported" with "This stream uses <codec>, which this device cannot play. Trying again will not help. Pick another channel or ask the provider for a stream in a supported format.", or "Can't play another stream" with "This device is already playing as many streams as it can."

#### Scenario: No secrets anywhere
- **GIVEN** a stream address with a server name, username and password fails
- **WHEN** every message, label, lock-screen field and log line is collected
- **THEN** none contains the stream address, server name, username or password

### Requirement: Try again, or recover on its own
The system SHALL load the same channel once more, without counting it as a channel change, when the user chooses Try again, the network returns after an offline error, or a missing login arrives, and on Apple TV SHALL offer Sign in for a missing login.

#### Scenario: Try again
- **GIVEN** the error screen shown
- **WHEN** the user taps "Try again", or presses select or play/pause on Apple TV
- **THEN** the same channel loads once more without counting as a channel change
- **AND** the error goes and the spinner shows

#### Scenario: The network or login returns
- **GIVEN** an offline or missing-login error
- **WHEN** the network comes back or the login arrives on the device
- **THEN** the same channel loads again by itself

#### Scenario: Sign in on Apple TV
- **GIVEN** a missing-login error on Apple TV
- **WHEN** the user chooses "Sign in"
- **THEN** the sign-in step runs and comes back to the channel

#### Scenario: Changing channel from the error
- **GIVEN** the error or the panel is shown
- **WHEN** the user changes channel
- **THEN** both close and the new channel starts fresh

### Requirement: Picture in Picture on iPhone and iPad
The system SHALL keep the channel playing in the Picture in Picture window without reloading when the user taps PiP or leaves the app, play newly picked channels in the same window, restore without reloading, pause when the window closes, and show the error in the app if reconnecting gives up.

#### Scenario: Entering Picture in Picture
- **GIVEN** a channel playing on iPhone or iPad where Picture in Picture is possible
- **WHEN** the user taps the PiP button or leaves the app with the Home gesture
- **THEN** the channel keeps playing in the small window without reloading
- **AND** the player area says "Playing in Picture in Picture"

#### Scenario: Another channel, restore and close
- **GIVEN** the channel plays in Picture in Picture
- **WHEN** the user picks another channel, restores the window, or closes it
- **THEN** a new channel plays in the same window, restoring brings the picture back with no reload, and closing the window pauses

#### Scenario: Reconnecting gives up
- **GIVEN** the channel plays in Picture in Picture
- **WHEN** the engine gives up reconnecting
- **THEN** the window closes and the error shows in the app

### Requirement: Keep listening in the background
The system SHALL keep the sound of a channel playing on iPhone, iPad or Mac for at least a minute when the user locks the screen, switches app or hides the window, pause it for a call or alarm, and resume when the system allows.

#### Scenario: Leaving the app
- **GIVEN** a channel playing on iPhone, iPad or Mac without Picture in Picture
- **WHEN** the user locks the screen, switches app or hides the window
- **THEN** the sound keeps playing for at least a minute

#### Scenario: A call or alarm
- **GIVEN** the sound plays in the background
- **WHEN** a phone call or alarm comes in and ends
- **THEN** playback pauses, and resumes if the system says it may

### Requirement: The channel shows on the lock screen
The system SHALL show the programme title or channel name, a channel line, the logo once cached and a live marker on the lock screen and in Control Center, with working play and pause and no skip buttons, updating within five seconds of a change.

#### Scenario: Lock screen and Control Center
- **GIVEN** a channel playing or paused on iPhone, iPad or Mac
- **WHEN** the user looks at the lock screen or Control Center
- **THEN** it shows the programme title, or the channel name when there is none, a "104 Sport One" style channel line, the logo once it is cached and a live marker
- **AND** play and pause there work and skip buttons are off

#### Scenario: A programme or channel change
- **GIVEN** the lock screen shows a channel
- **WHEN** the programme or channel changes
- **THEN** the details update within five seconds

### Requirement: Turn subtitles on or off in one step
The system SHALL offer a subtitles switch in the player that turns subtitles on, in the user's first language the stream has or else its first full track, or off with one press, shows which it is, and is kept for the channel like a pick in the list. It sits next to the audio-and-subtitles button on iPhone, iPad and Mac wherever AirPlay can show, and in the info panel on Apple TV.

#### Scenario: Turning subtitles on on iPhone in full screen
- **GIVEN** a channel with English subtitles playing in full screen on iPhone, with subtitles off and English as the device's language
- **WHEN** the user taps the subtitles button
- **THEN** English subtitles show, the button reads as on, and no list opens

#### Scenario: Turning subtitles off on Apple TV
- **GIVEN** subtitles are on and the info panel is open
- **WHEN** the user moves focus to the subtitles switch and presses select
- **THEN** subtitles turn off, the switch reads "Subtitles Off", and the panel stays open

#### Scenario: No subtitles in the stream
- **GIVEN** a stream with no subtitles
- **WHEN** the controls or the panel show
- **THEN** the subtitles switch is grayed out on iPhone, iPad and Mac, and not shown on Apple TV

#### Scenario: Only forced subtitles on
- **GIVEN** forced subtitles show because no full subtitles are on
- **WHEN** the user looks at the switch
- **THEN** it reads as off, and pressing it turns full subtitles on

#### Scenario: The switch is remembered for the channel
- **GIVEN** the user turned subtitles on with the switch on a channel
- **WHEN** they come back to that channel on the same device
- **THEN** it starts with those subtitles

#### Scenario: The narrow player on iPhone
- **GIVEN** the small player above the channel list on iPhone
- **WHEN** the controls show
- **THEN** the subtitles button is not in the strip, and subtitles are turned on or off from the audio-and-subtitles list or in full screen

### Requirement: Choose audio and subtitles in a movie or episode
The system SHALL offer in the movie and episode player the same audio and subtitle lists as Live, with the subtitles switch, on every platform, and SHALL start each title by the Subtitles setting.

#### Scenario: Picking a track on iPhone, iPad or Mac
- **GIVEN** a movie with several audio tracks and subtitles playing on iPhone, iPad or Mac
- **WHEN** the user taps the audio-and-subtitles button at the top of the player and picks a track
- **THEN** the list opens as a sheet at compact width and as a popover otherwise, with the same names, tick and Off row as in Live
- **AND** the movie switches to the track without restarting, and the list stays open

#### Scenario: The subtitles switch
- **GIVEN** an episode with full subtitles playing on iPhone, iPad or Mac
- **WHEN** the user taps the subtitles button next to the audio-and-subtitles button
- **THEN** subtitles turn on or off with no list, as in Live

#### Scenario: Apple TV
- **GIVEN** a movie playing on Apple TV
- **WHEN** the user holds select
- **THEN** a panel opens over the playing picture with Audio and Subtitles tabs and the Subtitles switch, and no Info tab
- **AND** Menu closes the panel first and the movie on the next press

#### Scenario: One sound and no subtitles
- **GIVEN** a title with one audio track and no subtitles
- **WHEN** the player shows
- **THEN** both buttons are grayed out on iPhone, iPad and Mac, and on Apple TV the Subtitles tab says there are none

#### Scenario: The next title
- **GIVEN** the user picked a language in one title
- **WHEN** another title or the next episode starts
- **THEN** it starts by the Subtitles setting and the device's languages, without carrying the pick over

### Requirement: Picture in Picture on a Mac
The system SHALL let a Mac user move the playing channel into the Picture in Picture window from the Live controls, on either playback path, without reloading, and SHALL pause when the window closes and bring the picture back without reloading when the user returns it.

#### Scenario: Entering Picture in Picture
- **GIVEN** a channel playing in the Mac window
- **WHEN** the user clicks the Picture in Picture button in the controls
- **THEN** the channel keeps playing in a floating window without reloading
- **AND** the player area says "Playing in Picture in Picture"

#### Scenario: Back and closed
- **GIVEN** the channel plays in the floating window
- **WHEN** the user clicks the window's return button, or closes it
- **THEN** returning puts the picture back in the player with no reload, and closing it pauses

#### Scenario: Another channel
- **GIVEN** the channel plays in the floating window
- **WHEN** the user picks another channel in the list
- **THEN** the new channel plays in the same window

### Requirement: Move around in a movie or episode
The system SHALL show the elapsed and remaining time of a playing movie or episode on a progress bar, SHALL skip back or forward 10 seconds, and SHALL move to any point the user drags or slides to, on every platform, never before the start or past the end.

#### Scenario: Skipping on iPhone and iPad
- **GIVEN** a movie playing on iPhone or iPad with the controls showing
- **WHEN** the user taps back 10 or forward 10
- **THEN** the movie moves 10 seconds that way and the times update

#### Scenario: Double tap on iPhone and iPad
- **GIVEN** a movie playing on iPhone or iPad
- **WHEN** the user double taps the left or right half of the picture
- **THEN** the movie skips back or forward 10 seconds

#### Scenario: Dragging the scrubber
- **GIVEN** the controls show on iPhone, iPad or Mac
- **WHEN** the user drags the scrubber
- **THEN** the elapsed time follows the finger or pointer while the picture stays put
- **AND** on release the movie plays from there, or stays paused there if it was paused

#### Scenario: Keys on a Mac
- **GIVEN** a movie playing on a Mac
- **WHEN** the user presses the left or right arrow key, or Space
- **THEN** the movie skips back or forward 10 seconds, or plays and pauses

#### Scenario: Clicking on Apple TV
- **GIVEN** a movie playing on Apple TV
- **WHEN** the user clicks left or right on the remote
- **THEN** the movie skips back or forward 10 seconds and the bar shows the new time

#### Scenario: Sliding while paused on Apple TV
- **GIVEN** a movie paused on Apple TV
- **WHEN** the user slides a finger left or right on the touch surface
- **THEN** a target time moves along the bar, shown above it, while the picture stays where it paused
- **AND** clicking left or right moves the target by 10 seconds
- **AND** select or play/pause plays from the target

#### Scenario: Putting the target back on Apple TV
- **GIVEN** the user moved the target time while paused on Apple TV
- **WHEN** they press Menu
- **THEN** the target goes away and the movie stays paused where it was
- **AND** the next Menu closes the movie

#### Scenario: Select on Apple TV
- **GIVEN** a movie playing on Apple TV with no target time
- **WHEN** the user clicks select
- **THEN** the movie pauses, and the next click plays it
- **AND** holding select still opens the audio and subtitles panel without pausing

#### Scenario: The ends of the title
- **GIVEN** a movie 5 seconds from its start or its end
- **WHEN** the user skips back or forward 10 seconds
- **THEN** it moves to the start, or to the end, which finishes it

#### Scenario: Back from the end
- **GIVEN** a movie that played to its end
- **WHEN** the user skips back or scrubs to an earlier point
- **THEN** it plays from there, not from the start

#### Scenario: A server that cannot skip
- **GIVEN** a movie whose server cannot jump to a point
- **WHEN** the controls show
- **THEN** the player says "This stream can't skip" with them, before the user presses anything
- **AND** skipping or scrubbing leaves the movie playing where it is and says it again for a few seconds

#### Scenario: Before the length is known
- **GIVEN** a title whose length the stream does not give
- **WHEN** the controls show
- **THEN** they show the elapsed time with no bar and no remaining time, and skipping back and forward still works

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on, on iPhone, iPad or Mac
- **WHEN** the user focuses the scrubber
- **THEN** it reads the elapsed time and the length, and swiping up or down skips forward or back 10 seconds

### Requirement: The movie controls show and hide
The system SHALL show the controls of a movie or episode when it starts and on any input, SHALL hide them a few seconds after the last input while it plays, and SHALL keep them while it is paused, while the user drags, and while VoiceOver is on.

#### Scenario: Tap on iPhone and iPad
- **GIVEN** a movie playing on iPhone or iPad with the controls hidden
- **WHEN** the user taps the picture
- **THEN** play/pause, back and forward 10, the scrubber with its times, Close and the track buttons show
- **AND** a second tap hides them, and with no tap they hide after a few seconds

#### Scenario: The pointer on a Mac
- **GIVEN** a movie playing on a Mac
- **WHEN** the pointer moves over the picture
- **THEN** the controls show, and hide a few seconds after it stops moving or a second after it leaves the window

#### Scenario: Apple TV
- **GIVEN** a movie playing full screen on Apple TV with nothing over it
- **WHEN** the user presses play/pause, clicks, or touches the touch surface
- **THEN** the bar shows with the elapsed time, the progress and the remaining time
- **AND** it hides a few seconds later while the movie plays, and stays while it is paused

#### Scenario: Paused
- **GIVEN** the user paused a movie on any platform
- **WHEN** they leave it paused
- **THEN** the controls stay until it plays again

### Requirement: A movie or episode that cannot play says why
The system SHALL show the player's error in place of a movie or episode that fails to open or stops with an error, on every platform, with the same wording as for channels, Try again, and a way back to the page it started from.

#### Scenario: The file cannot be opened
- **GIVEN** the user starts a movie whose server answers with an error or sends something that cannot play
- **WHEN** the player gives up
- **THEN** the error names the reason and the title instead of a black screen
- **AND** Try again loads the title once more from where it was, and Back, Menu on Apple TV or Escape on a Mac returns to the page

#### Scenario: It stops part-way
- **GIVEN** an episode playing
- **WHEN** the stream fails and reconnecting gives up
- **THEN** the same error shows, and Try again picks up from the last time shown

### Requirement: Black around the picture
The system SHALL show pure black around a picture that does not fill the player, on every platform and both playback paths, for movies, episodes and live TV.

#### Scenario: A 4:3 or wide film
- **GIVEN** a movie or episode whose picture is 4:3 or wider than the screen
- **WHEN** it plays full screen
- **THEN** the bars beside or above and below the picture are pure black

#### Scenario: A phone held upright
- **GIVEN** an iPhone held upright
- **WHEN** a movie plays
- **THEN** the screen above and below the picture is pure black

#### Scenario: Before the first frame
- **GIVEN** a movie or episode that is still opening
- **WHEN** the player shows
- **THEN** the area where the picture will be is black
