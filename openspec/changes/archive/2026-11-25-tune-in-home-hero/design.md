# Design

## Context

See proposal.md for why. What exists on 2026-11-25:

- `Web/site/src/routes/+page.svelte` renders the hero as a text column (h1,
  lead, App Store link, platforms) next to one `Screenshot` of
  `apple-tv-live.jpg`, loaded eagerly. Every later image on a page must be
  `loading="lazy"`.
- `SiteHeader.svelte` draws the still wordmark inline, with the triangle and
  mouth cut by a mask named `wordmark-cut` and the tips in `--tip`.
- The owner's web reference for the motions (`motion-reference.css` from the
  add-tuna-wordmark artwork) and the timings in add-tuna-wordmark design.md
  decision 2: Hello is 3.2 s, Tuning's rings last 1.2 s and the right tip
  follows the left by 0.6 s.
- `scripts/check-site.js` enforces: no inline script, no `<style>` element
  and no `style=` attribute in the built HTML, no Svelte `transition:`,
  `animate:` or `style:` directive, nothing from another address, each image
  at most 250 KB, at most 60 KB of compressed script per page, and at most
  500 KB for the home page's HTML, scripts, styles and first image.
- The CSP (`Infra/modules/site/main.tf`) has `img-src 'self'`, so no `data:`
  images, and `style-src-attr` allows only the route announcer's hash.
- Site screenshots: Apple TV live, guide, Movies and add-source; iPad live;
  iPhone guide and add-source; Mac live and Movies. The store set that
  `scripts/site-screenshots.sh` reads has, for each of Apple TV, iPad and
  iPhone, live, guide, movies, player and add-source. None has Series.

Budgets on main before this change, from `npm run build`: the home page is
199,950 bytes with its scripts, styles and first image (budget 512,000), and
loads 45.3 KB of compressed script (budget 60 KB).

Boards, under `openspec/specs/design-system/boards/`:
- Updated: `Web-Home.dc.html` (the hero at 1280 wide) and
  `Web-Home-Phone.dc.html` (the hero at phone width). Both draw the
  wordmark above the headline, the TV frame with the channel number, the
  iPad and iPhone in front, the glow and the pause button.
- Not drawn: the motion itself. The timeline below is the source.

Design-system requirements that apply: "The Antuna mark" and "The mark's
colors" (the hero draws the same shapes and colors as the header), "The
mark moves at three moments" (Hello plays as the home page opens; the rings
are Tuning's, played once per tip while the TV tunes, which is the TV
loading), "Reduce Motion stills the mark" (the still mark fades in over
0.4 s), "Nothing fake and nothing bundled" (the TV, iPad and iPhone show the
app's own store screenshots).

## Goals / Non-Goals

**Goals:**
- The tune-in plays from CSS alone, so it works before the script loads and
  with scripts off.
- The first visit downloads no more than today plus the iPad and iPhone
  screenshots for Live.
- No new budget, no new dependency, nothing from another address.

**Non-Goals:**
- A Series channel (no screenshot exists).
- An animation library or canvas drawing.

## Decisions

### 1. The timeline

All times from the first paint of the page. Hello's tracks are the owner's,
unchanged.

| Time | Wordmark (Hello) | TV |
|------|------------------|----|
| 0 to 0.91 s | letters draw, 0.55 s each, 0.09 s apart | dark screen |
| 0.5 to 0.95 s | the last a lands | static fades in over 0.2 s from 0.5 s |
| 0.83 s | the play triangle opens | static, about 1 s in all |
| 1.05 to 1.37 s | the sticks draw | |
| 1.25 to 1.67 s | the tips pop | |
| 1.6 s | | the static goes, the picture opens from a line in 0.16 s, the left tip's ring starts |
| 1.9 s | | the right tip's ring starts |
| 2.1 to 3.2 s | the triangle becomes the eye, blinks, comes back | channel number 1 in the corner |
| 5.8 s or a little later, then every 4 s | | zap to the next channel |

The rings are Tuning's (`mk-ring`, 1.2 s, ease-out, scale 1 to 2.6, opacity
0.7 to 0), played once per tip instead of looping, 0.3 s apart instead of
0.6 s so both are on screen while the picture comes in.

The script counts from when it starts, which is after the first paint: it
drops the tune-in at 1.8 s and zaps 4 s after that, so the first zap comes
at 5.8 s at the earliest.

A zap lasts 0.36 s. The picture on screen is replaced at once by the next
one, which opens from a line over 0.18 s after a 0.12 s delay, while the
static rises to 0.35 opacity and falls back. The iPad and iPhone cross-fade
to the same channel over 0.2 s. The channel number pops in.

Options considered:
- **Static before the wordmark is done, then rings later.** The owner asked
  for the rings while the picture snaps in, and the tips only exist from
  1.25 s, so the picture waits until 1.6 s.
- **Tuning's leaning antennae during the static.** Hello's sticks are still
  drawing then; leaning them as they draw reads as a glitch.

### 2. CSS for the tune-in, script for the zapping

Two new components in `src/lib/components/`: `TuneInWordmark.svelte` (the
wordmark above the h1, Hello and the rings) and `TuneInStage.svelte` (the
TV, iPad, iPhone and the pause button, in the hero's second column). Hello,
the static and the snap are CSS animations in their `<style>`, keyed to classes in the prerendered markup, so
they start with the first paint and need no script. The script does what
CSS cannot: the zapping, the pointer and scroll drift, the pause button,
loading the next channel and stopping all of that off screen.

The zap is a class on the stage (`zap`) that the script adds for 0.36 s.
The tune-in animations sit under a `tuning` class that the script removes
after 1.8 s, so adding and removing `zap` later does not restart them.

The drift writes two custom properties, `--drift-x` and `--drift-y`, with
`style.setProperty`. That is CSSOM, which `style-src-attr` does not govern,
and it writes no `style=` attribute into the markup or the scripts. The
devices use them through the `translate` property with a 0.3 s transition:
TV 4 px, iPad 10 px, iPhone 16 px at the edge of the viewport, and on scroll
the iPad rises up to 24 px and the iPhone 40 px as the hero leaves the top
of the window. Pointer drift only listens on `(hover: hover) and (pointer:
fine)` devices.

Timing constants, the channel list and the rule for when the zapping may run
live in `src/lib/tuneIn.ts`, so Vitest can check them without a browser.

Options considered:
- **Everything in script.** The page would show a still frame until the
  script loads, and nothing with scripts off.
- **Everything in CSS, with a long keyframe loop for the zapping.** It
  cannot wait for an image to load, pause off screen or obey a button.
- **Svelte transitions.** `check-site.js` forbids them, since they write
  `style=` attributes the CSP blocks.

### 3. The static

An inline SVG over the screen with `feTurbulence` (fractal noise, base
frequency 0.9, two octaves) turned grey, at 0.45 opacity over the dark
screen, drifting smoothly by a few percent of its size, with scanlines as a
repeating gradient of 1 px dark lines every 3 px that roll down slowly. It
never steps or blinks, so the screen's overall brightness only changes when
the static fades in and out. WCAG 2.3.1 counts a flash as a pair of opposing
brightness changes; the tune-in has one pair and each zap one pair, at most
one every four seconds.

Options considered:
- **A canvas redrawn with random pixels.** Real static, but it blinks every
  frame, needs a script before anything shows, and fails 2.3.1 unless it is
  very dim.
- **A noise image file.** A download for one second of effect, and `data:`
  URLs are blocked by the CSP.

### 4. Loading channels one at a time

Only channel 1 (Live: `apple-tv-live.jpg`, `live-tv-ipad.jpg`,
`live-iphone.jpg`) is in the prerendered markup. The TV's picture is the
page's first image and stays eager; the iPad and iPhone pictures are lazy as
the site check requires. After the tune-in the script loads channel 2's
three pictures with `new Image()` and `decode()`, and only then adds them to
the markup. Each zap starts loading the channel after it. A channel whose
pictures are not ready is skipped until they are. With Reduce Motion or
scripts off, nothing else loads.

The budget stays as it is. The first image is the same file. Measured with
`npm run build`: the home page goes from 199,950 to 221,687 bytes with its
scripts, styles and first image (budget 512,000; the HTML grows by 4.5 KB),
and its compressed script from 45.3 KB to 48.5 KB (budget 60 KB).

### 5. Screenshots

`screenshots.txt` gains seven lines; `scripts/site-screenshots.sh` resizes
them like the others (Apple TV 1200 wide, iPad 900, iPhone 600):

| Platform | Store file | Site file |
|----------|------------|-----------|
| appleTV | `04-player.png` | `player-apple-tv.jpg` |
| iPhone | `01-iPhone-17-Pro-Max-live.png` | `live-iphone.jpg` |
| iPhone | `03-iPhone-17-Pro-Max-movies.png` | `movies-iphone.jpg` |
| iPhone | `04-iPhone-17-Pro-Max-player.png` | `player-iphone.jpg` |
| iPad | `02-iPad-Pro-13-inch-M5-guide.png` | `guide-ipad.jpg` |
| iPad | `03-iPad-Pro-13-inch-M5-movies.png` | `movies-ipad.jpg` |
| iPad | `04-iPad-Pro-13-inch-M5-player.png` | `player-ipad.jpg` |

The channels, in order: Live (`apple-tv-live`, `live-tv-ipad`,
`live-iphone`), Guide (`guide-apple-tv`, `guide-ipad`, `guide-iphone`),
Movies (`movies-apple-tv`, `movies-ipad`, `movies-iphone`), Player
(`player-apple-tv`, `player-ipad`, `player-iphone`).

### 6. Layout

Above 720 px the hero keeps its two columns: the text column with the
wordmark (at most 300 px wide) above the h1, and the stage, up to 640 px
wide, on the right. The stage is 100 by 66 and positions in percent of its
width:

- TV: 88 % wide at the top right, a 1.2 % bezel in `#05070a` around a 16:9
  screen, corner radius 14 px.
- iPad: 27 % wide at the bottom left, a 1.1 % bezel around a 3:4 screen.
- iPhone: 13 % wide at the bottom, 4 % from the right, a 0.6 % bezel around
  the 600:1303 screen.

At 720 px and below the hero stacks: text, then the stage at full width,
100 by 95, with the TV 100 % wide at the top, the iPad 38 % wide from 8 %
on the left and the iPhone 21 % wide 10 % from the right, both on the
bottom, overlapping the TV's lower edge. Everything is in percent of the
stage, so nothing overflows sideways.

The pause button sits under the stage on the right, small, in the muted
text color. It is in the markup with `hidden` and the script shows it when
the zapping can run, so a page without script has no dead button.

The glow is a `radial-gradient(closest-side ...)` on a layer behind the
hero that reaches into the page's gutters, centered behind the TV, from
`--glow` (`#1A2A44`) to `--bg`. It reaches the ground at its closest sides,
so it has no edge. In light mode `--glow` is `#E3EBF6`. The TV, iPad and iPhone frames
stay dark in both modes.

### 7. Accessibility

- The wordmark in the hero is `aria-hidden`; the header already names
  Antuna.
- Each device's current picture has alt text from the strings file; the
  other channels' pictures carry `aria-hidden="true"`. Nothing in the stage
  is a live region, so zaps are not announced.
- The channel number is `aria-hidden`.
- The pause button is a plain `<button>` with its text as its name; it
  takes focus in reading order and traps nothing. It answers WCAG 2.2.2,
  since the zapping runs longer than five seconds next to other content.
- `prefers-reduced-motion: reduce` turns off every animation in the hero in
  CSS, and the script does not start, so it shows the final frame of Hello
  on Live TV, with Hello's 0.4 s fade from design-system.

### 8. Strings

New keys under `home.tuneIn`: `pause` ("Pause channels"), `play` ("Play
channels"), and `channels`, four entries with `tv`, `ipad` and `iphone` alt
texts. `home.heroAlt` becomes `home.tuneIn.channels[0].tv`.

## Risks / Trade-offs

- [Masks with animated children] Chrome, Safari and Firefox animate
  transforms inside `<mask>`, but a browser that does not shows the triangle
  and mouth at their final size from the start. That is the still mark, so
  nothing breaks.
- [Twelve pictures over a long visit] A visitor who watches all four
  channels downloads about 900 KB of screenshots. They load one channel at a
  time, only while the hero is on screen.
- [The store set ages] The new screenshots come from the same artifact as
  the others, so they show the app as of the same night. A later run of the
  script refreshes them all together.
