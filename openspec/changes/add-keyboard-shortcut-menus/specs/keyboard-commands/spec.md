## Purpose

Lets viewers on a Mac or an iPad with a keyboard find Antenna's shortcuts where other apps keep them, in the menu bar, and use them on whichever screen is in front.

## ADDED Requirements

### Requirement: Shortcuts are listed in the menus
The system SHALL list its keyboard commands, each with its key, in the Mac menu bar and in the iPad menu bar: Find in Edit, Zoom In and Zoom Out in View, and a Playback menu and a Go menu between View and Window. Every command that works from the keyboard and is not moving through a list SHALL be in a menu.

#### Scenario: The Mac menu bar
- **GIVEN** a channel playing on Live on a Mac
- **WHEN** the user opens the Playback menu
- **THEN** it lists Pause with Space, Back 15 Seconds with Left Arrow, Forward 30 Seconds with Right Arrow, Mute with M, Volume Up with Command-Up, Volume Down with Command-Down, Add to Multi-view with Command-Shift-M, and the multi-view tile items dimmed

#### Scenario: The iPad menu bar
- **GIVEN** an iPad with a hardware keyboard on Live
- **WHEN** the user holds Command or opens the menu bar from the top of the screen
- **THEN** the same menus show, without Mute and the volume items

#### Scenario: Find
- **WHEN** the user opens the Edit menu on Live, the Guide or Search
- **THEN** it lists Find Channel, Filter Channels or Search with Command-F, and choosing it puts the cursor in that screen's field

#### Scenario: Zoom
- **GIVEN** the Guide is in front
- **WHEN** the user opens the View menu
- **THEN** Zoom In with Command-Plus and Zoom Out with Command-Minus are listed and change the guide's scale, and Command-Equals also zooms in

#### Scenario: iPhone and Apple TV
- **WHEN** the app runs on iPhone or Apple TV
- **THEN** no menus are added and the keys and remote buttons work as before

### Requirement: Menu items follow the screen in front
The system SHALL make each menu item act on the screen in front of the frontmost window, name what it will do there, and dim it when that screen cannot use it. Items SHALL never be hidden for a screen. A command SHALL work when nothing in the window has focus.

#### Scenario: Skipping in the movie player
- **GIVEN** a movie playing
- **WHEN** the user opens the Playback menu
- **THEN** it lists Back 10 Seconds and Forward 10 Seconds, and Left and Right Arrow skip by 10 seconds

#### Scenario: Play while paused
- **GIVEN** the movie is paused
- **WHEN** the user opens the Playback menu
- **THEN** the first item reads Play

#### Scenario: Nothing playing
- **GIVEN** the Movies rows with nothing playing
- **WHEN** the user opens the Playback menu
- **THEN** every item is dimmed and Space starts nothing playing

#### Scenario: After clicking the video on a Mac
- **GIVEN** a channel playing on a Mac and the user has clicked the video, so no control has focus
- **WHEN** they press Space or Command-Down
- **THEN** the channel pauses or the volume goes down

#### Scenario: Two windows
- **GIVEN** two Antenna windows on a Mac or iPad, one playing a channel and one on the Guide
- **WHEN** the user presses Space with the Guide window in front
- **THEN** nothing in the other window pauses

#### Scenario: Multi-view
- **GIVEN** multi-view with three tiles
- **WHEN** the user opens the Playback menu
- **THEN** Select Tile 1 to 3 are listed with Option-Command-1 to 3, Select Tile 4 is dimmed, and Remove Tile is listed with Command-Delete

### Requirement: Typing is never taken by a shortcut
The system SHALL dim every command whose key has no Command, Option or Control modifier while a text field has the keyboard, so the key types into the field. Commands with Command SHALL stay available, except Volume Up, Volume Down and Remove Tile, which a text field uses for moving and deleting.

#### Scenario: Typing in the channel filter
- **GIVEN** a channel playing on Live and the cursor in the filter field
- **WHEN** the user types "m", a space and Left Arrow
- **THEN** the field gets "m ", the cursor moves left, the sound stays on and the channel keeps playing

#### Scenario: Leaving the field
- **GIVEN** the user typed in the filter field
- **WHEN** they press Escape or click the channel list
- **THEN** Space pauses again

### Requirement: Go to a section
The system SHALL offer a Go menu with Live, Guide, Movies, Series and Search on Command-1 to Command-5, in the sidebar's order, and Sources & Settings on Command-Comma. A section the sidebar does not show SHALL be dimmed.

#### Scenario: Jumping to the Guide
- **GIVEN** a channel playing on Live
- **WHEN** the user presses Command-2
- **THEN** the Guide opens and the channel keeps playing, as when the sidebar's Guide is picked

#### Scenario: No movies
- **GIVEN** no source offers movies or series
- **WHEN** the user opens the Go menu
- **THEN** Movies and Series are dimmed and Command-3 and Command-4 do nothing

#### Scenario: Settings
- **WHEN** the user presses Command-Comma
- **THEN** Sources & Settings opens

### Requirement: Moving through lists stays off the menus
The system SHALL keep the arrow keys for moving through the channel list, the guide grid, search results and a series' seasons, Return for opening or playing what is selected, and Escape for going back, working as the screens' own specs say, without listing them in a menu.

#### Scenario: The channel list
- **GIVEN** Live with a channel playing
- **WHEN** the user presses Down Arrow then Return
- **THEN** the focus ring moves to the next channel and Return plays it, as before this change

#### Scenario: Escape
- **GIVEN** a title page open over Movies on a Mac
- **WHEN** the user presses Escape
- **THEN** the page closes, and no menu item lists Escape

### Requirement: Shortcuts stay clear of the system's
The system SHALL use no key combination macOS or iPadOS reserves for itself or for standard menu items, and no two commands that can be available at the same time SHALL share a key.

#### Scenario: A reserved combination
- **WHEN** the list of commands is checked
- **THEN** none uses Command-Q, Command-W, Command-H, Command-M, Command-N, Command-Tab, Command-Space, Command-Grave, Control-Command-F, Control-Command-Q, Command-Shift-3, Command-Shift-4, Command-Shift-5, or the Edit menu's Command-X, Command-C, Command-V, Command-Z and Command-A

#### Scenario: Left and Right Arrow
- **GIVEN** Left and Right Arrow skip in the player and on Live with timeshift, and pick a season on a series page
- **WHEN** a series page is in front and nothing plays
- **THEN** the arrows pick the season, and the Playback skip items are dimmed
