## Why

Antuna still wears the mark it had as Antenna: a mast with two waves on each
side, which says "radio" and could belong to any streaming app. On
2026-11-24 the owner picked a new mark. The word "antuna" is set in round
monoline letters, and the last "a" is a tuna with two TV antennae on its
head and a play triangle in its middle.

The owner settled the artwork, the colors and three short motions. This
change brings them into the apps, the icons and the site. Afterwards:

- A new user meets the mark on the welcome screen, where it writes itself
  and says hello, on iPhone, iPad, Mac and Apple TV.
- Someone waiting for the App Store's first answer or for their sources to
  load sees the mark tuning in, instead of a plain spinner tile or nothing
  at all.
- Someone who restores a purchase gets a short "got it" from the mark
  before Continue.
- The Home Screen, the Dock and the Apple TV home screen show the new a, in
  teal by default and in each accent as an alternate. On Apple TV its
  antennae float above the head when the icon has focus.
- antuna.app shows the wordmark in its header.
- With Reduce Motion on, the mark fades and pulses instead of moving.

## What Changes

- A brand mark in the design system: the wordmark, the a on its own, its
  colors on dark and light grounds, and the rule that it only moves at
  three moments (Hello, Tuning, Got it), each with a Reduce Motion form.
- The geometry and the timing of every motion live in AntennaCore as data,
  so tests can check them and previews can show any frame without a clock.
- One SwiftUI component draws the mark, with the play triangle and the
  mouth cut out for real, so it works on any background.
- Placements: Hello on the welcome screen; Tuning on the launch splash, on
  the Apple TV loading screen and on the iPhone, iPad and Mac loading list;
  Got it on the paywall after a restore. The paywall's antenna symbol and
  the welcome screen's icon tile give way to the mark.
- The app icon, its six alternates, the Apple TV layered icons and Top Shelf
  are drawn from the new a. Teal becomes the standard icon's color, so the
  Teal alternate becomes Blue.
- The website's header shows the wordmark, light or dark to match the page,
  and the favicon is the new icon.

Out of scope:
- Motion over a playing stream or the guide's own loading. The player's
  buffering ring and the guide's placeholders stay as they are, since
  nothing may cover live video beyond what the player needs.
- Got it when the channels finish loading. The channel list replaces the
  loading screen the moment it is ready, and holding it back 1.2 s for a
  flourish would slow every launch.
- Got it after a purchase. A buyer goes straight into the app with no
  screen to play it on (`paywall-and-entitlement/a-buyer-goes-straight-in`).
- Sound, haptics, and a mascot anywhere outside the mark.
- New store screenshots. The nightly run picks up the new icon by itself.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `design-system`: adds the mark, its three motions and their Reduce Motion
  form; lets the mark's tips keep the brand teal on every profile.
- `first-run-onboarding`: the welcome screen says hello.
- `paywall-and-entitlement`: the launch splash tunes in; a restored purchase
  ends with Got it.
- `tvos-shell`: the loading screen at launch shows the mark tuning.
- `live-tv-on-iphone-ipad-mac`: the loading list shows the mark tuning.
- `app-release`: the icon, its Home Screen appearances and the alternates
  draw the new a; the Teal alternate becomes Blue.
- `sources-and-settings`: the App icon row lists Blue in place of Teal.
- `antuna-website`: the header shows the wordmark.

## Impact

- AntennaCore: new `Brand/` sources (geometry, path data, motion tables),
  `AppIconChoice` colors and cases, tests.
- Apps: new `Components/Brand/`, `AntennaMark.swift` removed, and the
  welcome, splash, paywall and both loading screens updated with previews.
- Icons: `design/icon/*.svg`, `scripts/render-icons.sh`, the Icon Composer
  files, the Apple TV asset catalog and `project.yml`'s alternate names.
- Web: the header, the favicon and the site check.
- Boards: a new `Brand-Mark` board, and the boards of every screen above.
- Depends on nothing. Not blocked.
