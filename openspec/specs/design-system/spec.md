# design-system Specification

## Purpose

The look and layout rules every Antuna screen follows on Apple TV, iPhone,
iPad and Mac, so the living-room viewer, the on-the-go viewer and the movie
and series watcher get one consistent app, and reviewers can check each
screen against its board. Tokens, type scale, layout patterns and shared
components are in the reference file next to this spec.

## Requirements

### Requirement: Every screen has a board before its change is proposed
A screen MUST have a board in the design-system boards folder before a change
that describes it is proposed. Each board is one screen exported from the
owner's design canvas at https://claude.ai/artifact/T98LnnsYB3oZfBrQQSsFJm,
and its inline styles are the measurements for sizes, spacing, colors and
type. A change that describes a screen MUST name its boards and the
design-system requirements that apply.

#### Scenario: Proposing a change for an undrawn screen
- **GIVEN** a screen with no board
- **WHEN** someone proposes a change that describes it
- **THEN** the board is drawn on the canvas and exported to the boards folder first

#### Scenario: Reading a measurement
- **WHEN** an implementer needs a size, spacing, color or type size for a screen
- **THEN** they read it from the inline style on the board, not from a guess

#### Scenario: A change names its boards and rules
- **WHEN** a reviewer reads a change that describes a screen
- **THEN** its design names the board files and the design-system requirements that apply

### Requirement: Visual changes update the boards in the same change
An intentional visual change MUST update the affected boards, and the
design-system reference when a token or pattern changes, in the same change
as the code.

#### Scenario: Changing a screen's look on purpose
- **WHEN** a change alters how a screen looks on purpose
- **THEN** the same change updates that screen's board

### Requirement: Undrawn states are listed and drawn before implementation
A change MUST list each state it describes that is not on a board (focused,
empty, loading, error) under "Not drawn" with the text style it uses. Those
states MUST be drawn before the implementing pull request opens.

#### Scenario: A described state missing from the board
- **GIVEN** a change describes an empty state that no board shows
- **WHEN** a reviewer checks the change
- **THEN** the state is listed under "Not drawn" with its text style, or the reviewer reports it

#### Scenario: Implementation starts with a state still undrawn
- **GIVEN** a state listed under "Not drawn"
- **WHEN** the implementing pull request opens before the state is drawn
- **THEN** the reviewer marks it not ready

### Requirement: Deviations from a design rule are named
A screen MUST NOT depart from a design-system requirement unless its change,
or the spec of the capability that owns the screen, names the requirement
and gives the reason in one sentence. A mismatch with the board that the change did not name MUST be
reported by the reviewer.

#### Scenario: A named deviation
- **GIVEN** a change says search results use a compact channel row and why
- **WHEN** a reviewer compares the screen with the channel row rule
- **THEN** the compact row is accepted

#### Scenario: A deviation named in a capability spec
- **GIVEN** the Apple TV shell spec says the open tab is filled white while focus is in its content, and why
- **WHEN** a reviewer compares the tab bar with the focus rule
- **THEN** the white open tab is accepted

#### Scenario: An unnamed deviation
- **WHEN** a screen differs from its board in a way the change did not name
- **THEN** the reviewer reports it

### Requirement: Live video keeps playing under overlays
On Apple TV, showing the channel overlay, the zap bar or the guide while a
channel plays MUST keep the same picture playing without a pause or
restart. Search is a tab, not an overlay: opening it MUST pause the channel,
as Movies and Series do.

#### Scenario: Opening the channel overlay
- **GIVEN** a channel is playing on Apple TV
- **WHEN** the viewer opens the channel overlay
- **THEN** the picture keeps playing behind the overlay without a pause, black frame or rebuffer

#### Scenario: Opening the guide from live TV
- **GIVEN** a channel is playing on Apple TV
- **WHEN** the viewer opens the guide
- **THEN** the same stream continues in the guide's picture-in-picture without restarting

#### Scenario: Opening Search from live TV
- **GIVEN** a channel is playing on Apple TV
- **WHEN** the viewer opens Search
- **THEN** the channel pauses behind it, and Live plays on from there when the viewer returns, or tunes it again once it has stopped after 30 seconds

### Requirement: Focus is the lifted white card
On Apple TV the focused element MUST use the system focus effect for its
control: the light platter with dark text, the lift, the shadow and the
motion that follows the remote. The parts the reference lists as drawn by
the app use the same light card, with the highlight hover effect on the
focused one only. Text in a focused row MUST stay readable. Borders, rings
and focus shown by scale alone are not allowed, and nothing at rest is
white or outlined.

#### Scenario: Moving focus down a list
- **WHEN** the viewer moves focus to a row on Apple TV
- **THEN** that row becomes a light card with dark text and a shadow, and it tilts slightly as the viewer rests a thumb on the remote
- **AND** no other element on screen is filled white

#### Scenario: Rows at rest
- **GIVEN** the channel overlay is open on Apple TV with the highlight on a channel
- **WHEN** the viewer looks at the other channels, the groups, the programmes coming next and the buttons under them
- **THEN** none of them has a line around it

#### Scenario: Focus without the card
- **WHEN** a reviewer finds a focused element shown only by a colored border, a white ring or a size change
- **THEN** it fails this requirement

#### Scenario: Text that vanishes on focus
- **WHEN** a reviewer focuses a Settings row on Apple TV
- **THEN** its title and value are dark on the light platter, never light text on light

#### Scenario: An element that only holds focus
- **GIVEN** the full-screen picture, a loading screen, or a screen whose only content is a line of text
- **WHEN** it has focus on Apple TV
- **THEN** it shows no card and no other focus effect, because there is nothing on it to lift

### Requirement: One accent color per profile
Each profile MUST have one accent color from a fixed set of five, Blue by default, and it MUST be the app's tint, so system controls draw with it. It SHALL appear only on progress fills, the guide's now line, the NOW and UP NEXT badges, links, the selected iPhone tab, the app icon, and system controls that tint by default. Eyebrows, titles, icons and decoration are not tinted. The Antuna mark's tips are the one exception: they are brand teal on every profile.

#### Scenario: The five accents
- **WHEN** a reviewer opens the accent choices
- **THEN** they are Blue, Teal, Amber, Pink and Violet, and a profile that never picked one shows Blue

#### Scenario: A tinted icon
- **WHEN** a reviewer finds an icon or label tinted in a color other than the current profile's accent
- **THEN** it fails this requirement

#### Scenario: Accent on a decorative element
- **WHEN** the accent appears on something that is not progress, the now line, a NOW or UP NEXT badge, a link, the selected iPhone tab, the app icon or a system control's tint
- **THEN** it fails this requirement

#### Scenario: Two accents on one screen
- **GIVEN** the current profile's accent is Teal
- **WHEN** a reviewer finds Blue, or any accent but Teal, on a progress bar, badge, link or system control
- **THEN** it fails this requirement

#### Scenario: The whole app follows the profile
- **GIVEN** Dad's accent is Blue and Kids's is Amber
- **WHEN** the device switches from Dad to Kids
- **THEN** progress bars, the now line, the badges, links, switches, the prominent button and the selected iPhone tab all show Amber

#### Scenario: Contrast of every accent
- **WHEN** a reviewer measures any of the five accents against the app background, a raised row or glass
- **THEN** the contrast is at least 4.5:1

#### Scenario: Focus on Apple TV
- **GIVEN** an Apple TV on a profile whose accent is Pink
- **WHEN** a row or button has focus
- **THEN** it is the light platter with dark text, with no pink ring or pink fill

#### Scenario: The app icon
- **WHEN** a reviewer checks the standard app icon
- **THEN** it is the Antuna a in near-white with teal tips on the dark ground, and uses no other color

#### Scenario: The mark on an Amber profile
- **GIVEN** the current profile's accent is Amber
- **WHEN** the mark shows on a loading screen
- **THEN** its tips are teal and the progress on the same screen is amber

#### Scenario: An eyebrow over a title
- **WHEN** a reviewer finds an eyebrow such as "RECENTLY ADDED" or "SERIES" in the accent
- **THEN** it fails this requirement

#### Scenario: Connect on iPhone
- **WHEN** the add-source sheet shows on iPhone
- **THEN** Connect is the prominent system button in the current profile's accent

### Requirement: Text stays above the platform caption floor
Text MUST never be smaller than the platform's caption minimum in the
reference type scale: 23 pt on Apple TV, 13 pt on iPad and Mac, 12 pt on
iPhone.

#### Scenario: Small metadata on Apple TV
- **WHEN** a screen on Apple TV shows a caption, a footnote or legal text
- **THEN** it is at least 23 pt

#### Scenario: Small metadata on iPhone
- **WHEN** a screen on iPhone shows a caption
- **THEN** it is at least 12 pt

### Requirement: Targets are large enough to hit
Touch targets MUST be at least 44 pt in each direction. Focusable rows on
Apple TV MUST be at least 64 pt tall.

#### Scenario: A small button on iPhone
- **WHEN** a reviewer measures a tappable control on iPhone, iPad or Mac
- **THEN** its hit area is at least 44 by 44 pt

#### Scenario: A list row on Apple TV
- **WHEN** a reviewer measures a focusable row on Apple TV
- **THEN** it is at least 64 pt tall

### Requirement: Channel rows share one anatomy
On every platform that lists channels, a channel row MUST show, in this
order, the channel number in muted tabular digits, the logo tile, the name,
the current programme title and a 3 to 4 pt accent progress bar. A channel
with catch-up shows a clock-arrow glyph at the trailing edge.

#### Scenario: A channel list on any platform
- **WHEN** a viewer opens a channel list on Apple TV, iPhone, iPad or Mac
- **THEN** each row shows number, logo, name, current programme and progress bar in that order

#### Scenario: A channel with catch-up
- **GIVEN** a channel whose provider offers catch-up
- **WHEN** its row is shown
- **THEN** a clock-arrow glyph sits at the row's trailing edge

### Requirement: A current programme always shows its progress
Wherever a programme that is on now is shown, its progress bar MUST be shown
with it: in channel rows, now panels, the zap bar, the player scrubber and
continue-watching cards.

#### Scenario: Now and next panel
- **WHEN** the viewer sees what is on now in a now panel or the zap bar
- **THEN** the current programme has a progress bar showing how far it has run

#### Scenario: Current programme without a bar
- **WHEN** a reviewer finds a current programme title shown without its progress bar
- **THEN** it fails this requirement

### Requirement: Channels without a logo show initials
A channel whose logo has not loaded MUST show a tile in the placeholder color
with up to four characters of the channel's initials. It MUST never show an
empty frame or a system glyph.

#### Scenario: Logo missing from the playlist
- **GIVEN** a channel with no logo link
- **WHEN** its row is shown
- **THEN** a placeholder-colored tile shows up to four characters of its initials

#### Scenario: Logo still loading or failed
- **GIVEN** a channel whose logo has not loaded yet or failed to load
- **WHEN** its row is shown
- **THEN** the initials tile is shown, not an empty frame or a system icon

### Requirement: Movies and series open content first
The Movies and Series screens MUST open with a hero and rows of posters. A
plain list MUST never be the first view.

#### Scenario: Opening Movies
- **WHEN** the viewer opens Movies
- **THEN** the first view is a hero followed by poster rows, not a plain list

### Requirement: One search across everything
Search MUST be a single field that searches channels, guide programmes,
movies and series together, with results in sections and the matched text
highlighted.

#### Scenario: Searching a name that is both a channel and a film
- **WHEN** the viewer types a word that matches a channel and a movie
- **THEN** one result list shows both, in separate sections
- **AND** the matched text is highlighted in each result

### Requirement: Accessibility identifiers follow the board
Accessibility identifiers MUST start with the screen prefix of the board the
element belongs to, from the prefix list in the reference. Element names MUST
come from the board's comments and labels.

#### Scenario: An element on the zap bar
- **WHEN** a reviewer inspects the progress bar on the zap bar
- **THEN** its accessibility identifier uses the zap bar's prefix and the element name from the board

#### Scenario: An unknown prefix
- **WHEN** an identifier uses a prefix that is not in the reference list
- **THEN** it fails this requirement

### Requirement: Nothing fake and nothing bundled
The app MUST draw no fake status bars and bundle no channels, titles,
third-party logos or artwork. Sample names on the boards are for layout and
never ship, and sample logins never use a real name. Copy MUST NOT name the
user, the user's device or a state the app cannot see. Naming the platform
is allowed.

#### Scenario: Fresh install
- **WHEN** the user opens the app before adding a source
- **THEN** no channel, title, logo or artwork appears that the user did not supply

#### Scenario: Copy that names the device
- **WHEN** a reviewer finds copy such as "your iPhone", a device name, or a notification on another device
- **THEN** it fails this requirement

#### Scenario: Copy that names the platform
- **WHEN** copy says "this Apple TV" or "Antuna on iPhone"
- **THEN** it passes

### Requirement: Text meets contrast minimums
Text MUST reach a contrast ratio of at least 4.5:1 against what it sits on,
including muted captions, and at least 3:1 for text at 24 pt and above.

#### Scenario: Muted caption on the background
- **WHEN** a reviewer measures a muted caption on the app background
- **THEN** its contrast is at least 4.5:1

#### Scenario: Muted text on the focused card
- **WHEN** a reviewer measures muted text on the focused white card
- **THEN** its contrast is at least 4.5:1

### Requirement: Nothing shows before the paywall
The app MUST show none of these screens until the user has an active
entitlement, because Antuna has no free tier.
Onboarding SHALL start after the paywall.

#### Scenario: First launch with no purchase
- **GIVEN** a user with no entitlement
- **WHEN** they open the app
- **THEN** they see the paywall and nothing else

#### Scenario: First launch after buying
- **GIVEN** a user who has just unlocked the app
- **WHEN** the paywall closes
- **THEN** onboarding starts

### Requirement: Loading shows real progress per step
A load with several steps, such as onboarding or a source refresh, MUST show
the state of each step with real counts as they arrive. A single spinner for
the whole job is not allowed.

#### Scenario: Adding a large source
- **WHEN** a source is loading its channels and then its guide
- **THEN** each step shows its own state and the counts update as they arrive

#### Scenario: One spinner for everything
- **WHEN** a reviewer finds a multi-step load shown as a single spinner
- **THEN** it fails this requirement

### Requirement: Layouts mirror in right-to-left languages
In a right-to-left language every screen MUST mirror its horizontal layout:
what sits at the leading edge in English sits at the right edge, rows and
chips run from the right, and back and disclosure arrows point the other
way. Photos, posters, channel logos and the video picture MUST NOT be
flipped.

#### Scenario: A channel row in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the viewer opens the Live list on any platform
- **THEN** each row reads from the right in the order the English row reads from the left
- **AND** on iPhone, iPad and Mac that is the logo tile, the name with its channel number after it, the current programme and progress bar
- **AND** on Apple TV that is the channel number, logo tile, name, current programme and progress bar
- **AND** the catch-up glyph sits at the row's left edge

#### Scenario: Group chips in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer looks at the day chips in the Guide or the genre chips in Movies
- **THEN** the first chip is at the right and the chips scroll toward the left

#### Scenario: The group button and sheet in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer looks at the group button above the Live list and opens it
- **THEN** the group's name starts at the right with the count and chevron to its left
- **AND** in the Groups sheet each row reads from the right, with the checkmark at the right and the count at the left

#### Scenario: A channel logo with text in it
- **GIVEN** the app is in Arabic
- **WHEN** a channel logo that contains Latin letters is shown
- **THEN** the logo is drawn as supplied, not mirrored

#### Scenario: The Apple TV channel overlay
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens the channel overlay
- **THEN** the groups column is at the right, the channels in the middle and now and next at the left

### Requirement: Progress runs in the reading direction
Every progress bar, the player scrubber and the timeshift bar MUST fill from
the leading edge, so in a right-to-left language they fill from the right.
The digits inside a time or number MUST keep their order. The left and right
arrow keys and the Siri Remote's left and right MUST skip toward the end of
the bar they point at, so in a right-to-left language right skips back and
left skips forward, on the keyboard and in the Playback menu.

#### Scenario: A programme's progress in Arabic
- **GIVEN** the app is in Arabic and a programme is half over
- **WHEN** its channel row is shown
- **THEN** the right half of the bar is filled

#### Scenario: The scrubber in Arabic
- **GIVEN** the app is in Arabic and the viewer is behind live
- **WHEN** the player controls show
- **THEN** the start time is at the right, the live edge at the left, and dragging toward the left moves forward in time

#### Scenario: The arrow keys in Arabic
- **GIVEN** the app is in Arabic and a movie is playing on iPhone, iPad or Mac with a keyboard
- **WHEN** the viewer presses Left Arrow
- **THEN** the movie skips forward 10 seconds, toward the left end of the bar
- **AND** Right Arrow skips back 10 seconds, and on Live with timeshift Right skips back 15 seconds and Left forward 30

#### Scenario: The Playback menu in Arabic
- **GIVEN** the app is in Arabic on a Mac or an iPad with a keyboard
- **WHEN** the viewer opens the Playback menu
- **THEN** Back is listed with Right Arrow and Forward with Left Arrow

#### Scenario: The Siri Remote in Arabic
- **GIVEN** the app is in Arabic on Apple TV and the controls of a movie or of paused live TV show
- **WHEN** the viewer clicks the right side of the touch surface
- **THEN** the picture skips back, toward the right end of the bar

### Requirement: The guide's time axis follows the reading direction
In a right-to-left language the guide grid MUST place the channel column at
the right edge and run time from right to left: earlier programmes to the
right, later ones to the left, with the now line moving left as time
passes. The iPhone guide's programme strips MUST run the same way.

#### Scenario: The Apple TV guide in Arabic
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens the guide
- **THEN** the channel column is at the right, the programme on now sits next to it, and later programmes follow to the left

#### Scenario: The iPhone guide in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer scrolls a channel's programme strip
- **THEN** the current programme is at the right and later programmes come in from the left

#### Scenario: The guide in English
- **WHEN** the app is in a left-to-right language
- **THEN** the guide keeps the channel column at the left and time running to the right, as today

### Requirement: Playback glyphs keep their meaning
Play, pause, Picture in Picture, AirPlay and track glyphs MUST NOT flip. In
a right-to-left language the skip back and skip forward buttons MUST swap
sides so skip back is on the right, and each MUST keep the glyph that shows
its time direction.

#### Scenario: The player strip in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the player controls show on iPhone, iPad or Mac
- **THEN** the play triangle points right as in English
- **AND** skip back sits to the right of play and skip forward to its left

### Requirement: Focus moves where the remote points
On Apple TV a swipe or click MUST move focus to the element drawn in that
direction on screen, in every language. In a right-to-left language the
first focus on a screen MUST land on the rightmost element of the first row.

#### Scenario: Moving through the guide in Arabic
- **GIVEN** the app is in Arabic and focus is on the programme on now in the guide
- **WHEN** the viewer swipes left
- **THEN** focus moves to the next programme, which is drawn to the left

#### Scenario: First focus in Arabic
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens Movies
- **THEN** focus starts on the rightmost poster of the first row

### Requirement: Copy fits in every language
App copy MUST fit its control or line in every shipped language at the
default text size: a label wraps or the layout grows, and it MUST NOT be
cut off with an ellipsis where the English is not. Text MUST NOT shrink
below the platform caption floor to fit. Badges are uppercase only in
scripts that have case.

#### Scenario: A long German button
- **GIVEN** the app is in German
- **WHEN** the paywall shows its restore and purchase buttons
- **THEN** each label is shown in full

#### Scenario: An Arabic badge
- **GIVEN** the app is in Arabic
- **WHEN** a channel with catch-up shows its badge
- **THEN** the badge text is in Arabic, in the badge outline, at least as large as the platform caption floor

### Requirement: Controls use system styles
Buttons, toggles, pickers, text fields and lists MUST use a system style on
every platform: bordered, bordered prominent, glass, glass prominent,
borderless, or card on Apple TV. A screen MUST NOT draw its own fill, border
or focus look for a control. The only exceptions are the parts the reference
lists as drawn by the app: guide programme blocks, channel overlay rows, zap
bar sections, multi-view tiles and the passcode digits.

#### Scenario: A primary button on any platform
- **WHEN** a reviewer finds the main action of a screen, such as Connect, Start watching or Play
- **THEN** it uses the prominent system style for that platform and gets the platform's pressed and focused looks without code of its own

#### Scenario: A custom-drawn button
- **WHEN** a reviewer finds a button whose fill, border, scale or shadow is drawn by the app and it is not on the reference's exception list
- **THEN** it fails this requirement

#### Scenario: The channel overlay's buttons
- **WHEN** the channel overlay shows Watch, the favorite star and Add to multi-view on Apple TV
- **THEN** Watch looks like Watch in the Guide, and the star and Add to multi-view like More info on the Movies banner

#### Scenario: A glyph whose meaning is unclear
- **WHEN** a reviewer finds a button shown only by a glyph not everyone reads the same way, such as a plus for My list
- **THEN** it fails this requirement; the button says what it does in words

#### Scenario: An outlined button
- **WHEN** a reviewer finds a button drawn as a line around its label, such as LIVE while behind live
- **THEN** it fails this requirement; the button is a system style or a plain surface instead

#### Scenario: A poster on Apple TV
- **WHEN** the viewer moves focus to a poster in a Movies or Series row
- **THEN** the poster lifts, grows and tilts with the remote the way posters do in the TV app, with no drawn ring

### Requirement: Type uses text styles
Text MUST use the platform's text styles (large title, title 1 to 3,
headline, body, callout, subheadline, footnote, caption 1 and 2), with a
weight or design change where the board asks for one. A fixed point size is
allowed only for glyphs that are not text, for the channel number entry, and
for the guide grid's time labels. A board gives the size; the reference maps
each size to its text style.

#### Scenario: Body copy on Apple TV
- **WHEN** a reviewer checks a description line on Apple TV
- **THEN** it is the body text style, 29 pt, and changes size with the system when the platform scales text

#### Scenario: Larger text on iPhone
- **GIVEN** the user has picked a larger text size on iPhone
- **WHEN** they open the add-source sheet
- **THEN** every label and field grows with it and nothing is cut off

#### Scenario: A fixed size in a screen
- **WHEN** a reviewer finds a fixed point size on text that is not on the exception list
- **THEN** it fails this requirement

### Requirement: Modals are system presentations
A screen shown over another one MUST be a system sheet, full-screen cover,
alert, confirmation dialog or popover. Its content MUST fit the presentation
it uses at the platform's size: on Apple TV a sheet holds no more than its
own width, and a layout wider than that uses a full-screen cover. A modal
MUST have a title and a visible way out (Cancel, Done or Back) in its
content, and Menu on the Siri Remote MUST close it.

#### Scenario: Adding a source from Settings on Apple TV
- **WHEN** the viewer selects Add a source in Settings on Apple TV
- **THEN** the add-source screen opens as one system presentation with the system's dimmed and blurred backdrop
- **AND** every field, the QR card and the buttons are fully visible without scrolling sideways

#### Scenario: Leaving a modal with the remote
- **GIVEN** the add-source screen is open on Apple TV
- **WHEN** the viewer presses Menu with nothing typed
- **THEN** it closes and focus returns to Add a source

#### Scenario: A modal that crops its content
- **WHEN** a reviewer finds a field, button or card cut off at the edge of a sheet
- **THEN** it fails this requirement

### Requirement: Forms use the platform form style
Screens where the user types or picks settings (add a source, source
details, sign-in, Settings, preferences, profiles) MUST use the system
grouped form or list. On Apple TV each field is a row with its label and
current value, and selecting it opens the system keyboard. A choice among
values MUST be a row that shows its label and current value, never an
unlabeled segmented control. Adding and editing the same kind of record MUST
use the same rows.

#### Scenario: Add and edit look alike
- **WHEN** a reviewer compares the add-source screen with the source details screen on the same platform
- **THEN** both use the same grouped rows for name, address and login

#### Scenario: A preference on Apple TV
- **WHEN** the viewer moves focus to the guide window preference in Settings on Apple TV
- **THEN** the row reads "Guide window" with its value, and selecting it lists the choices with a checkmark on the current one

#### Scenario: Typing a server address on Apple TV
- **WHEN** the viewer selects the Server row
- **THEN** the system keyboard opens full screen, and the row shows the typed address after it closes

### Requirement: Liquid Glass stays on the navigation layer
Tab bars, toolbars, floating controls over video, and buttons in sheets MUST
use Liquid Glass through the system components or the glass effect. Rows,
cards, posters, the guide grid and other content MUST NOT use glass; panels
in the content layer use the materials in the reference. Glass MUST NOT sit
on glass. A glass element MUST NOT also have a fill, a stroke or border, or a
shadow of its own; the system draws its edge and highlight. An element is
either glass or a plain surface, never both.

#### Scenario: The player controls over video
- **WHEN** the player controls show over a playing picture on iPhone, iPad or Mac
- **THEN** the buttons sit on glass and the picture shows through them

#### Scenario: Glass on a content card
- **WHEN** a reviewer finds the glass effect on a row, poster or guide block
- **THEN** it fails this requirement

#### Scenario: Glass is never combined with a fill or a stroke
- **WHEN** a reviewer finds a glass button, capsule or card that also draws a background color, an outline or a drop shadow
- **THEN** it fails this requirement

#### Scenario: Round buttons over the picture look alike
- **GIVEN** a title is playing full screen on iPhone, iPad or Mac with the controls shown
- **WHEN** the viewer looks at Close, the track buttons and the skip and pause buttons
- **THEN** each one sits on glass with the same edge, and none is a dark disc

### Requirement: One spacing and radius scale
Padding and gaps MUST come from the spacing scale in the reference (4, 8,
12, 16, 24, 32, 48, 64, 80). Corner radii MUST be one of the four in the
reference: small, medium, large, or capsule, or follow the container with a
concentric shape. Buttons and chips are capsules.

#### Scenario: A new card
- **WHEN** a reviewer measures the corner radius of a card on any platform
- **THEN** it is the large radius for that platform or concentric with its container

#### Scenario: An off-scale value
- **WHEN** a reviewer finds a padding of 14 or a radius of 9
- **THEN** it fails this requirement

### Requirement: Apple TV content stays in the safe area
On Apple TV, text, buttons and focusable items MUST stay at least 80 pt from
the left and right edges and 60 pt from the top and bottom, including the
room a focused item takes when it grows. Full-bleed art, video and scrims
may run to the edge.

#### Scenario: A row of cards
- **WHEN** the viewer focuses the first or last card in a row on Apple TV
- **THEN** the grown card and its shadow stay inside the safe area

#### Scenario: The kind picker
- **WHEN** the add-source kinds show on Apple TV
- **THEN** the first card starts at least 80 pt from the left edge

#### Scenario: The guide
- **WHEN** the Guide tab shows on Apple TV
- **THEN** the small picture and the channel column start 80 pt from the left edge, and the last half-hour column ends 80 pt from the right edge

#### Scenario: Movies and Series
- **WHEN** the Movies or Series tab shows on Apple TV
- **THEN** the hero's copy and buttons, the preview's copy and the first card of each row start 80 pt from the left edge, over art that still runs to the edge

#### Scenario: Search
- **WHEN** the Search tab shows results or recent searches on Apple TV
- **THEN** they start 80 pt from the left edge and end 80 pt from the right edge

#### Scenario: Typing a channel number
- **WHEN** the viewer types a channel number on a keyboard on Apple TV
- **THEN** the number box sits 80 pt from the left edge and 60 pt from the top

#### Scenario: The paywall
- **WHEN** the paywall shows on Apple TV
- **THEN** the wordmark sits 80 pt from the left and 60 pt from the top, and the legal line ends 60 pt above the bottom edge

### Requirement: Pages cover what is behind them
A page or panel opened over another screen MUST either hide that screen
with an opaque background or blur and dim it with the system backdrop or a
material from the reference. Text from the screen behind MUST never show
through or under the page's own text. Live video under the Apple TV live
overlays is the one screen allowed to stay visible, behind the overlay scrim.

#### Scenario: Settings opened from the Guide on Apple TV
- **GIVEN** the Guide is open on Apple TV
- **WHEN** the viewer opens Sources and Settings from the tab bar
- **THEN** no part of the guide grid or its programme text shows through Settings

#### Scenario: A modal over Settings
- **WHEN** the add-source screen opens over Settings on Apple TV
- **THEN** Settings behind it is dimmed and blurred by the system and none of its text competes with it

#### Scenario: A stand-in screen behind a modal
- **GIVEN** a tab that shows a placeholder or empty state
- **WHEN** a modal opens over it
- **THEN** the placeholder's text is not readable through the modal

### Requirement: Content clears the tab bar
On Apple TV a page's first line of content MUST start below the tab bar
while the bar shows, and nothing scrolls under the bar without the system
scroll edge effect. Titles, eyebrows, search fields and toolbar buttons MUST
NOT overlap the bar, the Antuna mark or the clock.

#### Scenario: Opening Settings
- **WHEN** Sources and Settings opens on Apple TV
- **THEN** its title is not drawn under or behind the tab bar

#### Scenario: The Movies hero
- **WHEN** the viewer opens Movies on Apple TV
- **THEN** the hero's eyebrow and title start below the tab bar and the Antuna mark

### Requirement: Empty and error states share one layout
Every empty, unavailable and error state MUST use one layout: a symbol, a
title in the title style for the platform, a message in body, and up to two
actions in system button styles, the first of which moves the user forward.
A screen MUST show one such state at a time.

#### Scenario: No channels on Apple TV
- **GIVEN** every source loaded without channels
- **WHEN** Live opens on Apple TV
- **THEN** it shows a symbol, "No channels yet", a line per source, and Open Settings and Try again as buttons

#### Scenario: Two states at once
- **WHEN** a reviewer finds an empty player placeholder and a separate error message on the same screen
- **THEN** it fails this requirement

### Requirement: The scrim blends into the art
Where copy sits over a picture, on the Movies and Series banner, the Apple
TV preview and the title pages, the darkening behind it MUST span the whole
picture and change smoothly, darkest under the copy and lighter away from
it, with no edge inside the picture. It MUST sit under the copy in
right-to-left languages too. On iPhone the section's name and the genre
button at the top of the banner MUST sit on a darkening of their own that
fades into the art below them.

#### Scenario: The Apple TV banner
- **WHEN** the viewer opens Movies or Series on Apple TV
- **THEN** the banner art darkens gradually from the left edge toward the right, with no line where the darkening stops

#### Scenario: The iPhone banner
- **WHEN** the user opens Movies on iPhone
- **THEN** the band under the copy fades into the art above it, with no line across the picture

#### Scenario: The iPhone header on a white picture
- **GIVEN** the banner shows a title whose picture is white at the top
- **WHEN** the user opens Series or Movies on iPhone
- **THEN** "Series" or "Movies", "All series" or "All movies", its count and its chevron are legible on a darker band
- **AND** the band fades into the art below the genre button, with no line across the picture

#### Scenario: A title page in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the viewer opens a title page on Apple TV, iPad or Mac
- **THEN** the darkest part of the backdrop is at the right, under the copy

### Requirement: Text on the accent is dark
Text and glyphs drawn on an accent fill MUST be the dark ground color, never
white: a prominent button's label, a picked chip, a NOW, UP NEXT or catch-up
badge, the now line's time tag and a check mark in an accent circle. The
dark label MUST reach 4.5:1 on each of the five accents. On Apple TV a
focused button keeps the system's light platter with dark text.

#### Scenario: Connect on iPhone
- **GIVEN** the current profile's accent is Blue
- **WHEN** the add-source sheet shows Connect
- **THEN** Connect is filled with the accent and its label is dark

#### Scenario: Every accent
- **WHEN** a reviewer measures the label of a prominent button on Blue, Teal, Amber, Pink or Violet
- **THEN** its contrast is at least 4.5:1

#### Scenario: A white label
- **WHEN** a reviewer finds white text or a white glyph on an accent fill on iPhone, iPad or Mac
- **THEN** it fails this requirement

#### Scenario: A picked chip
- **WHEN** the viewer picks a season or a genre chip on iPhone, iPad or Mac
- **THEN** the picked chip is filled with the accent and its name is dark

#### Scenario: Focus on Apple TV
- **WHEN** a button has focus on Apple TV
- **THEN** it is the light platter with dark text, as before

### Requirement: The Antuna mark
The app, its icons and the website MUST draw the Antuna mark from one set of shapes: the word "antuna" in round monoline letters, whose last "a" is a tuna head with a mouth and a soft tail, a play triangle through its middle and two antennae with round tips on top. Where the word does not fit, the a stands alone with its antennae. The still mark has no eye.

#### Scenario: The still mark
- **WHEN** a reviewer looks at the mark when it is not moving
- **THEN** the play triangle sits in the middle of the last a as the play button, and there is no eye

#### Scenario: A narrow place
- **WHEN** the mark has to fit a square, such as the app icon or the launch splash
- **THEN** it is the last a with its antennae, without the other letters

### Requirement: The mark's colors
On a dark ground the mark's letters MUST be #F2F4F8 and its tips teal #4FD1C5; on a light ground the letters MUST be #0B0E13 and the tips #119C8F. The play triangle and the mouth MUST show whatever is behind the mark.

#### Scenario: The mark on the dark ground
- **WHEN** a reviewer looks at the mark on the app's dark ground
- **THEN** the letters are near-white and the two tips teal

#### Scenario: The mark on a light ground
- **WHEN** the mark appears on a light page
- **THEN** the letters are near-black and the tips a darker teal

#### Scenario: The mark over a picture
- **GIVEN** the mark drawn over a photo or a gradient
- **WHEN** a reviewer looks at the play triangle and the mouth
- **THEN** they see the picture through them, not a patch of the app's ground color

### Requirement: The mark moves at three moments
The mark SHALL move only at three moments, Hello, Tuning and Got it, each tied to something the user did or is waiting for, and SHALL otherwise stand still. Each moment SHALL look the same on iPhone, iPad, Mac and Apple TV.

#### Scenario: Hello
- **WHEN** Hello plays
- **THEN** over 3.2 s the letters draw from left to right, the last a lands as a solid head, the play triangle opens in it, the antennae rise and their tips pop, and the mouth opens once
- **AND** the triangle slides forward and up to become a round eye, blinks once and slides back to be the play button

#### Scenario: Tuning
- **GIVEN** a wait that lasts ten seconds
- **WHEN** Tuning plays
- **THEN** the antennae keep leaning from side to side, once every 2.4 s, and the tips send out faint teal rings in turn
- **AND** the triangle has moved forward to be the eye, looks the way the antennae lean and blinks now and then, and the mouth opens and closes slowly

#### Scenario: Got it
- **WHEN** Got it plays
- **THEN** over 1.2 s the tail flicks once, the tips hop, the eye squints, the mouth gulps, and the eye slides back to the middle to become the play button

#### Scenario: Hello and Got it end on the still mark
- **WHEN** Hello has played for 3.2 s, or Got it for 1.2 s
- **THEN** the mark stands still with the play triangle in the middle and no eye

#### Scenario: Nothing to wait for
- **WHEN** a reviewer finds the mark moving where no screen is opening, loading or confirming
- **THEN** it fails this requirement

### Requirement: Reduce Motion stills the mark
When the system's Reduce Motion setting is on, the mark SHALL NOT draw, lean, hop or slide. Hello SHALL fade the still mark in over 0.4 s, Got it SHALL fade it from half to full strength over 0.4 s, and Tuning SHALL pulse the tips' opacity slowly while everything else stands still.

#### Scenario: Hello with Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the welcome screen opens
- **THEN** the still mark fades in and nothing on it moves

#### Scenario: Tuning with Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the Apple TV loading screen shows
- **THEN** only the two tips change, dimming and brightening every 2.4 s, and no eye appears
