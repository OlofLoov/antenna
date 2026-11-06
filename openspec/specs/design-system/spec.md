# design-system Specification

## Purpose

The look and layout rules every Antenna screen follows on Apple TV, iPhone,
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
A screen MUST NOT depart from a design-system requirement unless its change
names the requirement and gives the reason in one sentence. A mismatch with the board that the change did not name MUST be
reported by the reviewer.

#### Scenario: A named deviation
- **GIVEN** a change says search results use a compact channel row and why
- **WHEN** a reviewer compares the screen with the channel row rule
- **THEN** the compact row is accepted

#### Scenario: An unnamed deviation
- **WHEN** a screen differs from its board in a way the change did not name
- **THEN** the reviewer reports it

### Requirement: Live video keeps playing under overlays
On Apple TV, showing the channel overlay, the zap bar, the guide or search
while a channel plays MUST keep the same picture playing without a pause or
restart.

#### Scenario: Opening the channel overlay
- **GIVEN** a channel is playing on Apple TV
- **WHEN** the viewer opens the channel overlay
- **THEN** the picture keeps playing behind the overlay without a pause, black frame or rebuffer

#### Scenario: Opening the guide from live TV
- **GIVEN** a channel is playing on Apple TV
- **WHEN** the viewer opens the guide
- **THEN** the same stream continues in the guide's picture-in-picture without restarting

### Requirement: Focus is the lifted white card
On Apple TV the focused element MUST use the focus style from the reference:
a light card with dark text and a drop shadow. Accent borders and focus shown
by scale alone are not allowed, and nothing other than the focused element
is filled white.

#### Scenario: Moving focus down a list
- **WHEN** the viewer moves focus to a row on Apple TV
- **THEN** that row becomes a light card with dark text and a shadow
- **AND** no other element on screen is filled white

#### Scenario: Focus without the card
- **WHEN** a reviewer finds a focused element shown only by a colored border or a size change
- **THEN** it fails this requirement

### Requirement: One accent color
The accent blue from the reference MUST be the only accent color. It SHALL
appear only on progress fills, the guide's now line, the NOW and UP NEXT
badges, links and the selected iPhone tab. Nothing else is tinted.

#### Scenario: A tinted icon
- **WHEN** a reviewer finds an icon or label tinted in a color other than the accent
- **THEN** it fails this requirement

#### Scenario: Accent on a decorative element
- **WHEN** the accent appears on something that is not progress, the now line, a NOW or UP NEXT badge, a link or the selected iPhone tab
- **THEN** it fails this requirement

### Requirement: Text stays above the platform caption floor
Text MUST never be smaller than the platform's caption minimum in the
reference type scale: 18 pt on Apple TV, 13 pt on iPad and Mac, 12 pt on
iPhone.

#### Scenario: Small metadata on Apple TV
- **WHEN** a screen on Apple TV shows a caption
- **THEN** it is at least 18 pt

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
- **WHEN** copy says "this Apple TV" or "Antenna on iPhone"
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
entitlement, because Antenna has no free tier.
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
