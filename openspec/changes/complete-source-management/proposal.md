## Why

The household setter-upper wants "sources I add on one device to appear on my other devices, so I never type a URL or password twice". The app does this through iCloud, and every part one device can show is tested. Nobody has yet checked that a source saved on one device shows up on a second device signed in to the same iCloud account. CloudKit does not sync on a simulator or in CI, so that check needs two devices and a person.

This change used to hold five on-screen checks for screens that are gone: the old add-source sheet, the empty channel list, a Settings list that showed each source's link, the pushed player, and sync. Newer changes replaced those screens and test what they do:

- The add-source form keeps its error on a link without a scheme (`add-first-run-onboarding`).
- With no source the app opens on onboarding, and deleting the last source returns there (`add-first-run-onboarding`, `add-sources-and-settings`).
- Sources and Settings lists sources in the user's order and shows no link (`add-sources-and-settings`).
- Picking a channel plays it, in place in Live on iPhone, iPad and Mac and full screen on Apple TV (`add-live-tv-on-iphone-ipad-mac`, `add-tv-channel-overlay`).
- Sources added, edited or reordered on another device show up on this one by themselves (`add-sources-and-settings`), tested by feeding the store change on one device.

What is left is sync across two real devices, which no automated test can prove, so the change is reduced to that one requirement.

## What Changes

- A source saved on one device appears in Sources and Settings on the user's other devices, with its name, type and status and never its link, and its channels load there.

Out of scope:
- Anything one device can show. The changes above own it.
- A delete reaching other devices, which `add-sources-and-settings` task 4.1 checks.

## Capabilities

### New Capabilities

### Modified Capabilities
- `source-management`: adds the two-device sync requirement.

## Impact

- No code. One manual check on two devices.
- Depends on `add-sources-and-settings` for the Sources and Settings list and the refresher that loads a synced source.
- Blocked on two devices signed in to one iCloud account with iCloud Keychain on.
