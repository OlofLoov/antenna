# 0036. iPhone as setup device for Apple TV: QR code and Handoff

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Builds on specs: 0004, 0006, 0010, 0013, 0014
- Blocked on: an ADR that picks the web domain for the setup link and who hosts its two static files (the link file Apple reads and the page shown when Antenna is not installed), and says that host logs nothing.
- Needs from other specs: 0006, a revision where the root view holds while the QR card or the "Set up Apple TV" form is open, its keyboard card gets an identifier, and its add-source form removes spaces pasted around addresses and usernames; 0010, a revision that loads a source added while the shell is open.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-1, US-2, US-3

## Summary

Typing a server address and a password with the Apple TV remote is slow and error-prone. With this spec, the Apple TV's setup screen shows a QR code; the user scans it with their iPhone, fills in the source on the phone's keyboard (or pastes it), and the source travels to the Apple TV through iCloud. A playlist source is then ready on the TV with no typing at all; a login source needs only the username and password typed once on the TV, because logins do not sync to Apple TV yet. An iPad can scan the code too; a nearby iPhone, iPad or Mac can also pick it up through Handoff if the Apple TV offers it, which is checked on a device before implementation. It does not send passwords to the TV, pair devices on different iCloud accounts, or read a provider's own QR codes.

## Design

Boards: `docs/design/boards/TV-Onboard-3-QR.dc.html`, `docs/design/boards/TV-Onboard-3-QR-Timeout.dc.html`, `docs/design/boards/TV-Onboard-3-QR-SignIn.dc.html`, `docs/design/boards/TV-Onboard-3-QR-Received.dc.html` (drawn for the later credential spec), `docs/design/boards/iPhone-Onboard-2-FromTV.dc.html`, `docs/design/boards/iPhone-Onboard-2-FromTV-Waiting.dc.html`, `docs/design/boards/iPhone-Onboard-2-FromTV-Sent.dc.html`, `docs/design/boards/iPhone-Onboard-2-FromTV-Timeout.dc.html`.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15.
Not drawn: the Apple TV hint for a source this card cannot set up (AC-13), the not-signed-in version of the "Not sent yet" row (AC-26), the update line for a link from a newer Antenna, and the web page for an iPhone without Antenna (AC-31), which is not an app screen.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Setting up a source with the Siri Remote takes minutes and goes wrong often; users report that a stray space after a pasted address breaks the login. The iPhone has a keyboard, a clipboard and the provider's email, but today the Apple TV only offers the iPhone's keyboard for one field at a time, and 0006's hint that sources added on iPhone appear on the TV leaves the user to find the right screen themselves. Until logins can reach the Apple TV, this removes all typing for playlist sources and all but the login for Xtream sources.

## Scope

In:
- A QR code on the Apple TV's setup details step when the TV is signed in to iCloud. The code holds a web link with a random one-time code and nothing else.
- A Handoff offer while the QR code is shown, so a nearby iPhone, iPad or Mac can open Antenna without scanning.
- On iPhone, iPad and Mac, the link or Handoff opens the add-source form in a "Set up Apple TV" version, then a screen showing the source being sent.
- The Apple TV noticing the new source arriving through iCloud, with a hint if nothing comes, and for Xtream an offer to sign in with Name and Server already filled.
- A plain web page for an iPhone without Antenna, linking to the App Store.

Out (explicitly):
- Sending the login to the Apple TV. That waits for an ADR that changes ADR-0003 and a spec after it. No password ever travels in the link, in iCloud records or over the local network under this spec.
- A QR code on the "sign in on this Apple TV" step for a source that synced without its login.
- A QR code on the welcome step or in Settings after setup.
- Scanning a provider's own QR code into the form.
- Pairing devices on different iCloud accounts.
- Scanning with an Apple Watch or a Mac camera.
- The paywall.
- Removing spaces pasted around addresses and usernames: 0006's revision.
- Smart App Banners or other web-to-app flows beyond the fallback page.

## User flow

Apple TV:
1. On the setup details step, the form is on the left as before. On the right: "Set up from iPhone", a QR code, one sentence on what happens, "Waiting for iPhone", and a note that Antenna also shows in the iPhone's App Switcher and the remote still works.
2. The user scans the code with the iPhone camera, or opens Antenna from the App Switcher.
3. The source arrives through iCloud. A playlist source goes straight to loading channels. For Xtream, the TV says "<name> arrived from iPhone", fills in and locks Name and Server, says the login has not reached this Apple TV, and offers "Sign in on this Apple TV".
4. The user types the username and password once; Connect checks them and loading starts.
5. If nothing arrives within two minutes, a hint lists the usual causes. The user can type on the TV at any time.

iPhone, iPad and Mac:
1. The camera shows "Open in Antenna". Antenna opens the "Set up Apple TV" form with the banner "Opened from Apple TV" over whatever was on screen. Handoff opens the same form.
2. Without Antenna installed, the camera opens a web page that says what Antenna does and links to the App Store.
3. The user fills in the form, by pasting or typing, and taps Connect. 0006's checks and errors apply.
4. The form becomes "Sending to Apple TV": "Saved on this iPhone" is done and the Apple TV row is in progress. When iCloud confirms the upload it reads "Handed to iCloud. Open Antenna on Apple TV." After 30 seconds without confirmation it reads "Not sent yet" with what to check. "Continue on iPhone" is always there.

## Acceptance criteria

### AC-1 The Apple TV offers a QR code
Given an Apple TV that is signed in to iCloud and on the setup details step
When the step appears
Then a "Set up from iPhone" card shows a scannable QR code for the setup link, a status reading "Waiting for iPhone", and VoiceOver describes the code as something to scan with an iPhone; 0006's keyboard card is not shown.

### AC-2 No iCloud, no QR code
Given an Apple TV that is not signed in to iCloud
When the details step shows
Then 0006's keyboard card shows and there is no QR code or Handoff offer.

### AC-5 The code carries nothing but a random one-time code
Given the QR card on screen
When anyone reads the link in the code or the Handoff offer
Then they find only a version number and a random code that is new each time the user enters the step, and no source, password, device name or account detail.

### AC-8 A playlist source sent from the iPhone starts loading on the TV
Given the QR card on screen
When a new playlist source, created after the user reached this step (allowing for clock drift), arrives through iCloud
Then the TV goes on to loading channels for that source and adds no source of its own.

### AC-10 An Xtream source sent from the iPhone needs only the login on the TV
Given the QR card on screen and possibly some text in the TV's username and password fields
When a new Xtream source arrives through iCloud and the user signs in on the TV
Then the TV says the source arrived and the login has not reached it, fills in and locks Name and Server, keeps what the user had typed in the login fields, and on Connect saves the login for the arrived source without adding a second one.

### AC-13 Nothing arrives, and the TV says why that might be
Given the QR card on screen
When two minutes pass with no usable source
Then a hint says the iPhone needs Antenna, an internet connection and the same iCloud account as the TV; if a source arrived that this card cannot set up, the hint says to update Antenna or type the source on the TV instead.

### AC-15 Typing on the TV still works
Given the QR card on screen
When the user fills in the form on the TV and Connect succeeds
Then the TV goes on to loading as 0006 says, the QR card and Handoff offer go away, and a source arriving from the iPhone afterwards stays in the list without changing the screen.

### AC-17 Scanning opens the setup form on the iPhone
Given Antenna on an iPhone, iPad or Mac, on any screen
When the user scans the code or accepts the Handoff offer
Then a "Set up Apple TV" form opens with the banner "Opened from Apple TV" and 0006's fields, and the same code arriving again opens nothing new.

### AC-24 The iPhone shows the source on its way
Given the "Set up Apple TV" form on iPhone, iPad or Mac
When Connect succeeds
Then the form becomes "Sending to Apple TV" with "Saved on this iPhone" done and the Apple TV row in progress, it cannot be swiped or escaped away, and "Continue on iPhone" leads to 0006's ready screen.

### AC-26 The iPhone says what to check when sending stalls
Given the sending screen
When 30 seconds pass without iCloud confirming the upload, or the device is not signed in to iCloud
Then the Apple TV row reads "Not sent yet" and tells the user to check the device is online and signed in to iCloud, at once when it is not signed in.

### AC-31 An iPhone without Antenna gets a plain page
Given an iPhone without Antenna installed
When the camera opens the setup link
Then Safari shows a page that says "Antenna sets up Apple TV from iPhone." with one link to the App Store, and no scripts, images or third-party content.

### AC-35 The iPhone confirms the hand-off to iCloud
Given the sending screen, including after it reads "Not sent yet"
When iCloud confirms the upload
Then the Apple TV row reads "Handed to iCloud. Open Antenna on Apple TV." and "Continue on iPhone" becomes the main button.

## Edge cases

- Offline Apple TV: the QR card shows, nothing arrives, and the two-minute hint appears; the TV cannot tell this from a wrong account.
- Offline iPhone: Connect fails as in 0006 before anything is saved. Going offline after saving leads to "Not sent yet".
- Two iPhones scan the same code: both forms work; the first source to arrive is the one the TV uses and the other stays in the list.
- A photo of the code sent to someone else opens an empty form on their phone; whatever they add lands in their own iCloud.
- Different iCloud accounts on the two devices: nothing arrives and the hint names the same-account requirement.
- First launch on the TV while iCloud is still downloading old sources: only sources created after the user reached the step count as arrived.
- The TV ignores sources that were already there, have no address, or are of a kind the card cannot set up (AC-13 covers the visible result).
- Signing in or out of iCloud while the step is open swaps the QR card and 0006's keyboard card; the QR card shows a fresh code.
- A damaged setup link opens the plain add-source form; a link from a newer Antenna does the same and asks the user to update.
- A playlist source arriving while the user types on the TV replaces the form with loading, and the typed text is discarded.
- Opening the setup link in Safari on an iPhone that has Antenna shows the fallback page.
- If the entitlement lapses on the iPhone while the form is open, the paywall replaces it and the saved source stays.
- A link arriving while the paywall is up opens the form once the purchase goes through.
- With Reduce Motion on, progress rows show "In progress" instead of a spinner; with VoiceOver, each status row reads as one item.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | integration |
| AC-5 | core |
| AC-8 | integration |
| AC-10 | ui |
| AC-13 | integration |
| AC-15 | integration |
| AC-17 | ui |
| AC-24 | ui |
| AC-26 | integration |
| AC-31 | integration |
| AC-35 | integration |

## Open questions

- Should the TV match the arrived source to the code exactly? Today any new source in the window counts, so a source added at the same moment by someone else on the same iCloud account would be taken. Matching needs a new optional field on the source and a schema ADR. Changes AC-8; decide before Accepted.
- Should the QR code also appear on the type step, so the user never picks a type on the TV? Changes AC-1.
- Load channels and guide on the iPhone right after Connect, or only on "Continue on iPhone"? Can be decided in the plan.

## Notes for the plan

- The text of this spec before the trim (commit 19e8729) holds the board states with their wording, the identifiers, the link format (`https://<host>/setup?v=1&t=<22-character base64url token>`), the Handoff activity type `se.codecrave.antenna.setup`, the entitlement and association file contents, and the fallback page rules. Start from it; the assumed host is `antenna.codecrave.se` until the ADR picks one.
- The TV checks its store every 2 seconds while the card is shown, snapshots the source ids present on entry, counts only sources created within 300 seconds before the card appeared, and reads the raw kind so unknown kinds are not mistaken for playlists. Back from sleep, it checks at once.
- Device checks before Implemented: whether tvOS offers Handoff to a nearby iPhone at all (if not, Handoff leaves AC-17 and the footer loses the App Switcher sentence); whether SwiftData's container posts CloudKit export events (if not, AC-35 is dropped and AC-26 is the only end state); whether the TV target needs the associated domain.
- 0006 changes first: its keyboard card gets an identifier, the root view does not switch while the QR card or the "Set up Apple TV" form is open, and its form removes spaces pasted around the server, playlist and guide addresses and the username (this spec's old AC-23, AC-23b and AC-23c), leaving the password alone unless 0006 decides otherwise. 0010 needs to load a source added while the shell is open, or a source sent from the shell does not appear until relaunch.
- The token, link and Handoff data are never logged or stored, and the link types take no source, credential, device name or iCloud id.
- When Xtream sign-in on the TV succeeds for a source without a credential key, set the key to the source id first; that is the only change the TV makes to an arrived source.
- On the iPhone: a code already used in this launch opens nothing; another code while any add-source sheet is open is dropped; Cancel before Connect saves nothing and forgets the code; Connect errors show as in 0006 and keep the banner.
- The form notes how many sources the iPhone already has, since they reach the TV on their own.
- The 120-second hint and 30-second upload timeout are guesses; measure on devices.
- For the later credential spec, with `TV-Onboard-3-QR-Received.dc.html` as its board: an Xtream source arriving with its login, a login arriving later, and a "Keep waiting" button after 60 seconds.

## Dropped

- AC-9 (Xtream source arrives with its login) and AC-11 (login arrives later, 60 s timeout, Keep waiting): under ADR-0003 no login reaches tvOS; moved to Notes for the plan (later credential spec).
- Moved to 0006's revision: AC-23, AC-23b, AC-23c.
- Moved to the implementation plan: AC-4b, AC-8c, AC-8d, AC-10d, AC-12a, AC-12c, AC-12d, AC-15c, AC-16, AC-16b, AC-20b, AC-21, AC-22, AC-28b, AC-28c, AC-29, AC-30, AC-32, AC-33, AC-34.
- Merged into AC-1: AC-1b.
- Merged into AC-2: AC-2b, AC-2c (both now an Edge case).
- Merged into AC-5: AC-3, AC-4, AC-6a, AC-6b.
- Merged into AC-8: AC-8b, AC-14.
- Merged into AC-10: AC-10b, AC-10c, AC-12b.
- Merged into AC-13: AC-14b.
- Merged into AC-15: AC-15b.
- Merged into AC-17: AC-7, AC-18, AC-19, AC-19b, AC-20.
- Merged into AC-24: AC-24b, AC-28.
- Merged into AC-26: AC-27.
- Merged into AC-35: AC-25, AC-26b.
