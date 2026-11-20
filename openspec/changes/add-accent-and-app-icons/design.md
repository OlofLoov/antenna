# Design

## Context

The accent is one constant today, `Palette.accent` (#5BB8FF), read directly by about forty components: progress bars, the guide's now line and its time tag, the NOW and UP NEXT badges, links such as "See all" and "Forgot passcode?", the favorite star, search highlights, the onboarding checklist, the timeshift scrubber, the AirPlay button's active color and `AntennaMark`. `AppRootView` sets it as the SwiftUI tint on iPhone, iPad and Mac, so system controls and the selected iPhone tab draw with it; Apple TV keeps the system tint.

Profiles have a circle color, one of eight (`Profile.colors`), stored as `ProfileRecord.colorIndex` and synced. `ProfileGate` puts the chosen profile's id in the environment as `currentProfile` and rebuilds the app under it with `.id(chosen)`.

The app icon is one Icon Composer file, `Apps/Mobile/AppIcon.icon`, for iPhone, iPad and Mac, and one brand asset with layered image stacks for Apple TV. Both are made from `design/icon/*.svg` by `scripts/render-icons.sh`. The mark's color is the SVG's `color` attribute.

## Boards

- `iPhone-Settings-Appearance` (new): the Appearance section in Sources & Settings, with Accent (swatch and name) and App icon (the icon's thumbnail and name), and the footer.
- `iPhone-Settings-AppIcon` (new): the pushed App icon page, a list of the seven icons with thumbnails and the current one ticked. The pushed Accent page is the same list with swatches.
- `iPad-Settings-Appearance` (new): the same section in the iPad split.
- `Mac-Settings-Appearance` (new): the Mac form with Accent only.
- `TV-Settings-Appearance` (new): the Apple TV split page with the Appearance rows, App icon focused.
- `TV-Settings-Accent` (new): the pushed Accent choices on Apple TV, a swatch before each name and a checkmark on the current one.
- `iPhone-Profiles-Edit-Accent` (new): the edit sheet with an Accent row of five swatches under the circle colors. iPad and Mac show the same sheet.
- `TV-Profiles-Edit-Accent` (new): the Apple TV edit screen with the Accent swatches under the colors.

Each board takes the accent as its `accent` prop, so a reviewer can switch it between the five values and see what moves.

Design-system requirements followed: `design-system/one-accent-color-per-profile` (renamed here), `design-system/text-meets-contrast-minimums`, `design-system/controls-use-system-styles` (system lists, `NavigationLink` rows, the system picker sheet), `design-system/forms-use-the-platform-form-style` (on Apple TV each choice is a row that pushes its choices), `design-system/focus-is-the-lifted-white-card` (swatches and rows lift on Apple TV, no accent ring), `design-system/targets-are-large-enough-to-hit` (44 pt swatch targets), `design-system/accessibility-identifiers-follow-the-board`, `design-system/layouts-mirror-in-right-to-left-languages`.

Not drawn: the pushed Accent page on iPhone, iPad and Mac, which is `iPhone-Settings-AppIcon` with swatches for thumbnails; the add-profile sheet, which is the edit sheet without Delete profile; the App icon choices on Apple TV, which are `TV-Settings-Accent` with icon thumbnails.

## Decisions

### Five accents, each above 4.5:1 on every dark surface

| Accent | Hex | Ground #0B0E13 | Row, 6% white #1A1C21 | Tab bar #11151C | Glass stand-in #2C2C2E |
|---|---|---|---|---|---|
| Blue (default) | #5BB8FF | 8.97 | 7.91 | 8.49 | 6.47 |
| Teal | #4FD1C5 | 10.36 | 9.14 | 9.81 | 7.47 |
| Amber | #FFB454 | 10.96 | 9.67 | 10.37 | 7.90 |
| Pink | #F472B6 | 7.30 | 6.44 | 6.91 | 5.26 |
| Violet | #C084FC | 7.32 | 6.45 | 6.92 | 5.27 |

Ratios are WCAG 2.x relative luminance. Glass has no fixed color; #2C2C2E is the lightest dark system material and stands in for glass over the dark ground. A NOW or UP NEXT badge draws ground text on an accent fill, which is the Ground column. Text links need 4.5:1, progress and badges need 3:1, and every accent clears 4.5:1 everywhere, so a link may sit on any of these surfaces. `ProfileAccentTests` computes the table and fails when an accent drops below 4.5:1 on any of them.

The five hex values are five of the eight profile circle colors, so an accent never looks foreign next to the circles.

Options considered:
- Six accents with Green #A3E635 (rejected): it passes (12.82 on the ground) but reads as "online" and "OK", and the sixth alternate icon slot went to Light instead.
- Red #F87171 (rejected): it passes (6.99) but red is for Delete and errors.
- Grey #94A3B8 (rejected): it looks disabled.

A known gap, not changed here: a prominent system button (Connect, Start watching, a picked chip) draws a white label on its accent fill. White on Blue is 2.15:1 today; Teal 1.87, Amber 1.76, Pink 2.65, Violet 2.64. No color passes 4.5:1 both on the dark ground and under a white label: the first needs a relative luminance above 0.195, the second one below 0.183. The fix is a dark label on prominent buttons, which belongs to the button pass running alongside this change.

### The accent is its own field, separate from the circle color

`ProfileRecord.accent: String?` holds `ProfileAccent.rawValue` ("blue", "teal", "amber", "pink", "violet"). Nil or a value this build does not know reads as Blue, so existing profiles stay blue and a newer build's accent never breaks an older one. `Profile.accent: ProfileAccent` carries it. With one profile there may be no stored record; picking an accent stores Main's record, as renaming Main does.

Options considered:
- The circle color is the accent (rejected): three of the eight circle colors make poor accents (Red, Lime, Grey, above), and every existing profile with a non-blue circle would change color on update without anyone asking.
- The circle color picks a default accent the user can override (rejected): two fields that move together surprise the user the first time they come apart.
- Per device in `UserDefaults` (rejected): the owner asked for it with the profile, and Dad's teal should follow Dad to the Apple TV.

### One token: the `accent` environment value

`EnvironmentValues.accent: ProfileAccent`, default `.blue`. `ProfileGate` sets it from the chosen profile next to `currentProfile`, and sets `.tint` from it on iPhone, iPad and Mac, replacing the fixed tint `AppRootView` set. Splash, paywall, onboarding and "Who's watching?" sit outside the gate and show Blue.

Every component that drew `Palette.accent` reads `@Environment(\.accent)` and draws `accent.color`. `Palette.accent` is removed, so the compiler finds any use that is left, and `scripts/check-rules.sh` fails on a hard-coded system color used as a tint (`.tint(.blue)` and the like) and on `Palette.accent` coming back. Code that is not a view takes the accent as a value: `AirPlayPicker` gets it from the view that makes it, and the paywall's attributed links get it from the screen.

Apple TV keeps the system tint and its focus look (`design-system/focus-is-the-lifted-white-card`). The accent there colors progress, the now line, badges and links, as Blue did.

Options considered:
- `.tint` as a shape style everywhere (rejected): `Color` is needed in attributed strings, as a view and for UIKit, and a component that sets its own `.tint` would change what its children draw.
- A UIKit trait that dynamic colors read (rejected): no AppKit counterpart for the Mac, and SwiftUI does not promise to resolve custom traits in a `Color`.

### Alternate icons: six, drawn from the mark, per device

| Name | Mark | Ground | Dark appearance |
|---|---|---|---|
| Antenna (standard) | #5BB8FF | #0B0E13 | black ground |
| Mono | #F2F4F8 | #0B0E13 | black ground |
| Light | #0B0E13 | #F2F4F8 | stays light |
| Teal | #4FD1C5 | #0B0E13 | black ground |
| Amber | #FFB454 | #0B0E13 | black ground |
| Pink | #F472B6 | #0B0E13 | black ground |
| Violet | #C084FC | #0B0E13 | black ground |

`scripts/render-icons.sh` writes `Apps/Mobile/AppIcon-<Name>.icon` for each from `design/icon/waves.svg` and `mast.svg` with the mark color swapped, and an Apple TV image stack `Apps/TV/Assets.xcassets/AppIcon-<Name>.imagestack` (400 x 240, 1x and 2x) from the `tv-*` layers. `project.yml` lists the names in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` for iOS and tvOS. `actool` puts them under `CFBundleAlternateIcons` for both; that was tried with a scratch catalog before this was written. `AppIconChoice` in AntennaCore names each icon, its alternate name and its colors, and `AppIconTests` checks every file the script writes.

Settings shows each icon as a thumbnail drawn in SwiftUI from the same mark (`AntennaMark.Glyph`) and the table's colors, so no extra images ship.

The icon is per device. The system keeps the chosen alternate itself (`UIApplication.alternateIconName`) and restores it after an update, so the app stores nothing. A `UserDefaults` copy could only disagree with the system.

Options considered:
- Per profile, switched when the profile changes (rejected): iOS shows an alert each time the icon changes, which would appear on every profile switch.
- An icon per accent chosen automatically with the accent (rejected): same alert, and the Home Screen belongs to the device, not the person.

### Platforms

- iPhone and iPad: accent and app icon.
- Apple TV: accent and app icon. `setAlternateIconName` is available on tvOS since 10.2 and takes an image stack named in `CFBundleAlternateIcons`. Top Shelf images stay the standard ones.
- Mac: accent only. The Mac app is native SwiftUI, and AppKit has no alternate icon API. `NSApplication.applicationIconImage` changes the Dock tile only while the app runs; Finder, Launchpad and the Dock after quitting keep the bundle icon. A half-working icon picker is worse than none, so Settings on the Mac has no App icon row.

### Where it lives

`AppearanceSection` (`Apps/Shared/Views/Settings/AppearanceSection.swift`) sits in Settings after Preferences, with Accent for the current profile and, on iPhone, iPad and Apple TV, App icon. Its rows push `SwatchChoiceList` (`Apps/Shared/Components/Settings/SwatchChoices.swift`), a list with a swatch or thumbnail, the name and a checkmark, which on Apple TV sits in the settings split page. The profile editors (`ProfileEditSheet` on iPhone, iPad and Mac, `ProfileEdit` on Apple TV) gain a row of five accent swatches under the circle colors.

On iPhone the section is Settings content only. Where Settings opens from is the business of `split-movies-and-series-tabs`.

### Identifiers

- `settings.appearance.accent`: the Accent row. Its accessibility value is the accent the environment holds, which is how the UI tests check that the tint followed the pick.
- `settings.appearance.icon`: the App icon row; value is the icon's name.
- `settings.choice.<id>`: a row on a pushed choices page, such as `settings.choice.teal` or `settings.choice.mono`.
- `profiles.edit.accent.<id>`: a swatch in the profile editor, such as `profiles.edit.accent.amber`.

### Strings

"Appearance", "Accent", "App icon", the five accent names, "Antenna", "Mono", "Light" and the footer "The accent is for this profile on every device. The app icon is for this device only.", in every catalog language. Accent names are colors, so they translate.

## Risks

- `ProfileRecord.accent` is a new optional field on a synced record, a lightweight CloudKit migration. An older build ignores it and shows Blue.
- `filter-adult-content` adds `showsAdult` to the same record and type. The two fields are independent; whichever lands second rebases.
- A changed icon shows the system's "You have changed the icon" alert. That is the platform's behavior and stays.
