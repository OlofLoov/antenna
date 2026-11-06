# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Onboard-3-QR.dc.html`, `TV-Onboard-3-QR-Timeout.dc.html`, `TV-Onboard-3-QR-SignIn.dc.html`, `TV-Onboard-3-QR-Received.dc.html` (drawn for the later credential change), `iPhone-Onboard-2-FromTV.dc.html`, `iPhone-Onboard-2-FromTV-Waiting.dc.html`, `iPhone-Onboard-2-FromTV-Sent.dc.html`, `iPhone-Onboard-2-FromTV-Timeout.dc.html`.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the Apple TV hint for a source this card cannot set up, the not-signed-in version of the "Not sent yet" row, the update line for a link from a newer Antenna, and the web page for an iPhone without Antenna, which is not an app screen.

## Goals / Non-Goals

**Goals:**
- No login, source detail or device detail travels in the link, the Handoff data or the logs.
- The TV makes exactly one change to an arrived source, and only on Xtream sign-in.

**Non-Goals:**
- Sending the login to the TV. Secrets live only in the synchronizable iCloud Keychain, which Apple TV does not offer, so no login reaches tvOS. An Xtream source arriving with its login, a login arriving later, and a "Keep waiting" button after 60 seconds belong to a later credential change, with `TV-Onboard-3-QR-Received.dc.html` as its board.
- Matching an arrived source to the exact code. Any new source in the time window counts.

## Decisions

- Board states with their wording, the identifiers, the link format (`https://<host>/setup?v=1&t=<22-character base64url token>`), the Handoff activity `se.codecrave.antenna.setup`, the entitlement and association file contents, and the fallback page rules are in the sections below. The assumed host is `antenna.codecrave.se` until the hosting decision picks one.
- The TV checks its store every 2 seconds while the card is shown, snapshots the source ids present on entry, counts only sources created within 300 seconds before the card appeared, and reads the raw kind so unknown kinds are not mistaken for playlists. Back from sleep, it checks at once. Sources already there, without an address, or of an unknown kind are ignored.
- Device checks before the change is implemented: whether tvOS offers Handoff to a nearby iPhone at all (if not, Handoff leaves the scanning requirement and the footer loses the App Switcher sentence); whether SwiftData's container posts CloudKit export events (if not, the hand-off confirmation requirement is dropped and "Not sent yet" is the only end state); whether the TV target needs the associated domain.
- First-run onboarding changes first: its keyboard card gets an identifier, the root view does not switch while the QR card or the "Set up Apple TV" form is open, and its form removes spaces pasted around the server, playlist and guide addresses and the username, leaving the password alone unless onboarding decides otherwise. Live TV on iPhone, iPad and Mac loads a source added while the shell is open, or a source sent from the shell does not appear until relaunch.
- The token, link and Handoff data are never logged or stored, and the link types take no source, credential, device name or iCloud id.
- When Xtream sign-in on the TV succeeds for a source without a credential key, the key is set to the source id first. That is the only change the TV makes to an arrived source.
- On the iPhone: a code already used in this launch opens nothing; another code while any add-source sheet is open is dropped; Cancel before Connect saves nothing and forgets the code; Connect errors show as in onboarding and keep the banner.
- The form notes how many sources the iPhone already has, since they reach the TV on their own.

## Board states and copy

`<device>` in every string is "iPhone", "iPad" or "Mac" for the platform the sheet runs on. The boards show the iPhone wording. Some requirement scenarios quote these strings without "your"; the wording below matches the boards. "Signed in to iCloud" means `CKContainer.accountStatus()` reports `.available`, so an Apple ID without iCloud Drive counts as not signed in.

Apple TV:

- Waiting (`TV-Onboard-3-QR`): onboarding's details form on the left, unchanged. On the right `onboarding.qr` with the title "Set up from your iPhone" at 30 pt, a white 300 pt QR tile, body copy at 22 pt `#D7DEE8`, `onboarding.qr.status` "Waiting for your iPhone" at 20 pt muted with a 12 pt accent dot, and a 20 pt muted footer that names Handoff and the remote. The footer names the iOS keyboard offer generically ("your iPhone offers its keyboard too"). The card replaces onboarding's "Easier to type on your iPhone" card, which stays for an Apple TV not signed in to iCloud.
- The QR tile is white because a scanner needs a light quiet zone. It is not focusable. The pattern on the board is a placeholder; the app renders the setup link.
- `onboarding.qr.code` has the accessibility label "QR code. Scan it with your iPhone to set up this Apple TV from there."
- Nothing arrived after 120 s (`TV-Onboard-3-QR-Timeout`): `onboarding.qr.hint` at 22 pt muted under the status, reading "Nothing yet? Your iPhone needs Antenna installed, an internet connection and the same iCloud account as this Apple TV." The code and status stay.
- A source arrived that the card cannot use (Stalker, or a kind this build does not know), after the same 120 s: the hint reads "A source arrived from iCloud that this Apple TV can't set up here. Update Antenna, or type the source here." Not drawn.
- Xtream source arrived (`TV-Onboard-3-QR-SignIn`): the tile at 40% opacity. Status rows "<name> arrived from your iPhone" with a 28 pt accent check, and "The login hasn't reached this Apple TV." in the error style with a 28 pt `#FF5F57` glyph. Name and Server hold the arrived record's `name` and `url.absoluteString`, read-only and not focusable. Form title "Sign in on this Apple TV", subtitle "Server and name came from your iPhone.". `onboarding.qr.signInHere` is the 64 pt white button. Username and Password keep any text typed before the arrival. Focus stays in a field if it was in one, and a right press from any field moves to `onboarding.qr.signInHere`; otherwise the button takes focus. Selecting it moves focus to Username and removes the button.
- Menu while the card is shown goes back to the type step with the entered values kept, drops the link and the Handoff offer, and stops the store check. Entering the details step again starts with a new code and a new snapshot. After an Xtream arrival, Name and Server go back to what the user had typed (empty if nothing) and are focusable again.
- `TV-Onboard-3-QR-Received` ("Waiting for the login…" with a 28 pt ring, Username focused and empty) belongs to the later credential change.

iPhone, iPad and Mac (iPad and Mac center the same sheet at 390 pt wide, as onboarding does):

- Form from TV (`iPhone-Onboard-2-FromTV`): nav "Cancel" and title "Set up Apple TV". `onboarding.fromTV.banner` reads "Opened from your Apple TV" at 15 pt with the 13 pt muted second line "Fill this in here. The source syncs to the Apple TV through iCloud.". Then onboarding's type picker with Xtream selected, the clipboard banner (its second line reads "Spaces around it are removed when you connect"), the fields, the lock note and Connect. No Guide toggle.
- `onboarding.fromTV.existing`, one 13 pt muted line under the banner, not drawn: "This <device> already has 1 source. It appears on the Apple TV on its own when both use the same iCloud account." for one source, "This <device> already has <n> sources. They appear on the Apple TV on their own when both use the same iCloud account." for more, absent for none. Only sources with an address count.
- A link that does not parse opens onboarding's plain "Add a source" sheet with no banner and no error. For a link from a newer version, `onboarding.fromTV.update` sits above the form in 13 pt muted, not drawn: "This code is from a newer Antenna. Update Antenna on this <device> to set up your Apple TV from here."
- Sending (`iPhone-Onboard-2-FromTV-Waiting`): the form is replaced in the same sheet by `onboarding.sending`, title "Sending to your Apple TV" at 22 pt. `onboarding.sending.row.saved` done, reading "Saved on this <device>" with the source name beneath. `onboarding.sending.row.tv` in progress with a 26 pt ring, reading "Sending to your Apple TV…" with "Usually a few seconds" beneath. Lock note. `onboarding.sending.continue` as a surface button reading "Continue on <device>". No Cancel. Swipe-down on iPhone and iPad, and Escape and Command-period on Mac, do nothing. Channel and guide loading for the record starts as onboarding's Connect does.
- Sent (`iPhone-Onboard-2-FromTV-Sent`): `row.tv` done, reading "Handed to iCloud. Open Antenna on your Apple TV." with no detail. Continue becomes the white primary button. Only a successful export that started at or after the save counts; an earlier or failed one changes nothing.
- Not sent after 30 s (`iPhone-Onboard-2-FromTV-Timeout`): `row.tv` title "Not sent yet" with the detail "Check that this <device> is online and signed in to iCloud. It sends on its own once it can." in the error style, no ring, Continue as the primary button. A later confirmation still turns it into Sent.
- Not signed in to iCloud, not drawn: `row.tv` reads "Not sent yet" at once with the detail "This <device> isn't signed in to iCloud, so the source can't reach your Apple TV. Sign in to iCloud in Settings and it sends on its own." in the error style, and no 30 s timer runs.
- Continue opens onboarding's ready sheet for the saved record with its rows in whatever state loading has reached, and marks the code as used. Over the shell, the ready sheet has no "Add another" and Start watching leaves the playing channel alone. Over the welcome step, the welcome step stays under the sheet until Start watching, then the shell shows with the new source.
- Connect errors show onboarding's text in `onboarding.error`, save nothing, and keep the banner.
- Error style is 15 pt on iOS and 22 pt on tvOS in `#FF5F57`, as onboarding. Done markers use the accent. Step segments as onboarding, step 3 current.

Both platforms:

- With Reduce Motion on, a row in progress shows the static text "In progress" instead of a ring.
- With VoiceOver, each status row is one element labeled state, title and detail in that order, for example "Done. Saved on this iPhone. My Provider".

## Identifiers

New: `onboarding.qr`, `onboarding.qr.code`, `onboarding.qr.status`, `onboarding.qr.hint`, `onboarding.qr.signInHere`, `onboarding.fromTV`, `onboarding.fromTV.banner`, `onboarding.fromTV.existing`, `onboarding.fromTV.cancel`, `onboarding.fromTV.update`, `onboarding.sending`, `onboarding.sending.row.saved`, `onboarding.sending.row.tv`, `onboarding.sending.continue`, and `onboarding.keyboardCard` on onboarding's existing card. Everything else reuses onboarding's identifiers.

## Setup link and Handoff

- `SetupLink`, `PairingToken` and `SetupLink.Error` live in `Packages/AntennaCore/Sources/AntennaCore/Setup/`.
- `PairingToken` is 16 random bytes in base64url without padding, 22 characters. `PairingToken(using:)` takes an injected `RandomNumberGenerator`; `PairingToken()` uses `SystemRandomNumberGenerator`.
- `SetupLink(token:).url` is `https://\(SetupLink.host)/setup?v=1&t=<token>`, with the query items `v` and `t` in that order. `SetupLink.host` is `antenna.codecrave.se` until the hosting decision picks one.
- `SetupLink(url:)` accepts the items in either order and an uppercase host, ignores unknown query items, and reads `/setup/` as `/setup`. Checks run in this order and the first failure is thrown: host or path (`.notASetupLink`), then `v` (`.missingVersion` when absent, `.unsupportedVersion(String)` when not `1`), then `t` (`.missingToken` when absent, `.malformedToken` when not 22 base64url characters or when the last character has non-zero unused bits, so only the canonical encoding of 16 bytes parses). A repeated `v` or `t` is `.notASetupLink`.
- The Handoff activity: `activityType` `se.codecrave.antenna.setup`, `title` "Set up Antenna on Apple TV", `webpageURL` the setup link, `userInfo` exactly `["token": <token>]`, `isEligibleForHandoff` true, and `isEligibleForSearch`, `isEligibleForPrediction` and `isEligibleForPublicIndexing` false.
- The link and the activity are dropped, and the store check stops, when a source arrives, when Connect succeeds on the TV, on Menu, and when iCloud signs out while the card is shown.
- On iPhone, iPad and Mac the link arrives through `onOpenURL` or an `NSUserActivityTypeBrowsingWeb` activity, and Handoff through an activity of type `se.codecrave.antenna.setup` with a valid `userInfo["token"]`. While the paywall shows, nothing is presented; the sheet opens once the entitlement arrives, and a link from before a relaunch is not kept.
- The TV side is a `@MainActor` `SetupPairingModel` owned by onboarding's model, taking a `ModelContext`, `CredentialStore`, an identity provider over `CKContainer.accountStatus()` that relays `CKAccountChanged`, a clock, and an activity recorder that wraps `NSUserActivity`. The iPhone side is a `SetupLinkRouter` taking the entitlement provider and a `SyncEventSource` (`successfulExports: AsyncStream<DateInterval>`) over `NSPersistentCloudKitContainer.eventChangedNotification`.

## Universal link files

- `Config/Antenna.entitlements`, used by the Antenna target on iOS and macOS: `com.apple.developer.associated-domains` contains `applinks:<SetupLink.host>`.
- `Apps/Mobile/Info.plist`: `NSUserActivityTypes` contains exactly `se.codecrave.antenna.setup`. `Apps/TV/Info.plist` does not list it. Whether `Config/AntennaTV.entitlements` needs the domain for a Handoff activity with a `webpageURL` is one of the device checks.
- `Web/.well-known/apple-app-site-association` lists under `applinks.details[0].appIDs` one app id matching `^[A-Z0-9]{10}\.se\.codecrave\.antenna$` (the team id is public and committed), with one `components` entry `{ "/": "/setup" }` and nothing else. It is served over HTTPS as `application/json` with no redirect.
- `Web/` is a new top-level directory for the page and the association file. CLAUDE.md's Layout gains it.

## Fallback page

`Web/setup/index.html` is what Safari shows when an iPhone without Antenna opens the link.

- Its `<body>` text, tags removed and whitespace collapsed, is exactly "Antenna sets up your Apple TV from your iPhone. Get Antenna on the App Store".
- `<head>` holds only `<meta>` and `<title>` elements.
- Exactly one `<a href>`, whose host is `apps.apple.com`. The listing URL is a placeholder until the listing exists.
- No `<script`, `<iframe`, `<img` or `<link` anywhere. Styling is inline.
- It says nothing about content. On an iPhone that has Antenna but opened the link in Safari, the page shows and its App Store link opens the listing.

## Risks / Trade-offs

- Open question: should the TV match the arrived source to the code exactly? Today any new source in the window counts, so a source added at the same moment by someone else on the same iCloud account would be taken. Matching needs a new optional field on the source and a schema decision. Changes the playlist-arrival requirement. Decide before the change is accepted.
- Open question: should the QR code also appear on the type step, so the user never picks a type on the TV? Changes the QR code requirement.
- Open question: load channels and guide on the iPhone right after Connect, or only on "Continue on iPhone"? Can be settled during implementation.
- [The 120-second hint and the 30-second upload timeout are guesses] → measure on devices.
- [An offline TV cannot be told apart from a wrong account] → the hint names both causes.
