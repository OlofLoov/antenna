# Design

## Context

Two owner reports from a device on 2026-11-20. My list on the banner and the title page was a plus or a check in a square (`ShelfBanner.MyListButton`, `TitlePage.MyListButton`), and on iPhone the banner's Trailer was a glyph in a square too (`ShelfBanner.TrailerGlyphButton`). On Apple TV the channel overlay's rows and buttons showed a thin light rim at rest. A screenshot of the overlay on the tvOS 27.2 simulator showed the rim on every element that carries `FocusCard`, which applies `hoverEffect(.highlight)`; the Guide, whose Watch is a system bordered button and whose blocks hold focus without the effect, had none.

Boards: `iPhone-Movies`, `iPhone-Movies-Grid`, `iPhone-Movies-Trailer`, `iPhone-Series`, `iPhone-Title`, `iPhone-Title-Cast`, `iPhone-Title-Scores`, `iPad-Movies`, `iPad-Movies-Trailer`, `iPad-Movies-Poster-Only`, `iPad-Series`, `iPad-Title`, `iPad-Title-Scores`, `TV-Movies`, `TV-Movies-Trailer`, `TV-Movies-Poster-Only`, `TV-Hints-Movies`, `TV-Series`, `TV-Title`, `TV-Title-Cast`, `TV-Title-Scores`, `iPhone-Player-Timeshift` and `iPhone-Player-Timeshift-RTL`. Every one of them is updated in this change. The overlay boards (`TV-Overlay*`) already draw no rim.

Design-system requirements followed: `design-system/controls-use-system-styles`, `design-system/focus-is-the-lifted-white-card`, `design-system/copy-fits-in-every-language`, `design-system/targets-are-large-enough-to-hit`.

## Decisions

### My list in words

The button reads "Add to My list", and "Remove from My list" once the title is on the list, in the secondary action style at the size of the buttons beside it. VoiceOver reads the same words, with the value "On My list" or "Not on My list". Identifiers stay `title.myList` and `<prefix>.hero.myList`.

Options considered:
- "My list" with a check once added (rejected): the owner asked for no glyph, and "My list" alone reads as a link to the list, not an action.
- "Add to My list" and "On My list" (rejected): "On My list" names a state, so a viewer can't tell a press removes the title.
- "Add to My list" and "Remove from My list" (chosen): the pair the poster's menu already uses, translated in all six catalog languages. The title page's lowercase "my list" strings go, so both places use one pair.

### Room for the words

The longest label is German, "Aus „Meine Liste“ entfernen", about 200 points at 15 points semibold. The layouts that had a square for My list make room:
- iPhone banner: two rows, Play and Info, then Trailer and My list. Trailer uses the same Label with glyph and word as on iPad, so `TrailerGlyphButton` goes. The copy rises by one row over the 520-point art; the top controls keep their place.
- iPhone title page: Play alone across the width, then My list and Trailer at their own widths.
- iPad and Mac banner: the button row is no longer held to the copy's 480 points. It runs up to about 640 points in German, inside the 330-point card on every iPad and the Mac window's minimum width.
- iPad title page and Apple TV: room as it is; each label is fixed to its ideal width so it never truncates.

Options considered:
- `ViewThatFits` between one row and two (rejected): the row would jump when the label changes length on a press.
- Shorter words (rejected): every shorter pair drops the verb.

### The rim on Apple TV

`FocusCard` gives the hover effect the card's shape with `contentShape([.hoverEffect, .accessibility], _:)` and turns the effect on only while focused, `hoverEffect(.highlight, isEnabled: isFocused)`. The focused card still lifts, casts its shadow and tilts with the remote. At rest nothing is drawn but the card's resting fill. With the effect off, a row's accessibility frame shrank to its text, 16 points in from the card, which `testTheColumnsKeepTheSafeEdgeWhileSwitchingGroups` caught; the accessibility shape keeps it on the card.

Options considered (each tried on the simulator):
- The shaped content shape alone (rejected): the rim stayed at rest.
- `hoverEffect(.lift)` (rejected): it drew a gray platter behind every resting row.
- No hover effect and a scale on focus (rejected): `design-system/focus-is-the-lifted-white-card` asks for the tilt that follows the remote.
- The effect on the focused element only (chosen).

### The overlay's buttons

Watch takes `primaryActionStyle()` and the favorite star and Add to multi-view take `secondaryActionStyle()`, the system bordered style on Apple TV, as Watch and Remind me in the Guide. The star keeps a circle shape. `PanelButtonStyle` goes.

### LIVE behind live

The button that goes back to live on iPhone, iPad and Mac keeps its muted dot and drops the outline for the badge's 0.14 surface fill, the same as the LIVE badge at live. The red dot still tells the two apart.

### A check for outlined buttons

`scripts/check-rules.sh` reads the label closure of every `Button` in `Apps` for `.stroke(`, `.strokeBorder(` or `.border(`, and fails on a hit. The profile color swatches (`ProfileBadge.swift`, `ProfileFlow.swift`) are named exceptions: their ring marks the picked color. App-drawn button styles are already limited to the parts listed in `controls-use-system-styles` by the ButtonStyle check.

## Not drawn

Nothing new. The Groups sheet on iPhone (`iPhone-Live-Groups`) was checked against the report and already uses plain rows and the system close button, so it is unchanged.
