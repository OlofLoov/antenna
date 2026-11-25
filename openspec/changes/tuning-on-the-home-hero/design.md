# Design

## Context

See proposal.md for why. What exists on 2026-11-25, from
`tune-in-home-hero`:

- `TuneInWordmark.svelte` plays Hello (3.2 s) from the first paint and one
  Tuning ring per tip at 1.6 s and 1.9 s. The triangle, the mouth and the
  eye are black shapes inside an SVG `<mask>` that cuts the head, and Hello
  animates them there.
- `TuneInStage.svelte` fades static in at 0.5 s and snaps the TV's picture
  in at 1.6 s, all in CSS under a `tuning` class. Its script drops that
  class 1.8 s after it starts and zaps every 4 s from then on, only while
  the stage is on screen, the tab is visible and Pause channels is off.
  Pause, off screen and a hidden tab stop the zapping and the drift but not
  the tune-in or the wordmark.
- `src/lib/tuneIn.ts` holds the times, which the site tests compare with
  the CSS.
- The app's Tuning and Got it are `MarkMotion.tuning` and `MarkMotion.gotIt`
  in AntennaCore, ported from the owner's `motion-reference.css`. The hero
  copies their keyframes, curves and geometry: Tuning loops every 2.4 s,
  the antennae lean about their bases (656, -112) and (690, -112), left
  0, -14, 9, 0 degrees at 0, 30, 65 and 100 %, right 0, -9, 14, 0; the
  rings scale 1 to 2.6 and fade 0.7 to 0 over 1.2 s, the right 0.6 s after
  the left; the triangle slides by (-21, -21) and shrinks to nothing in
  0.35 s; the eye at (650, -80), r 10, pops in 0.25 s later, looks (-3, -1)
  at 30 % and (3, -1) at 60 %, blinks to 0.1 high at 86 %; the mouth wedge
  `M641 -60L605 -56.3L606 -68Z` stretches to 2.1 at 50 %. Got it is 1.2 s.

Budgets on main, from `npm run build`: the home page is 221,687 bytes with
its scripts, styles and first image (budget 512,000) and loads 48.5 KB of
compressed script (budget 60 KB).

Boards: `Web-Home.dc.html` and `Web-Home-Phone.dc.html` draw the hero's
still frame, which does not change. The motion is not drawn; the timeline
below is the source, as it was for `tune-in-home-hero`.

Design-system requirements that apply: "The mark moves at three moments"
(the draw-on is Hello's first part, Tuning is the TV loading, Got it is
the picture arriving, and the mark then stands still), "Reduce Motion
stills the mark" (the hero keeps its still mark with the 0.4 s fade), "The
Antuna mark" and "The mark's colors".

## Goals / Non-Goals

**Goals:**
- Tuning and Got it look as they do in the app.
- The tune-in still plays from CSS alone, with scripts off too.
- Pause channels, off screen and a hidden tab stop everything that moves in
  the hero.
- Safari moves the triangle, eye and mouth as Firefox and Chrome do.
- No new budget, no new dependency.

**Non-Goals:**
- More than one Tuning loop. The static would pass four seconds.
- Motion on zaps.

## Decisions

### 1. The timeline

All times from the first paint. Tuning runs once, from 1.6 s to 4.0 s, and
Got it from 4.0 s to 5.2 s.

| Time | Wordmark | TV |
|------|----------|----|
| 0 to 0.91 s | letters draw, 0.55 s each, 0.09 s apart | dark screen |
| 0.5 to 0.95 s | the last a lands | static fades in from 0.5 s to 0.7 s |
| 0.83 to 1.13 s | the triangle opens | static |
| 1.05 to 1.37 s | the sticks draw | |
| 1.25 to 1.67 s | the tips pop | |
| 1.6 s | Tuning starts: the triangle slides forward and shrinks, the left ring starts, the antennae start to lean | |
| 1.85 to 2.15 s | the eye pops in | |
| 2.2 s | the right ring | |
| 2.32 s | both lean left (-14 and -9 degrees), the eye looks left | |
| 2.8 s | the mouth is open widest, the left ring again | |
| 3.16 s | both lean right (9 and 14 degrees); the eye looked right at 3.04 s | |
| 3.4 s | the right ring again, its last | |
| 3.66 s | the eye blinks | |
| 4.0 s | Got it starts; the antennae are upright again | the static goes, the picture opens from a line in 0.16 s, the iPad and iPhone fade in |
| 4.0 to 4.48 s | the eye squints | |
| 4.1 s | the mouth gulps | channel number 1 |
| 4.15 to 4.85 s | the tail flicks | |
| 4.3 and 4.38 s | the tips hop | |
| 4.62 to 5.08 s | the eye shrinks and the triangle comes back, overshooting to 1.12 | |
| 5.2 s | still | |
| about 8.2 s, then every 4 s | still | zap to the next channel |

The draw-on keeps Hello's tracks from 0 to 1.67 s unchanged, except the
triangle opens with the prototype's `mk-open` (0.3 s,
`cubic-bezier(0.3, 1.4, 0.5, 1)`, from 0.83 s) and the mouth does not
speak, since the mouth breathes 0.8 s later. Hello's second half, the eye
trip and blink, goes: Tuning's eye replaces it.

The left ring plays twice from 1.6 s and the right twice from 2.2 s, so
the last ring fades out at 4.6 s, by then at 3 % opacity under the hopping
tip. Every Tuning track runs one 2.4 s loop and ends where it started, so
Got it takes over at 4.0 s with no jump.

Options considered:
- **Two Tuning loops, picture at 6.4 s.** Faithful to "loops while the wait
  lasts", but six seconds of static before the product shows is too long
  for a first visit.
- **Tuning from 1.4 s, as the sticks finish.** Saves 0.2 s; the antennae
  lean while the tips are still popping, which reads as a glitch.
- **Hello in full, then Tuning.** The picture would wait until 5.6 s.

### 2. Shapes over the head instead of a mask

The head and tail are solid. The triangle (stroked 6 with a round join),
the mouth wedge and the eye are drawn over them in `--bg`, as in the
owner's prototype. The page's ground under the hero's text column is
`--bg`: the glow reaches `--bg` at its closest sides, about 400 px from its
center behind the TV, and the wordmark sits further out than that at every
width.

The antennae turn about their bases with `transform-box: view-box` and
`transform-origin` at (656, -112) and (690, -112), as in the prototype; the
other parts scale about their own boxes. Each group nests so that one
property moves per element: the eye is a blink-and-squint group around a
look group around the circle that pops.

Options considered:
- **Keep the mask.** WebKit on macOS 27 animates it (checked with
  `WKWebView`), but Safari has a history of not repainting masked content
  when only the mask's children animate, and a mask needs a document-wide
  id.
- **A static mask for the triangle and a plug that fills it.** Cannot show
  the triangle sliding toward the eye.

### 3. Holding the hero

The page owns one `held` flag that it binds to the stage and passes to the
wordmark. The stage's script sets it when Pause channels is on, the hero is
off screen or the tab is hidden (`mayAnimate` in `tuneIn.ts`). Each
component then sets `animation-play-state: paused` on its elements, so the
static, the snap, Tuning and Got it stop on the frame they are at and go on
from it.

The stage no longer drops `tuning` on a timer. It waits for the stage's
finite animations to finish (`getAnimations` and `finished`), so a held
tune-in delays the first zap with it; with Reduce Motion there are none and
it counts as tuned at once. The script watches the whole hero section, not
the stage alone, since on a phone the TV can sit below the fold while the
wordmark is in view.

The Pause channels button shows as soon as the script runs, so it covers
the tune-in. Its name stays: the tune-in is part of the channels.

Options considered:
- **Pause only the zapping, as before.** The wordmark and static last
  5.2 s together, longer than WCAG 2.2.2's five seconds, and the owner asked
  for the button to cover them.
- **`Animation.pause()` from the script.** Same effect, but a class keeps
  the rule in the CSS next to the animations it stops.

### 4. Zaps leave the mark still

Recommended and built: the mark stands still after Got it. The
design-system rule is that the mark moves only when something opens,
loads or confirms. A zap is the page's own loop, it comes every four
seconds forever, and a lean on each would make the mark the busiest thing
on the page. A single lean of the antennae would be the least of it; it is
a one-line addition if the owner wants it later.

### 5. The first picture under a cover

The static now lasts until 4.0 s. Hiding the TV's picture until then would
push the page's largest paint to 4 s. Instead the picture is painted from
the start under a black cover in the screen, and the cover goes at 4.0 s
as the picture's snap starts. The snap animation fills forwards only, so
before 4.0 s the picture is at full size under the cover.

### 6. Timings in code

`timing` in `tuneIn.ts` becomes: `staticFrom` 500, `tuningFrom` 1600,
`tuningLoop` 2400, `picture` 4000, `snap` 160, `gotIt` 1200, `ring` 1200,
`secondRing` 600 (after the first), `zapEvery` 4000, `zap` 360. `hello` and
`tuned` go. The site tests check `picture` equals `tuningFrom` plus
`tuningLoop`, and that the CSS uses these numbers.

## Risks / Trade-offs

- [Overlay color] A future background behind the wordmark that is not
  `--bg` would show the triangle, eye and mouth as patches. The hero test
  checks the glow stays a closest-side gradient to `--bg`.
- [Longer wait for the picture] The product shows at 4.0 s instead of
  1.6 s. The headline and the App Store link are there from the first
  paint, and the largest paint does not move (decision 5).
- [Held in a background tab] The CSS starts before the script, so a tab
  opened in the background may have played a little of the tune-in before
  it holds.
