# Tasks

## 1. Foundations (PR 1)

- [x] 1.1 Add `Apps/Shared/Components/Metrics.swift` with the spacing scale and the four radii per platform, and `FocusCard` (light fill, dark text, focus shadow, `.hoverEffect(.highlight)` on tvOS), with previews on Apple TV and iPhone
- [x] 1.2 Set the accent as the app tint on every platform, remove `preferredColorScheme` overrides inside presentations, and verify the previews still render dark
- [x] 1.3 Add the two warning greps to `scripts/check-rules.sh` (fixed font sizes outside the allow list, `ButtonStyle` types outside the exception components) and verify they list today's files
- [x] 1.4 Add a `TVJourneys` and `AppJourneys` step for each screen in the audit table that has no step yet (Settings add source, source details, kinds, Movies focus, No channels yet), anchored on its identifier

## 2. Add a source and onboarding (PR 2)

- [ ] 2.1 Draw the not-drawn add-source states (error, connecting, iPad and Mac sheet) and rename `TV-Refresh-AddSource`, `TV-Refresh-AddSource-Kinds` and `iPhone-Refresh-AddSource` over `TV-Onboard-3`, `TV-Onboard-2` and `iPhone-Onboard-2`, redrawing their other states
- [ ] 2.2 On Apple TV present add a source from Settings as a full-screen cover with no app background, kinds then form in one `NavigationStack`, Cancel in the content and Menu going back a page (design-system/modals-are-system-presentations, design-system/pages-cover-what-is-behind-them)
- [ ] 2.3 Rebuild `OnboardingForm.Television` as the two-column page with `Form` field rows, footer, glass prominent Connect and Cancel; rebuild `OnboardingKinds.Television` as card buttons inside the safe area (design-system/forms-use-the-platform-form-style, design-system/apple-tv-content-stays-in-the-safe-area)
- [ ] 2.4 Rebuild `OnboardingForm.Phone` as a grouped `Form` with Type as a menu picker, Cancel and Connect in the toolbar, and the clipboard offer as a button row (design-system/forms-use-the-platform-form-style)
- [ ] 2.5 Move welcome, help, progress and summary to text styles and system buttons, and drop the accent eyebrow on the summary
- [ ] 2.6 Run `OnboardingTVUITests`, `OnboardingUITests`, `SetupTVUITests`, `LoginFromPhoneTVUITests` and `SourceSignInTVUITests` on simulators and cite the requirements in the tests that prove them

## 3. Sources and Settings (PR 3)

- [x] 3.1 Draw Apple TV source details and the Preferences choice list, and rename `TV-Refresh-Settings` over `TV-Settings`
- [x] 3.2 Give Settings on Apple TV an opaque page with the split view, hide the tab bar while it is open, and start content below the safe area (design-system/pages-cover-what-is-behind-them, design-system/content-clears-the-tab-bar)
- [x] 3.3 Remove fixed foreground colors from rows inside system lists so focused rows take the platter's colors (design-system/focus-is-the-lifted-white-card)
- [x] 3.4 Replace the unlabeled segmented preferences with labeled value rows on Apple TV, and source details' nested fields with field rows (design-system/forms-use-the-platform-form-style)
- [ ] 3.5 Run `ShellUITests`, `FileImportTVUITests`, `SettingsUITests`, `GuideSourcesUITests` and `ProfileUITests` on simulators

## 4. Empty and error states (PR 4)

- [ ] 4.1 Draw the iPhone Live empty state and rename `TV-Refresh-Shell-Empty` over `TV-Shell-Empty`
- [ ] 4.2 Add one `StatusView` component (symbol, title, message, up to two actions) built on `ContentUnavailableView`, and move "No channels yet", the player failure, Live's load failure and the Movies and Search empty states onto it (design-system/empty-and-error-states-share-one-layout)
- [ ] 4.3 Give "No channels yet" an Open Settings action and rename Retry to Try again everywhere
- [ ] 4.4 Run `ShellUITests`, `LiveStatesUITests`, `PlayerErrorTVUITests`, `PlayerErrorUITests` and `ShelfStatesUITests`

## 5. Movies, Series, title pages and Search (PR 5)

- [ ] 5.1 Replace `ShelfView.CardStyle`, `EpisodePicker.ChipStyle`, `ShelfGridView.ChipStyle` and the search poster style with card and borderless system styles that lift and tilt; episode rows become focus cards (design-system/controls-use-system-styles)
- [ ] 5.2 Start the hero below the tab bar, drop the accent eyebrows, and put the iPhone Movies and Series switch and genre chips on glass (design-system/content-clears-the-tab-bar, design-system/one-accent-color, design-system/liquid-glass-stays-on-the-navigation-layer)
- [ ] 5.3 Move hero, rows, title page and search to text styles and the radius scale, and update `TV-Movies`, `TV-Title`, `TV-Series`, `TV-Search`, `iPhone-Movies` and `iPhone-Title` type comments
- [ ] 5.4 Run `ShelfTVUITests`, `TitleTVUITests`, `SearchTVUITests`, `ShelfUITests`, `TitleUITests` and `SearchUITests`

## 6. Live layer, guide, paywall and profiles (PR 6)

- [ ] 6.1 Move the channel overlay, zap bar, guide grid and multi-view styles onto `FocusCard`, text styles and the overlay material, keeping their layout and identifiers (design-system/focus-is-the-lifted-white-card, design-system/type-uses-text-styles)
- [ ] 6.2 Move the overlay's group column and every other Apple TV live screen inside the safe area (design-system/apple-tv-content-stays-in-the-safe-area)
- [ ] 6.3 Put the iPhone, iPad and Mac player controls on glass (design-system/liquid-glass-stays-on-the-navigation-layer)
- [ ] 6.4 Move the paywall, profile picker, reminder banner and Top Shelf placeholders to system buttons and text styles, and raise every Apple TV caption to 23 pt (design-system/text-stays-above-the-platform-caption-floor)
- [ ] 6.5 Run `ChannelOverlayUITests`, `ZapBarUITests`, `GuideUITests`, `MultiViewTVUITests`, `PaywallTVUITests`, `ProfileUITests`, `PlayerPanelTVUITests` and their iPhone counterparts

## 7. Apple TV tab bar (PR 7, after the owner answers open question 1)

- [ ] 7.1 Put the custom tab bar on glass with the bar scrim, or move to the system `TabView` per the owner's answer, through a `tvos-shell` change if the Menu behavior changes
- [ ] 7.2 Run `ShellUITests` and `TopShelfTVUITests`

## 8. Verify

- [ ] 8.1 Turn the two `check-rules.sh` greps into failures and confirm they pass with an empty allow list beyond the named exceptions
- [ ] 8.2 Fold the text style table, spacing and radius scale, materials and exception list from design.md into the design-system reference
- [ ] 8.3 Each requirement in this change has a test citing `design-system/<requirement-slug>`: UI tests for presentations, backdrops, tab bar clearance, focus colors and empty states, and the `check-rules.sh` greps for styles, text styles and radii
- [ ] 8.4 Run the full UI suite with the `ui-tests` label and compare the `App screenshots` artifact with the boards
- [ ] 8.5 `/opsx:verify refresh-visual-design` passes
