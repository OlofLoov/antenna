# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Onboard-3-QR.dc.html`, `TV-Onboard-3-QR-Timeout.dc.html`, `TV-Onboard-3-QR-SignIn.dc.html`, `TV-Onboard-3-QR-Received.dc.html` (drawn for the later credential change), `iPhone-Onboard-2-FromTV.dc.html`, `iPhone-Onboard-2-FromTV-Waiting.dc.html`, `iPhone-Onboard-2-FromTV-Sent.dc.html`, `iPhone-Onboard-2-FromTV-Timeout.dc.html`.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the Apple TV hint for a source this card cannot set up, the Apple TV sign-in for an arrived Stalker portal, the not-signed-in version of the "Not sent yet" row, the update line for a link from a newer Antenna, and the web page for an iPhone without Antenna, which is not an app screen.

## Goals / Non-Goals

**Goals:**
- No login, source detail or device detail travels in the link, the Handoff data or the logs.
- The TV makes exactly one change to an arrived source, and only on Xtream or Stalker sign-in.

**Non-Goals:**
- Sending the login to the TV. Secrets live only in the synchronizable iCloud Keychain, which Apple TV does not offer, so no login or Stalker MAC address reaches tvOS. An Xtream source arriving with its login, a login arriving later, and a "Keep waiting" button after 60 seconds belong to a later credential change, with `TV-Onboard-3-QR-Received.dc.html` as its board.
- Matching an arrived source to the exact code. Any new source in the time window counts.

## Decisions

- Board states with their wording, the identifiers, the link format (`https://<host>/setup?v=1&t=<22-character base64url token>`), the Handoff activity `se.codecrave.antenna.setup`, the entitlement and association file contents, and the fallback page rules are in the sections below. The assumed host is `antenna.code-crave.se` until the hosting decision picks one.
- The TV checks its store every 2 seconds while the card is shown, snapshots the source ids present on entry, counts only sources created within 300 seconds before the card appeared, and reads the raw kind so unknown kinds are not mistaken for playlists. Back from sleep, it checks at once. Sources already there, without an address, or of an unknown kind are ignored.
- Device checks before the change is implemented: whether tvOS offers Handoff to a nearby iPhone at all (if not, Handoff leaves the scanning requirement and the footer loses the App Switcher sentence); whether SwiftData's container posts CloudKit export events (if not, the hand-off confirmation requirement is dropped and "Not sent yet" is the only end state); whether the TV target needs the associated domain.
- First-run onboarding changes first: its keyboard card gets an identifier, the root view does not switch while the QR card or the "Set up Apple TV" form is open, and its form removes spaces pasted around the server, playlist and guide addresses and the username, leaving the password alone unless onboarding decides otherwise. Live TV on iPhone, iPad and Mac loads a source added while the shell is open, or a source sent from the shell does not appear until relaunch.
- The token, link and Handoff data are never logged or stored, and the link types take no source, credential, device name or iCloud id.
- When Xtream or Stalker sign-in on the TV succeeds for a source without a credential key, the key is set to the source id first. That is the only change the TV makes to an arrived source.
- On the iPhone: a code already used in this launch opens nothing; another code while any add-source sheet is open is dropped; Cancel before Connect saves nothing and forgets the code; Connect errors show as in onboarding and keep the banner.
- The form notes how many sources the iPhone already has, since they reach the TV on their own.

## Board states and copy

`<device>` in every string is "iPhone", "iPad" or "Mac" for the platform the sheet runs on. The boards show the iPhone wording. "Signed in to iCloud" means `CKContainer.accountStatus()` reports `.available`, so an Apple ID without iCloud Drive counts as not signed in.

Apple TV:

- Waiting (`TV-Onboard-3-QR`): onboarding's details form on the left, unchanged. On the right `onboarding.qr` with the title "Set up from your iPhone" at 30 pt, a white 300 pt QR tile, body copy at 22 pt `#D7DEE8`, `onboarding.qr.status` "Waiting for your iPhone" at 20 pt muted with a 12 pt accent dot, and a 20 pt muted footer that names Handoff and the remote. The footer names the iOS keyboard offer generically ("your iPhone offers its keyboard too"). The card replaces onboarding's "Easier to type on your iPhone" card, which stays for an Apple TV not signed in to iCloud.
- The QR tile is white because a scanner needs a light quiet zone. It is not focusable. The pattern on the board is a placeholder; the app renders the setup link.
- `onboarding.qr.code` has the accessibility label "QR code. Scan it with your iPhone to set up this Apple TV from there."
- Nothing arrived after 120 s (`TV-Onboard-3-QR-Timeout`): `onboarding.qr.hint` at 22 pt muted under the status, reading "Nothing yet? Your iPhone needs Antenna installed, an internet connection and the same iCloud account as this Apple TV." The code and status stay.
- A source arrived that the card cannot use (a kind this build does not know, or a source without an address), after the same 120 s: the hint reads "A source arrived from iCloud that this Apple TV can't set up here. Update Antenna, or type the source here." Not drawn.
- Xtream source arrived (`TV-Onboard-3-QR-SignIn`): the tile at 40% opacity. Status rows "<name> arrived from your iPhone" with a 28 pt accent check, and "The login hasn't reached this Apple TV." in the error style with a 28 pt `#FF5F57` glyph. Name and Server hold the arrived record's `name` and `url.absoluteString`, read-only and not focusable. Form title "Sign in on this Apple TV", subtitle "Server and name came from your iPhone.". `onboarding.qr.signInHere` is the 64 pt white button. Username and Password keep any text typed before the arrival. Focus stays in a field if it was in one, and a right press from any field moves to `onboarding.qr.signInHere`; otherwise the button takes focus. Selecting it moves focus to Username and removes the button.
- Menu while the card is shown goes back to the type step with the entered values kept, drops the link and the Handoff offer, and stops the store check. Entering the details step again starts with a new code and a new snapshot. After an Xtream arrival, Name and Server go back to what the user had typed (empty if nothing) and are focusable again.
- Stalker portal arrived, not drawn: as the Xtream arrival, with the form title "Sign in on this Apple TV", the subtitle "Portal and name came from your iPhone.", Name and Portal read-only, the second status row "The MAC address hasn't reached this Apple TV.", and the MAC address, Login and Password fields of onboarding's portal form. Any MAC address, login or password typed before the arrival stays.
- `TV-Onboard-3-QR-Received` ("Waiting for the login…" with a 28 pt ring, Username focused and empty) belongs to the later credential change.

iPhone, iPad and Mac (iPad and Mac center the same sheet at 390 pt wide, as onboarding does):

- Form from TV (`iPhone-Onboard-2-FromTV`): nav "Cancel" and title "Set up Apple TV". `onboarding.fromTV.banner` reads "Opened from your Apple TV" at 15 pt with the 13 pt muted second line "Fill this in here. The source syncs to the Apple TV through iCloud.". Then onboarding's type picker with Xtream selected and all three types enabled, the clipboard banner (its second line reads "Spaces around it are removed when you connect"), the fields, the lock note and Connect. No Guide toggle.
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
- `SetupLink(token:).url` is `https://\(SetupLink.host)/setup?v=1&t=<token>`, with the query items `v` and `t` in that order. `SetupLink.host` is `antenna.code-crave.se` until the hosting decision picks one.
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

## Implementation decisions

- Stalker portals are set up from the iPhone like Xtream (2026-11-12). When this change was written, Stalker was shown disabled and the TV treated an arrived portal as a source it could not set up. Onboarding now connects portals with an address and a MAC address, and the Apple TV sign-in asks a synced portal for its MAC. The MAC address lives in the Keychain as the portal's credential, so it does not reach the TV either, and an arrived portal goes to the same sign-in as an Xtream source with the portal's MAC address, Login and Password fields. The board `iPhone-Onboard-2-FromTV.dc.html` still draws the Stalker segment disabled; the app enables it, and the board needs redrawing.
- Jellyfin servers arrive like Xtream sources. Jellyfin reached main while this change was being built, and its Apple TV sign-in asks a synced server for its username and password, so an arrived server goes to the same sign-in with Name and Server locked. Channels DVR reached main after Jellyfin, and its change made an arrived Channels DVR server load like a playlist: the TV asks the server for its lineup with no login. A server that needs a login fails that request, and the form shows onboarding's message with the address filled in. The arrival check switches over every source kind with no default, so adding a kind fails to compile until it is decided here.
- `SetupArrivals` in `Packages/AntennaCore/Sources/AntennaCore/Setup/` holds the arrival rules (the snapshot, the 300-second window, the first by creation time, kinds it cannot use), so they are tested without SwiftData. The TV model feeds it the stored sources on each check.
- `SetupPairingModel` and the arrival handling in `OnboardingModel` build on every platform, though only the Apple TV shows the card, so their integration tests run in `AntennaTests` on every PR instead of only in the nightly tvOS unit tests. The UI tests in `SetupTVUITests` cover the screens on tvOS.
- An arrived playlist is downloaded on the TV through the same probe the form uses, and its checklist starts from that download. If the download fails, the form shows onboarding's message with the playlist filled in and the QR card stays dimmed, so Connect on the TV can try again. Options were to start the checklist before the download (the checklist has no line for it) or to hide the failure; neither tells the user what went wrong.
- An arrived login source reuses the Apple TV sign-in that `OnboardingModel.signIn` already runs for a source that synced without its login, so the TV sets the credential key and adds no source by the same code path. The screen is a new component, `SetupSignIn.Television`, because the board keeps the QR card beside the form.
- `SetupCard.Television` takes its "Sign in on this Apple TV" button as a view slot, so the sign-in screen owns the focus state and moves focus to the first login field when the button is chosen.
- When a login source arrives, the "Sign in on this Apple TV" button takes focus even if the user was typing in a field. The design asks focus to stay in the field; tvOS rebuilds the focus tree when the form becomes the sign-in, and keeping it needs the two screens merged into one view. Left as a known gap.
- The QR card's iCloud check uses `CKContainer.accountStatus()` as designed. The welcome screen's sync line keeps `ubiquityIdentityToken`, as onboarding decided.
- The UI test "no second source" check for an arrived Xtream source lives in the integration test `SetupPairingTests`, which counts the stored sources after sign-in. The UI test proves the sign-in screen, the locked values and the focus moves.
- UI tests stand in for the iPhone with `-ui-testing-setup-send <kind>`, which saves a source once the card shows, and shorten the hint with `UITESTING_SETUP_HINT_SECONDS`. The store check runs every 0.5 seconds under UI tests.
- `SetupInbox` holds a setup link the way `ImportInbox` holds a shared file: it sits above the paywall in `AntennaApp`, and `PlatformRoot`, below the paywall, shows the sheet. A link that arrives while the paywall is up opens the sheet once the app unlocks, and a lapse removes `PlatformRoot` with the sheet while the saved source stays. This replaces the planned `SetupLinkRouter` that took the entitlement provider, because the window root now decides the paywall for every screen.
- The inbox drops a second link while the "Set up Apple TV" sheet is open. It does not know about onboarding's or Settings' own add-source sheets, so a link that arrives while one of those is open shows the setup sheet over it. Left as is; the two sheets do not share state.
- Cancel before Connect forgets the code, so the same code can open the sheet again; Continue marks it used for the rest of the launch.
- Continue opens onboarding's checklist in the same sheet, as Settings' add-source sheet does, including its "Add another source". Start watching closes the sheet and leaves the shell, or the welcome screen's switch to the shell, as it is: the sheet sits outside onboarding's gate and cannot hand a channel to it. The design asked for no "Add another" over the shell and for the first channel to play over the welcome step; both are left for a later change.
- The onboarding gate holds the welcome screen while the setup sheet is open, so the sheet stays over the welcome step and the shell shows after it closes.
- `SetupDelivery` subscribes to export events before it reads the iCloud state, so an upload that finishes while it asks still counts. Only a successful export whose start is at or after the moment Connect began counts.
- The setup form hides "Import a file instead". A file source has no address, so the Apple TV card ignores it.
- The clipboard banner keeps onboarding's wording. "Spaces around it are removed when you connect" waits for onboarding to trim pasted spaces, which this change leaves to it.
- The associated-domains entitlement is not added yet. `Config/Antenna.entitlements` holds no capability today, not even iCloud, and adding one changes provisioning for device builds; it goes in with the hosting decision and the device checks. `NSUserActivityTypes` is in `project.yml` for the Antenna target. `Web/.well-known/apple-app-site-association` waits for the team id.
- `Web/setup/index.html` exists with a placeholder App Store id, and a core test checks the page rules (body text, one App Store link, only `meta` and `title` in the head, no script, iframe, image or link tags).
- `onOpenURL` is registered twice, once for shared files and once for setup links; each inbox ignores links that are not its own. Whether SwiftUI calls both handlers for a universal link is unverified until the device check, since UI tests open the link through a launch argument.
