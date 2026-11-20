# Proposal

## Why

> As one of several people sharing Antenna, I want my profile to look like mine, and I want the icon on my Home Screen to match it.

On 2026-11-20 the owner decided what themes mean for Antenna: an accent color per profile and alternate app icons, nothing more. The app stays dark-only, like the Apple TV app, so there is no light mode and no full skin.

Today every profile shows the same blue on progress bars, the guide's now line, the NOW and UP NEXT badges, links, the selected iPhone tab and system controls. Profiles already have a circle color, but nothing else on screen changes when someone else picks their profile.

## What Changes

- Each profile gets an accent: Blue, Teal, Amber, Pink or Violet. Blue stays the default, so nothing changes on screen until someone picks another. Each passes 4.5:1 on the dark ground, on rows and on glass.
- The accent is picked in the profile editor when adding or editing a profile, and in Settings, Appearance for the current profile. It syncs with the profile.
- Every place that draws in the accent today draws in the profile's accent: progress, the now line, NOW and UP NEXT badges, links, the selected iPhone tab and the tint of system controls on iPhone, iPad and Mac. Apple TV keeps its system focus look.
- Settings, Appearance offers an app icon on iPhone, iPad and Apple TV: the standard icon and six alternates (Mono, Light, Teal, Amber, Pink, Violet), all drawn from the existing mark. The icon is per device.
- The design-system rule "One accent color" becomes "One accent color per profile" and keeps its limits on where the accent may appear.

Out of scope:
- Light mode, full skins, custom colors typed by the user.
- An alternate Dock icon on the Mac (the reason is in design.md).
- Tying the icon to the profile, or switching icons when the profile changes.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `design-system`: one accent color per profile, from a fixed set that passes contrast.
- `profiles`: adding and editing a profile picks its accent; profiles sync their accent.
- `sources-and-settings`: an Appearance section with the accent for the current profile and the app icon for this device.
- `app-release`: the alternate icons keep the mark and follow the Home Screen appearance like the standard icon.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV for the accent; iPhone, iPad and Apple TV for the icon.
- Code: `Packages/AntennaCore` (`ProfileAccent`, `AppIconChoice`, `Contrast`, `Profile.accent`), `Apps/Shared/Persistence` (one optional field on `ProfileRecord`), every component that draws in the accent today, `ProfileGate`, the profile editors, Settings, `scripts/render-icons.sh`, `project.yml`, `scripts/check-rules.sh`.
- Data: one optional field on an existing synced record, so CloudKit migrates lightly. An older build ignores it and shows blue.
- Strings: the section, the rows, five accent names, seven icon names and the footers, in every catalog language.
- Boards: `iPhone-Settings-Appearance`, `iPhone-Settings-AppIcon`, `iPad-Settings-Appearance`, `Mac-Settings-Appearance`, `TV-Settings-Appearance`, `TV-Settings-Accent`, `iPhone-Profiles-Edit-Accent`, `TV-Profiles-Edit-Accent`.
- Depends on: `profiles` (the editor and sync). Runs next to `filter-adult-content`, which adds a field to the same profile record, and `split-movies-and-series-tabs`, which moves Settings on iPhone behind the profile button; this change adds Settings content, not an entry point.
