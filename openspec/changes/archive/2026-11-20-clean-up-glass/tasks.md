# Tasks

## 1. Glass alone (PR 1)

- [x] 1.1 Title back, Movies search and title player close take the glass button style; the track buttons take the glass effect; the transport circles share a glass container (design-system/liquid-glass-stays-on-the-navigation-layer)
- [x] 1.2 The Movies and Series switch becomes two glass chips in one container
- [x] 1.3 `secondaryActionStyle()` is glass on iPhone, iPad and Mac; onboarding uses it
- [x] 1.4 The reminder banner is glass alone, with a bordered prominent Watch
- [x] 1.5 The rewind strip floats on glass
- [x] 1.6 The Apple TV onboarding cards take the plain surface
- [x] 1.7 The guide details' Watch and Remind me take the primary and secondary system styles (design-system/controls-use-system-styles)
- [x] 1.8 The multi-view tile shows only the white focus ring, clipped and stroked on one shape; the iPad and Mac remove button is glass (design-system/focus-is-the-lifted-white-card)
- [x] 1.9 `scripts/check-rules.sh` fails on glass with a background, border, shadow or stroked overlay; the reference states the rule
- [x] 1.10 Redraw the boards named in the design

## 2. Verify

- [x] 2.1 The check-rules glass rule cites design-system/liquid-glass-stays-on-the-navigation-layer and fails on a planted violation
- [x] 2.2 The UI test classes for the touched screens pass on an iPhone simulator, and `OnboardingTVUITests` and `MultiViewTVUITests` on Apple TV
- [x] 2.3 `/opsx:verify clean-up-glass` passes
