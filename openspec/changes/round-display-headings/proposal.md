## Why

The new wordmark is drawn in round monoline strokes, but every heading next
to it is plain SF Pro. On the paywall, the welcome screen and the Movies and
Series heroes, "Unlock Antuna" or "The Long Harbor" sits under the mark in a
different voice. On 2026-11-25 the owner decided how the type follows the
mark: large display headings switch to SF Pro Rounded, everything else stays
SF Pro. Rounded body text would push the app toward cute, so it stops at the
headings.

Afterwards:

- Someone opening Antuna sees the paywall, welcome and "You're set"
  headlines, the screen titles the app draws (Movies, Series, the Live TV
  group on iPad and Mac) and the title of a movie, series or person in
  rounded letters that match the wordmark, on iPhone, iPad, Mac and Apple TV.
- Rows, lists, buttons, captions, descriptions and form labels read exactly
  as before.
- Larger Text, right-to-left layouts and Arabic keep working. Arabic
  headings use the system Arabic font, as they do today.
- A visitor to antuna.app sees the page headings in the same rounded letters
  on Apple devices, and the system font elsewhere.

## What Changes

- A design-system rule: the top two steps of each platform's type scale are
  rounded, every other step is plain SF Pro, and the app and site bundle or
  download no fonts.
- The type scale decides the design. A screen asks for a size and gets the
  rounded or plain face with it; no screen picks the design itself.
- The headings that use a text style directly (the welcome, onboarding and
  passcode headlines, the iPad and Mac Live TV title) go through the scale,
  so they pick up the rule.
- The website's h1 and h2 headings use the rounded system face where the
  browser has one.
- The boards draw the display headings in the rounded face.

Out of scope:

- System navigation bar titles (Settings, Groups, the add-source sheets).
  SwiftUI has no setting for their font, and changing it means UIKit
  appearance overrides on iOS and tvOS. They stay as the system draws them.
- Any bundled or downloaded font, including a rounded font on the site for
  browsers that have none.
- Weights, sizes and spacing. Only the face changes.
- New store screenshots. The nightly run picks up the headings by itself.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `design-system`: adds the rule for display headings and states that text
  styles come with the design the scale gives them.
- `antuna-website`: page headings use the rounded system face.

## Impact

- Apps: `TypeScale` and the call sites that use a large text style
  directly; previews and the type scale tests.
- `scripts/check-rules.sh`: a check that only the type scale picks a font
  design and that no custom font is loaded.
- Web: `site.css` and a site test.
- Boards: 78 boards get the rounded face on their display headings.
- Depends on `add-tuna-wordmark` (archived). Not blocked.
