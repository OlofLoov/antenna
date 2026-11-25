## Why

The home page hero plays Hello above the headline: the wordmark writes
itself, then the triangle turns into an eye, blinks and goes back. Hello is
the app's greeting on first launch. What the hero shows is a TV finding a
signal, and the brand has a motion for exactly that wait: Tuning, which
hands over to Got it when the picture arrives. On 2026-11-25 the owner
asked for Tuning in the hero instead of Hello.

Afterwards, a visitor opening antuna.app:

- sees the wordmark draw on, short, as today;
- sees the TV search for a signal in soft static while the wordmark tunes:
  the antennae lean one way and the other, the tips send out faint rings,
  the eye looks the way they lean and blinks, the mouth breathes;
- sees the picture snap in at the moment the mark plays Got it: a flick of
  the tail, a hop of the tips, a squint and a gulp, and the eye slides back
  to be the play triangle;
- then sees the mark stand still while the TV zaps through the app;
- can stop all of it with Pause channels, and nothing moves while the hero
  is off screen or the tab is hidden;
- with Reduce Motion on, gets the still mark and Live TV, as today.

## What Changes

- The hero's wordmark plays a short draw-on, one loop of Tuning and Got it
  instead of Hello. The draw-on is Hello's first 1.6 s without the mouth.
- The TV's static lasts 3.5 s instead of 1.1 s, so it covers one Tuning
  loop, and the picture snaps in at 4.0 s instead of 1.6 s.
- The hero draws the triangle, the mouth and the eye as shapes in the page's
  ground color over the head, as the owner's motion prototype does, instead
  of animating shapes inside an SVG mask.
- Pause channels, scrolling the hero away and hiding the tab also hold the
  tune-in and the wordmark where they are.
- The mark stays still on each zap.

Out of scope:

- Motion on the header's wordmark or anywhere else on the site.
- A lean of the antennae on each zap. design.md decision 4 says why the
  mark stays still.
- Any change to the channels, the zap, the drift or the Reduce Motion form.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `antuna-website`: the home page tunes in, and the TV zaps through the
  app (the pause and the holds now cover the tune-in and the wordmark).

## Impact

- Web: `TuneInWordmark.svelte`, `TuneInStage.svelte`, `src/lib/tuneIn.ts`,
  the home page, the site tests.
- Depends on `tune-in-home-hero` (archived) for the hero and on
  `add-tuna-wordmark` (archived) for Tuning and Got it, whose app version is
  `MarkMotion` in AntennaCore. Not blocked.
- No new dependency, no budget change.
