## Why

The top of antuna.app is a headline, a lead, the App Store link and one
still screenshot of Apple TV. It says what Antuna is, but nothing on it
feels like turning on a TV, and the new wordmark sits small in the header.
On 2026-11-25 the owner asked for a hero that tunes in.

Afterwards, a visitor on a laptop or a phone:

- sees the wordmark write itself above the headline, the way the welcome
  screen greets a new user in the app;
- sees an Apple TV tune in: a second of soft static, then the picture snaps
  in while the wordmark's antenna tips send out teal rings;
- watches the TV flip through Live, the guide, Movies and a movie playing,
  one channel every four seconds, with an iPad and an iPhone in front of it
  showing the same screen, so it is clear the app looks alike everywhere;
- can pause the channels with a button under the TV;
- with Reduce Motion on, gets the same picture standing still.

The headline, the lead, the platforms and the App Store link stay as they
are and still come first.

## What Changes

- The hero shows the wordmark large above the headline, playing Hello once.
- The hero's screenshot moves into a drawn TV frame that tunes in on load.
- The TV, an iPad and an iPhone switch together through four channels every
  four seconds, with a short zap, a channel number in the TV's corner and a
  pause button.
- The iPad and iPhone stand in front of the TV and drift a few pixels with
  the pointer and with scrolling.
- The hero sits on the app icon's radial glow.
- Seven new screenshots from the store set, picked by the existing
  screenshot script: the player on Apple TV, Live, Movies and the player on
  iPhone, and the guide, Movies and the player on iPad.
- The Web-Home and Web-Home-Phone boards draw the new hero.

Out of scope:

- A Series channel. The store set has no Series screenshot on any device,
  so the TV shows Live, the guide, Movies and the player. A Series picture
  needs a new step in the App screenshots workflow first.
- Sound, video files and any picture that is not one of the app's own
  store screenshots.
- Motion anywhere else on the site. The feature pages and the sections
  below the hero stay still.
- Any change to the headline, the lead or the App Store link.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `antuna-website`: the home page tunes in, the TV zaps through the app,
  and the hero holds still with Reduce Motion.

## Impact

- Web: the home page hero, a new hero component and its timing module,
  strings for the pause button and the new alt texts, the site tests.
- Screenshots: `Web/site/static/images/screenshots.txt` gains seven lines,
  and `scripts/site-screenshots.sh` writes the JPEGs and their sizes.
- Boards: `Web-Home.dc.html` and `Web-Home-Phone.dc.html`.
- Depends on `add-tuna-wordmark` (archived) for the wordmark's shapes and
  motions, and on `add-feature-website` for the home page. Not blocked.
  `round-display-headings` changes the heading font on the same page; the
  two do not touch the same lines.
