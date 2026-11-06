# Proposal

## Why

> As a new user, I want to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing.

> As a household setter-upper, I want sources I add on one device to appear on my other devices, so I never type a URL or password twice.

> As a household setter-upper, I want to type long details on my iPhone instead of with the TV remote, so setting up an Apple TV is not a chore.

Setting up a source with the Siri Remote takes minutes and goes wrong often. Users report that a stray space after a pasted address breaks the login. The iPhone has a keyboard, a clipboard and the provider's email, but today the Apple TV offers the iPhone's keyboard for one field at a time, and onboarding's hint that sources added on iPhone appear on the TV leaves the user to find the right screen themselves. Until logins can reach the Apple TV, this removes all typing for playlist sources and all but the login for Xtream sources.

Not reviewed yet.

## What Changes

- A QR code on the Apple TV's setup details step when the TV is signed in to iCloud. The code holds a web link with a random one-time code and nothing else.
- A Handoff offer while the QR code is shown, so a nearby iPhone, iPad or Mac can open Antenna without scanning.
- On iPhone, iPad and Mac, the link or Handoff opens the add-source form in a "Set up Apple TV" version, then a screen showing the source being sent.
- The Apple TV notices the new source arriving through iCloud, shows a hint if nothing comes, and for Xtream offers to sign in with Name and Server already filled.
- A plain web page for an iPhone without Antenna, linking to the App Store.

Out of scope:
- Sending the login to the Apple TV. That waits for a decision that changes adr-0003 and a change after it. No password travels in the link, in iCloud records or over the local network.
- A QR code on the "sign in on this Apple TV" step for a source that synced without its login.
- A QR code on the welcome step or in Settings after setup.
- Scanning a provider's own QR code into the form.
- Pairing devices on different iCloud accounts.
- Scanning with an Apple Watch or a Mac camera.
- The paywall.
- Removing spaces pasted around addresses and usernames, which first-run onboarding takes on.
- Smart App Banners or other web-to-app flows beyond the fallback page.

## Capabilities

### New Capabilities
- `iphone-as-setup-device`: setting up an Apple TV source from an iPhone, iPad or Mac by QR code or Handoff, with the source travelling through iCloud.

### Modified Capabilities

None.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `source-management`, `channel-catalogue`, `guide-data`, and the changes `add-first-run-onboarding`, `add-live-tv-on-iphone-ipad-mac`.
- Needs from other changes: `add-first-run-onboarding` holds its root view while the QR card or the "Set up Apple TV" form is open, gives its keyboard card an identifier, and removes spaces pasted around addresses and usernames in its add-source form. `add-live-tv-on-iphone-ipad-mac` loads a source added while the shell is open.
- Blocked on: a decision that picks the web domain for the setup link and who hosts its two static files (the link file Apple reads and the page shown when Antenna is not installed), and says that host logs nothing.
