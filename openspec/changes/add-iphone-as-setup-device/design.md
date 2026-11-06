# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Onboard-3-QR.dc.html`, `TV-Onboard-3-QR-Timeout.dc.html`, `TV-Onboard-3-QR-SignIn.dc.html`, `TV-Onboard-3-QR-Received.dc.html` (drawn for the later credential change), `iPhone-Onboard-2-FromTV.dc.html`, `iPhone-Onboard-2-FromTV-Waiting.dc.html`, `iPhone-Onboard-2-FromTV-Sent.dc.html`, `iPhone-Onboard-2-FromTV-Timeout.dc.html`.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the Apple TV hint for a source this card cannot set up, the not-signed-in version of the "Not sent yet" row, the update line for a link from a newer Antenna, and the web page for an iPhone without Antenna, which is not an app screen.

Decisions this builds on: adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only).

## Goals / Non-Goals

**Goals:**
- No login, source detail or device detail travels in the link, the Handoff data or the logs.
- The TV makes exactly one change to an arrived source, and only on Xtream sign-in.

**Non-Goals:**
- Sending the login to the TV. Under adr-0003 no login reaches tvOS. An Xtream source arriving with its login, a login arriving later, and a "Keep waiting" button after 60 seconds belong to a later credential change, with `TV-Onboard-3-QR-Received.dc.html` as its board.
- Matching an arrived source to the exact code. Any new source in the time window counts.

## Decisions

- The text of the old spec before its trim (commit 19e8729) holds the board states with their wording, the identifiers, the link format (`https://<host>/setup?v=1&t=<22-character base64url token>`), the Handoff activity type `se.codecrave.antenna.setup`, the entitlement and association file contents, and the fallback page rules. Start from it. The assumed host is `antenna.codecrave.se` until the hosting decision picks one.
- The TV checks its store every 2 seconds while the card is shown, snapshots the source ids present on entry, counts only sources created within 300 seconds before the card appeared, and reads the raw kind so unknown kinds are not mistaken for playlists. Back from sleep, it checks at once. Sources already there, without an address, or of an unknown kind are ignored.
- Device checks before the change is implemented: whether tvOS offers Handoff to a nearby iPhone at all (if not, Handoff leaves the scanning requirement and the footer loses the App Switcher sentence); whether SwiftData's container posts CloudKit export events (if not, the hand-off confirmation requirement is dropped and "Not sent yet" is the only end state); whether the TV target needs the associated domain.
- First-run onboarding changes first: its keyboard card gets an identifier, the root view does not switch while the QR card or the "Set up Apple TV" form is open, and its form removes spaces pasted around the server, playlist and guide addresses and the username, leaving the password alone unless onboarding decides otherwise. Live TV on iPhone, iPad and Mac loads a source added while the shell is open, or a source sent from the shell does not appear until relaunch.
- The token, link and Handoff data are never logged or stored, and the link types take no source, credential, device name or iCloud id.
- When Xtream sign-in on the TV succeeds for a source without a credential key, the key is set to the source id first. That is the only change the TV makes to an arrived source.
- On the iPhone: a code already used in this launch opens nothing; another code while any add-source sheet is open is dropped; Cancel before Connect saves nothing and forgets the code; Connect errors show as in onboarding and keep the banner.
- The form notes how many sources the iPhone already has, since they reach the TV on their own.

## Risks / Trade-offs

- Open question: should the TV match the arrived source to the code exactly? Today any new source in the window counts, so a source added at the same moment by someone else on the same iCloud account would be taken. Matching needs a new optional field on the source and a schema decision. Changes the playlist-arrival requirement. Decide before the change is accepted.
- Open question: should the QR code also appear on the type step, so the user never picks a type on the TV? Changes the QR code requirement.
- Open question: load channels and guide on the iPhone right after Connect, or only on "Continue on iPhone"? Can be settled during implementation.
- [The 120-second hint and the 30-second upload timeout are guesses] → measure on devices.
- [An offline TV cannot be told apart from a wrong account] → the hint names both causes.
