# Design

## Context

An audit of every `.glassEffect`, `.glass` button style, material, stroke,
border and shadow in `Apps/`, and screenshots of the main screens on iPhone,
iPad and Apple TV. The code had no glass view with a fill or stroke in the
same modifier chain. The sloppy look came from three other places:

- Fake glass. Controls over art and video drawn as a dark disc or capsule
  at 0.55 to 0.6 of the scrim tint (title back, Movies search, title player
  close and track buttons), next to real glass (the transport circles, Live's
  strip and its Picture in Picture and AirPlay capsule). Two edges and two
  levels of translucency on one screen.
- Fill inside glass. The iPhone Movies and Series switch drew a white pill
  inside a glass capsule.
- Mixed families. Play is glass prominent and More info, the trailer and My
  list were bordered, so one row of buttons had two edges. Onboarding used
  `.glass` directly beside a bordered primary on Apple TV. The reminder
  banner had a fill, a hairline and a shadow, and its Watch was a white
  capsule the app drew.

Boards: `iPhone-Movies`, `iPhone-Title`, `iPhone-Title-Player-Transport`,
`iPad-Title-Player-Transport`, `iPhone-Reminder-Banner`, `iPhone-Guide-Detail`, `iPad-Guide`, plus the scrim controls on `iPhone-Movies-Grid`, `iPhone-Movies-Trailer`, `iPhone-Series`, `iPhone-Title-Cast`, `iPhone-Title-Scores`, `iPhone-Title-Player-Tracks`, `iPad-Title-Player-Tracks`, `iPad-MultiView` and `iPad-MultiView-Failed`.

Design-system requirements it follows: "Liquid Glass stays on the
navigation layer", "Controls use system styles", "One spacing and radius
scale".

## Goals / Non-Goals

**Goals:**
- Every control over video or art is system glass and nothing else.
- A row of actions shares one style family per platform.
- A check that fails when a view combines glass with a fill, stroke or shadow.

**Non-Goals:**
- The areas other changes own now (see the proposal).
- Notices over the picture (`Transport.Notice`, `Timeshift.Notice`) and the
  full-screen channel line. They are text, not controls, and stay on the
  scrim.

## Decisions

### 1. One rule: glass alone or a plain surface alone

Options considered:
- **Glass alone or a plain surface alone.** Glass takes no background,
  stroke or shadow; a surface takes no glass. Matches Apple's guidance and
  is checkable in code.
- **Allow a tint fill under glass for contrast.** Covers bright art, but the
  system's glass already adapts to what is behind it, and the tint is the
  doubled edge the owner saw.

Decision: glass alone or a plain surface alone.

### 2. Controls over art and video use system glass

The title back button, the Movies search button and the title player's
close button take `.buttonStyle(.glass)` with the circle border shape. The
track buttons take `.glassEffect(.regular, in: Capsule())`, as Live's
Picture in Picture and AirPlay pair does. The three transport circles sit in
one `GlassEffectContainer` and draw their glyphs in the Text color, as the
close and track buttons do.

### 3. The Movies and Series switch is two chips

The switch becomes two buttons with `chipStyle(isPicked:on: .art)` in a
`GlassEffectContainer`: the open kind is glass prominent in the accent, the
other is glass. It matches the genre chips under it. A system segmented
picker was considered; it draws its own opaque track over the art and does
not take glass.

### 4. Secondary actions are glass on iPhone, iPad and Mac

`secondaryActionStyle()` is `.glass` with the capsule shape on iPhone, iPad
and Mac, and stays bordered on Apple TV, where the primary is bordered.
Onboarding's direct `.buttonStyle(.glass)` calls move to it, so Apple TV
onboarding no longer mixes glass and bordered.

### 5. The reminder banner is glass

The banner floats over every screen, so it is control layer. It takes
`.glassEffect(.regular, in: cornerShape(.medium))` with no fill, hairline or
shadow. Watch takes the bordered prominent capsule; a glass prominent Watch
would put glass on glass.

### 6. The rewind strip is glass

Live's two-row strip while it can rewind was a full-width scrim band under
the glass live strip. It now floats on glass in the large corner, 4 pt from the sides and 8 pt from the top and bottom of
the picture, like the live strip; 4 pt keeps the programme bar its width.

### 7. Apple TV onboarding cards are plain surfaces

The QR card, the keyboard tip and the sign-in QR card used the regular
material on top of `CoverBackdrop`, which is itself material. They take the
0.06 surface the other onboarding cards use.

### 8. The guide details use system buttons

The guide's details popover on iPad and Mac and sheet on iPhone drew Watch
as a white rounded rectangle (radius 10 or 12, off the scale) and Remind me
on the 0.12 surface. Watch takes `primaryActionStyle()` and Remind me
`secondaryActionStyle()`, both large and full width.

### 9. The multi-view ring is the focus ring and nothing else

The owner reported a magenta ring on the highlighted multi-view tile. The
code draws the ring in the Text color, and the tvOS simulator shows it white,
so the extra color comes from a focus look the app does not draw. The Apple
TV tile now opts out of the system focus effect (`.focusEffectDisabled()`),
so the 5 pt white ring and its shadow are the only focus look. On every
platform the tile clips to the medium corner and the ring is a stroke border
on the same shape; before, the tile clipped at 14 (Apple TV) or 12 while the
ring was drawn centered on a 16 or 12 corner, so the corners did not meet.
The remove button on iPad and Mac tiles is a glass circle instead of a disc
on the scrim tint.

### 10. The check

`scripts/check-rules.sh` reads each Swift file under `Apps/`, finds every
line that applies glass, and walks that view's modifier chain: the run of
lines at the same indent that start with a dot, skipping the closures in
between. A `.background`, `.border` or `.shadow` in the chain, or an
`.overlay` whose closure strokes, fails. Fills inside the view's label or
children are a different view and pass. The named exceptions are a regex
of files; today only `Apps/Shared/Debug/`. The glass effect allow list
gains the rewind strip, the title player's track buttons and the reminder
banner, and loses the shelf switch.

## Risks / Trade-offs

- [The check reads indentation] → `swift format` fixes indentation before
  commit, so the chain is reliable. A modifier split over lines at a deeper
  indent is read as a closure and passes.
- [A glass container takes all the room it is offered] → between two
  spacers the transport's container grew to most of the screen and took the
  tap that hides the controls. Each container here is `.fixedSize()`.
- [Glass over bright art] → the system adapts glass to what is behind it;
  the screenshots on iPhone and iPad show the glyphs readable on the sample
  art.

## Migration Plan

None.

## Open Questions

None.

## Not drawn

None; the boards above are redrawn in this change.
