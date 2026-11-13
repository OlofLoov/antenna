# Proposal

## Why

> The owner, after testing on a real Apple TV: the UI "looks iffy" and must have the style one expects from a state-of-the-art app. The add-source modal on Apple TV "is not styled as one would expect".

The audit on 2026-11-13 (Apple TV 4K and iPhone 17 simulators, main at `6a33ee8b`) found why. On Apple TV, Add a source opens as a system sheet but fills it with the 1,700-point onboarding layout, so the sheet crops its own fields and the QR card, and Settings itself draws over the Guide with no backdrop, so two screens of text sit on top of each other. Underneath that, the app hand-draws almost everything the system would draw: 464 fixed font sizes against 67 text styles, 30 custom button styles, 78 plain buttons, no Liquid Glass, no materials, no card buttons and 14 different corner radii. The design-system capability tells implementers to copy point sizes from the boards, which is how this happened.

After this change the living-room viewer and the household setter-upper get an Apple TV app that moves and reads like Apple's own: system focus with lift and motion, Liquid Glass on the navigation layer, system sheets and forms for setup, text sizes from the tvOS type scale, and every screen inside the TV safe area. The on-the-go viewer gets the same rules on iPhone, iPad and Mac, where the add-source sheet becomes the same grouped form as source details. The TiviMate-style live layer (channel overlay, zap bar, guide grid) keeps its layout.

## What Changes

- New design-system rules: controls use system styles, type uses text styles, modals are system presentations with the system backdrop, forms use the platform form style, Liquid Glass only on the navigation layer, one spacing and radius scale, the tvOS safe area, pages that cover what is behind them, content that clears the tab bar, and one layout for empty and error states.
- Modified rules: focus comes from the system focus effect (the lifted light platter with motion), the Apple TV caption floor rises from 18 to 23 pt (Apple's minimum), and the one accent color becomes the app tint that system controls pick up for their primary action.
- Boards for the worst screens: the Apple TV add-source sheet and its kind picker, Apple TV Sources and Settings, Apple TV "No channels yet", and the iPhone add-source sheet. Each is a new `*-Refresh-*` board that replaces the old board when its screen ships.
- The text style table per platform, the spacing and radius scale, and the materials table, in design.md, folded into the design-system reference when the change is archived.
- Implementation in seven small PRs, one per screen family, listed in tasks.md.

Out of scope:
- New features or new screens. Copy changes beyond button labels named on the new boards.
- The layout of the channel overlay, zap bar, guide grid, multi-view and player controls. They get text styles, materials and system focus motion only.
- Moving the Apple TV shell to the system `TabView` tab bar. Recorded as an open question in design.md; the custom bar keeps its layout here and only gains glass and a backdrop rule.
- Light mode. The app stays dark on every platform.
- App icon and Top Shelf artwork.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `design-system`: adds ten rules on system styles, text styles, presentations, forms, materials, spacing and radii, safe area, backdrops, tab bar clearance and empty states; changes the focus, caption floor and accent rules.

## Impact

- Platforms: Apple TV, iPhone, iPad and Mac, with the same rules on each.
- Code (later PRs): `Apps/Shared/Components/` (every custom `ButtonStyle`, `OnboardingForm`, `OnboardingKinds`, `ShellLiveScreens`, `ShelfView`, `EpisodePicker`, `Palette`), `Apps/Shared/Views/SettingsView.swift`, `SettingsAddSource.swift`, `SourceDetailsScreen.swift`, the shell layers, and a new `Type` and `Metrics` file next to `Palette`.
- `scripts/check-rules.sh` gains greps for `.system(size:` outside the allow list and for new `ButtonStyle` types.
- Tests: XCUITests keep their identifiers. Preview PNGs change on almost every screen.
- Boards: five new, listed in design.md. The old boards they replace stay until the screen ships.
- Depends on: main as of 2026-11-13. `add-localization` adds right-to-left rules to the same capability without touching these requirements. `add-title-metadata`, `add-discover-rows` and `add-browse-by-person` draw new screens; once this change is archived their boards follow these rules, and screens that ship before then get restyled in the PR for their family.
- Blocked on: the owner's answers to the open questions in design.md for PR 7 (the Apple TV tab bar). PRs 1 to 6 can start now.
