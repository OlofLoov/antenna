# Proposal

## Why

> As a user, I want to edit, refresh or remove a source, and change how the app behaves, so my setup stays right as my subscription changes.

> As a household setter-upper, I want sources I add on one device to appear on my other devices, so I never type a URL or password twice.

> As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text.

Once a source is added there is no way to fix a typo in its link, enter a password the provider changed, see whether it loaded, or remove it on Apple TV or Mac. Channels load once per launch, so a source added on iPhone shows nothing on an Apple TV that has been running since morning. The live TV screens assume something keeps every source loaded and the guide fed, and nothing does that yet.

Not reviewed yet.

## What Changes

- A Sources and Settings screen on every platform: the Settings tab on iPhone, the sidebar on iPad and Mac, the gear on Apple TV.
- A list of sources in the user's order, each with its channel count, guide days, when it last loaded on this device, and any problem.
- A source's details: what it holds, and an editable name, link, guide link, Xtream login, or Stalker MAC address and login, checked against the server before saving.
- Sign in on this Apple TV, for an Xtream source or Stalker portal whose login has not reached the device.
- Delete with confirmation on every platform, removing the source, its login, its favorites, its guide and its channels.
- Reorder sources by dragging, or with Move up and Move down on Apple TV.
- Every source loads at launch, when another device changes one, when a login arrives, by hand, and on a schedule.
- Preferences: which screen opens at launch, how many hours the guide shows, how often sources refresh, and on Apple TV whether swiping changes channel.
- An About row with the app version.
- **BREAKING** for `source-management`: delete moves here and works on every platform, a source row shows load status instead of what it showed before, and a source's load result is no longer kept on the synced source record.

Out of scope:
- Adding a source. Onboarding owns the form, and this screen opens it.
- Group management, guide sources per playlist and importing a playlist file. Each adds its own row to this screen when accepted.
- Keeping channel lists between launches. Every launch loads every source again.
- Changing a source's type.
- The crash on a repeated Xtream category id, which is a bug fix in the Xtream client.
- The paywall, restoring the purchase and managing it.
- Zap bar timing, guide zoom and other screens' fine-tuning.
- Diagnostics and log export.

## Capabilities

### New Capabilities
- `sources-and-settings`: look after added sources (status, edit, sign in, delete, reorder, refresh) and set app preferences, on every platform.

### Modified Capabilities
- `source-management`: delete, what a source row shows, when sources load and where a load result is kept move to `sources-and-settings`.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `source-management`, `favorites`, `channel-catalogue`, `guide-data`, `tvos-shell`, `xtream-vod-client`, and the changes `add-first-run-onboarding` and `add-live-tv-on-iphone-ipad-mac`.
- `channel-catalogue` and `guide-data` wait on the source loading this change adds, and several screens read its per-source states.
- Other changes read these preferences: `add-tv-zap-bar-and-number-entry` (swipe), `add-tv-guide-grid` (guide window), `guide-data` (refresh interval), `add-live-tv-on-iphone-ipad-mac` and `tvos-shell` (screen opened at launch).
- Blocked on: the decision `add-first-run-onboarding` names on where a login typed on an Apple TV is kept. The project rule is that secrets sync through iCloud Keychain, which Apple TV does not offer. This change assumes a login typed on an Apple TV stays there. The other outcome changes only the wording of the Apple TV sign-in requirement and the iCloud footer.
- Blocked on: where app preferences are stored. This change assumes one synced preferences record. A decision for per-device storage changes where the preference values live and nothing else.
