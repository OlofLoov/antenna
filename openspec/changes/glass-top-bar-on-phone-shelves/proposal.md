# Proposal

## Why

> The owner, on the iPhone Movies and Series tabs: "the previous fix where we add a shade to the entire art kind of works but would it not be better to use a separate top menu and then have the art + info below? kind of like how Netflix and others do? also that menu should be glass transparent style (the one we got right) in that we can have the 'All movies' or the selected category showing as well."

On iPhone, and in a narrow iPad window, "Movies" or "Series", the profile button and the genre button sit on the banner art. The band added in `fix-banner-header-over-light-art` keeps them legible, but it darkens the top third of every picture, and once the banner scrolls away a second copy of the name pins on a flat bar with no genre button.

After this change the name, the genre button and the profile button stay in one bar at the top of the screen at all times. The genre button is a glass capsule like the controls over the Live picture and always reads the open list, "All movies" or the picked genre. The banner, its art and its copy, starts below the bar as one rounded card, the way Netflix shows its hero on iPhone, so the art is no longer darkened at the top.

## What Changes

- A top bar pinned over Movies and Series on iPhone and in a narrow iPad window: the section's name, the genre button as a glass capsule reading the open list and its count, and the profile button. Rows and posters scroll under it, blurred by the system's scroll edge effect.
- The banner starts below the bar, inset from the screen's edges with rounded corners. The art keeps the band under the copy at its foot and loses the band at its top.
- The bar that pinned on the ground color after 420 pt of scroll goes away; the one bar is there from the start.
- Boards `iPhone-Movies`, `iPhone-Movies-Grid`, `iPhone-Movies-Trailer`, `iPhone-Movies-Rows` and `iPhone-Movies-Discover` draw the bar and the card.

Out of scope:
- iPad and Mac in a regular window. Their name, search field and sort menu sit in a row on the ground color above the banner card, never over the art.
- Apple TV. The tab bar is the system's and the banner has no name or genre button over its art.
- The Genres sheet itself, what a poster tap does, and the order of the rows.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `movies-and-series-browsing`: a new requirement for the pinned top bar on iPhone; "Pick a genre from a list on iPhone" puts the genre button in that bar instead of over the banner.
- `design-system`: "The scrim blends into the art" drops the band behind the iPhone header; "Liquid Glass stays on the navigation layer" names the iPhone top bar.

## Impact

- Platforms: iPhone, and iPad or Mac in a narrow window, where Movies and Series use the iPhone layout.
- Code: the compact Movies and Series screen, the iPhone banner layout, a new top bar component, and the hero scrims, where the top band is removed.
- Tests: the unit tests of the top band are replaced by tests of the bar; the iPhone Movies UI tests check the bar's place and label.
- Builds on `fix-banner-header-over-light-art` (archived) and replaces its top band. Blocked on nothing.
