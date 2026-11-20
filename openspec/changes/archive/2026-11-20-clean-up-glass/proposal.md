# Proposal

## Why

The owner, after the visual refresh landed: many elements use the glass style
but also carry a background or a line around them, and look sloppy. Someone
watching on iPhone, iPad or Mac sees round buttons over the picture drawn
three ways (glass, a dark disc, a dark disc next to a glass capsule), a Movies
and Series switch with a white pill inside glass, and a reminder card with a
fill, a hairline and a shadow. Apple's Liquid Glass guidance puts glass
alone on the control layer and content on plain surfaces.

Afterwards every control that floats over video or art is system glass with
nothing drawn around it, rows of actions share one edge, and a check fails
when someone dresses glass again.

## What Changes

- Round buttons over art and video (title back, Movies search, title player
  close) and the title player's track buttons move from dark scrim fills to
  system glass, matching Live's player controls.
- The iPhone Movies and Series switch becomes two glass chips in one glass
  container, like the genre chips under it, with no fill inside the glass.
- The reminder banner on iPhone, iPad and Mac becomes glass alone, without
  its fill, hairline and shadow, and Watch takes the bordered prominent style.
- The secondary action beside a glass prominent primary is glass on iPhone,
  iPad and Mac (it was bordered), so Play and More info share one family.
  Onboarding's Cancel and Add another source use the same style, which is
  bordered on Apple TV beside the bordered primary.
- Live's rewind strip floats on glass like the live strip.
- The guide details' Watch and Remind me take the primary and secondary
  system styles instead of a white rectangle and a surface rectangle drawn by
  the app.
- The Apple TV onboarding cards (QR, keyboard tip, sign-in QR) drop the
  regular material for a plain surface, since they sit on the cover's own
  material.
- The highlighted multi-view tile shows only the white focus ring, with
  corners that meet the tile, and the iPad and Mac remove button is glass.
- `scripts/check-rules.sh` fails when a view applies glass together with a
  background, border, shadow or a stroked overlay.

## Capabilities

### Modified Capabilities
- `design-system`: "Liquid Glass stays on the navigation layer" gains the
  rule that glass is never combined with a fill, stroke or shadow.

## Out of scope

Other changes own these right now, and findings for them are in the PR:
the Apple TV channel overlay, group column and remote-hints card; the profile picker circle; the season row; the hero and
backdrop scrim; the channel group picker on iPhone, iPad and Mac; the store
screenshot walk.

## Impact

- Platforms: iPhone, iPad and Mac for the glass controls and the banner;
  Apple TV for the onboarding cards and button styles.
- Code: `Apps/Shared/Components` (system button styles, shelf controls,
  search parts, title page, transport, reminder banner, timeshift strip,
  onboarding), `Apps/Shared/Views/Shelf` (title player close and tracks).
- Boards: `iPhone-Movies`, `iPhone-Title`, `iPhone-Title-Player-Transport`,
  `iPad-Title-Player-Transport`, `iPhone-Reminder-Banner`, `iPhone-Guide-Detail`, `iPad-Guide`, plus the scrim controls on `iPhone-Movies-Grid`, `iPhone-Movies-Trailer`, `iPhone-Series`, `iPhone-Title-Cast`, `iPhone-Title-Scores`, `iPhone-Title-Player-Tracks`, `iPad-Title-Player-Tracks`, `iPad-MultiView` and `iPad-MultiView-Failed`.
- Depends on: `refresh-visual-design` archived.
