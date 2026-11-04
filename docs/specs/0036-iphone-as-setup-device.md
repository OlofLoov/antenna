# 0036. iPhone as setup device for Apple TV: QR code and Handoff

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0006 (onboarding steps, add-source form, Connect, loading checklist, AC-21 sign-in on this Apple TV, AC-24 no duplicate on Connect), 0004 (storage of a source, AC-12 sync), 0013 and 0014 (what the loading step shows after the source arrives).
- ADR needed: a static host for the universal-link domain, serving `apple-app-site-association` and the no-app fallback page. The apps' copy says "Antenna has no servers"; the ADR decides the domain, who hosts it and that it serves two static files and logs nothing. The host is the single constant `SetupLink.host` in AntennaCore; criteria assert against it and the ADR fixes its value. Blocked on this ADR: the spec stays Draft until that ADR is Accepted.
- Not covered: the Xtream login reaching the Apple TV. iCloud Keychain does not sync to Apple TV, and ADR-0003 as accepted plus 0006's header make "entered and kept on this Apple TV" the tvOS credential path. This spec carries the source (name, server or playlist URL) and asks for the login once on the TV. Criteria for a credential arriving are listed under "Deferred to the credential spec" and belong to the spec that follows the ADR amending ADR-0003, which 0006 is blocked on.
- Handoff rule: if the device check (Open questions) finds that tvOS does not advertise the activity to a nearby iPhone, AC-7 and AC-18 move to a Dropped section with that reason before the status becomes Implemented, and the footer on TV-Onboard-3-QR loses the App Switcher sentence.
- Sync-event rule: if the implementing PR cannot observe `NSPersistentCloudKitContainer.eventChangedNotification` for SwiftData's container, AC-25 moves to Dropped and AC-26 is the only terminal state of the sending view.

## Design

Boards: `docs/design/boards/TV-Onboard-3-QR.dc.html` (tvOS, details step with the QR card), `TV-Onboard-3-QR-Timeout.dc.html`, `TV-Onboard-3-QR-SignIn.dc.html`; `TV-Onboard-3-QR-Received.dc.html` is drawn for the deferred credential criteria and no criterion here shows it; `iPhone-Onboard-2-FromTV.dc.html` (iOS; iPadOS and macOS centre the same sheet at 390 pt wide as 0006 does), `iPhone-Onboard-2-FromTV-Waiting.dc.html`, `iPhone-Onboard-2-FromTV-Sent.dc.html`, `iPhone-Onboard-2-FromTV-Timeout.dc.html`.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15. Deviations: DR-2, `onboarding.qr.code` is a white-filled 300 pt tile because a scanner needs a light quiet zone; it is not focusable, so it never competes with the focused element. DR-3, done markers use the accent as 0006's do. DR-12, the QR pattern on the boards is a layout placeholder, not a scannable code; the app renders the AC-3 URL. DR-12, the card footer names the iOS keyboard offer generically ("your iPhone offers its keyboard too"), as 0006's card does.
States on the boards:
- Waiting (TV-Onboard-3-QR): the 0006 details form on the left unchanged, `onboarding.qr` on the right with title "Set up from your iPhone" at 30 pt, the 300 pt tile, body copy at 22 pt `#D7DEE8`, `onboarding.qr.status` "Waiting for your iPhone" at 20 pt muted with the 12 pt accent dot, and a 20 pt muted footer that names Handoff and the remote. This card replaces 0006's "Easier to type on your iPhone" card when the Apple TV is signed in to iCloud; 0006's card stays for the not-signed-in case (AC-2).
- Nothing arrived after 120 s (TV-Onboard-3-QR-Timeout): `onboarding.qr.hint` at 22 pt muted under the status, AC-13.
- Source arrived (TV-Onboard-3-QR-SignIn): the tile at 40% opacity, status rows "<name> arrived from your iPhone" with a 28 pt accent check and "The login hasn't reached this Apple TV." in the error style with a 28 pt `#FF5F57` glyph; Name and Server prefilled and read-only, form title "Sign in on this Apple TV", subtitle "Server and name came from your iPhone.", `onboarding.qr.signInHere` as the focused 64 pt white button, AC-10 and AC-12a.
- Waiting for the login (TV-Onboard-3-QR-Received): the second status row "Waiting for the login…" with a 28 pt indeterminate ring, Username focused and empty. Deferred to the credential spec, together with a Keep waiting button beside Sign in; kept so that spec starts with a board.
- Form from TV (iPhone-Onboard-2-FromTV): nav "Cancel" and title "Set up Apple TV", `onboarding.fromTV.banner` at 15 pt with a 13 pt muted second line, then 0006's type picker, clipboard banner (its second line reads "Spaces around it are removed when you connect", AC-23), fields, lock note and Connect. No Guide toggle, as 0006 removed it.
- Sending (iPhone-Onboard-2-FromTV-Waiting): the form replaced by `onboarding.sending`, title "Sending to your Apple TV" at 22 pt, `onboarding.sending.row.saved` done, `onboarding.sending.row.tv` with a 26 pt ring and "Usually a few seconds", lock note, `onboarding.sending.continue` as a surface button, AC-24.
- Sent (iPhone-Onboard-2-FromTV-Sent): row.tv done reading "Handed to iCloud. Open Antenna on your Apple TV.", Continue as the white primary button, AC-25.
- Not sent after 30 s (iPhone-Onboard-2-FromTV-Timeout): row.tv title "Not sent yet" with the detail in the error style, Continue as the white primary button, AC-26.
Error style: 15 pt iOS, 22 pt tvOS, `#FF5F57`, as 0006. Step segments as 0006/AC-19a, step 3 current.
Copy: `<device>` in every string below is "iPhone", "iPad" or "Mac" for the platform the sheet runs on. The boards show the iPhone wording. "Signed in to iCloud" everywhere in this spec means the injected identity provider reports `CKContainer.accountStatus()` as `.available`; an Apple ID without iCloud Drive counts as not signed in.
Not drawn: `onboarding.fromTV.existing` (AC-22), one 13 pt muted line under the banner; `onboarding.fromTV.update` (AC-19b), one 13 pt muted line above the form of the plain sheet; the AC-14b hint, AC-13's hint with different text; the AC-27 not-signed-in variant of the Timeout board, same row with different text; the no-app web page (AC-31), which is not an app screen and has no board.

## Problem

Typing a server address, a username and a password with the Siri Remote takes minutes and goes wrong often; TiviMate users call setup "a pain in the neck" and report that a stray space after a pasted URL breaks login. The iPhone has a keyboard, a clipboard and the provider's email. Today the Apple TV only offers the continuity keyboard, which still means reading the login off another screen, and 0006's note that "sources added on iPhone appear here" asks the user to go find the app and the right sheet themselves. Until tvOS has a credential path, this spec removes the server and name typing for Xtream and all typing for M3U; the login is still entered once on the Apple TV.

## Scope

In:
- A QR card on the tvOS onboarding details step (0006 step 3) when the Apple TV is signed in to iCloud. The code holds a setup link with a random pairing token and nothing else.
- A Handoff activity advertised while the card is shown, so the iPhone's App Switcher offers Antenna without scanning.
- `SetupLink` and `PairingToken` in AntennaCore: building and parsing the link, generating the token.
- On iOS, iPadOS and macOS, the link or the activity opens the 0006 add-source sheet in a "from Apple TV" variant with a sending view after Connect.
- The Apple TV watches its store for the arriving `SourceRecord`, with progress, a nothing-arrived hint and, for Xtream, the sign-in offer that lands in 0006/AC-21's form with Name and Server filled.
- Trimming of pasted whitespace in the add-source form. The form is shared with 0006, so this holds there too.
- The fallback web page for an iPhone without Antenna, with the App Store link and nothing about content.
- Universal-link entitlement and the `apple-app-site-association` file.
- Accessibility identifiers with prefix `onboarding.`, new names listed in the test plan.

Out (explicitly):
- Carrying the credential to the Apple TV by any path other than the one ADR-0003 and its amendment define (the amendment ADR, then a follow-up spec). No credential or encrypted blob ever rides in the link, in CloudKit records or on the local network under this spec.
- A QR code on 0006/AC-21's sign-in step for a source that already synced without its login. Until the amendment ADR, the iPhone cannot help there; the later credential spec owns it.
- A QR code on the welcome step or in Sources and Settings after onboarding (Sources and Settings spec).
- Scanning a provider's own QR code into the form (0006 open question on provider message formats).
- Pairing two devices on different iCloud accounts. AC-13 and AC-25 tell the user both devices need the same account; nothing else is attempted.
- Apple Watch and Mac as the scanning device. Mac handles the link and Handoff like iPhone (AC-17, AC-18) but has no camera flow.
- The paywall (ADR-0006 follow-up spec). AC-21 only says what happens to a pending link while it is shown.
- Smart App Banner or web-to-app flows in Safari beyond the fallback page.

## User flow

tvOS:
1. Details step (0006 step 3). The form is on the left as before. On the right, "Set up from your iPhone" with a QR code, one sentence on what happens, "Waiting for your iPhone", and a footer that Antenna also appears in the iPhone's App Switcher and that the remote still works.
2. The user points the iPhone camera at the code (or opens Antenna from the App Switcher). Nothing changes on the TV yet.
3. The source arrives through iCloud. For M3U the loading step (0006 step 4) appears. For Xtream the card shows "<name> arrived from your iPhone", the form's Name and Server fill in and lock, and the card says the login has not reached this Apple TV and offers "Sign in on this Apple TV" (focused).
4. Sign in moves focus to Username; Connect verifies against the arrived server, saves the login under the arrived record and shows the loading step.
5. If nothing arrives for two minutes a hint names the three usual causes. The user can type on the TV at any time; Connect there works as 0006 says.

iOS, iPadOS, macOS:
1. The camera recognises the code and shows "Open in Antenna". Tapping it opens the app with the "Set up Apple TV" sheet over whatever is showing: the banner "Opened from your Apple TV", the type picker, the clipboard banner if a link is on the clipboard, the fields, the lock note, Connect. Handoff from the App Switcher opens the same sheet.
2. Without Antenna installed, the camera opens Safari on a page that says Antenna sets up the Apple TV from the iPhone and links to the App Store.
3. The user fills the form (Fill in from the clipboard per 0006/AC-17b or AC-17c, or by typing) and taps Connect. 0006's validation and errors apply.
4. Connect succeeds. The form is replaced by "Sending to your Apple TV" with two rows: "Saved on this iPhone" done and "Sending to your Apple TV…" in progress. When iCloud confirms the upload the row reads "Handed to iCloud. Open Antenna on your Apple TV." After 30 s without confirmation it reads "Not sent yet" with what to check. "Continue on iPhone" is always available and leads to 0006's ready sheet.
5. Not signed in to iCloud: the second row says so at once and tells the user to sign in.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 QR card on the details step
Given tvOS onboarding is on the details step (0006 step 3), the injected entitlement provider reports entitled and the injected identity provider reports signed in to iCloud
When the step appears
Then `onboarding.qr` exists at the trailing side of the form, `onboarding.qr.code` has the accessibility label "QR code. Scan it with your iPhone to set up this Apple TV from there.", `onboarding.qr.status` reads "Waiting for your iPhone", and `onboarding.keyboardCard` (0006's card, identifier required below) does not exist.

### AC-1b The code encodes the link
Given the pairing model with the identity provider reporting signed in
When the details step is entered
Then `setupLink` is non-nil and decoding the rendered code image with `CIDetector(ofType: CIDetectorTypeQRCode)` yields `setupLink.url.absoluteString`.

### AC-2 No QR card without iCloud
Given the identity provider reports not signed in to iCloud
When the details step appears
Then `onboarding.qr` does not exist, `onboarding.keyboardCard` exists, `setupLink` is nil and no `NSUserActivity` is current.

### AC-2b iCloud status changes while the step is shown
Given the details step with `onboarding.keyboardCard` shown because the status was `.couldNotDetermine`, `.temporarilyUnavailable`, `.restricted` or `.noAccount`
When the identity provider reports `.available` (it relays `CKAccountChanged`)
Then after the view updates `onboarding.qr` replaces `onboarding.keyboardCard` with a new token and AC-1 holds. Tested once per starting status.

### AC-2c iCloud signed out while the card is shown
Given the card is shown and no record has arrived
When the identity provider reports any status other than `.available`
Then after the view updates `onboarding.keyboardCard` replaces `onboarding.qr`, `setupLink` is nil, the activity is invalidated and polling stops.

### AC-3 Setup link format (core)
Given a `PairingToken`
When `SetupLink(token:).url` is built
Then it is `https://\(SetupLink.host)/setup?v=1&t=<token>` with scheme, host and path exactly so, the query items exactly `v` and `t` in that order, and `<token>` 22 characters from the base64url alphabet with no padding.

### AC-4 Setup link parsing (core)
Given a URL
When `SetupLink(url:)` is called
Then it returns a link with the same token for every URL AC-3 builds, including one with the query items in the other order or with an uppercase host. Checks run in this order and the first failure is thrown: host or path (`SetupLink.Error.notASetupLink`), then `v` (`.missingVersion` when absent, `.unsupportedVersion(String)` when not `1`), then `t` (`.missingToken` when absent, `.malformedToken` when not 22 base64url characters or when the last character has non-zero unused bits, so only the canonical encoding of 16 bytes parses).

### AC-4b Lenient parts of the link (core)
Given a URL AC-3 builds
When an unknown query item is added, the path gets a trailing slash, or `v` or `t` appears twice
Then the unknown item is ignored and the link parses with the same token; `/setup/` parses as `/setup`; a repeated `v` or `t` throws `.notASetupLink`.

### AC-5 Nothing but the token in the link and the activity
Given the details step with the card shown
When `setupLink.url` and the current `NSUserActivity` are inspected
Then the URL's query item names are exactly `["v", "t"]` and the activity's `userInfo` keys are exactly `["token"]` with the token string as value.

### AC-6a Token encoding and uniqueness (core)
Given `PairingToken(using:)` with an injected `RandomNumberGenerator`
When 16 bytes are drawn
Then the token is their base64url encoding without padding; and 10 000 tokens from `PairingToken()` (which uses `SystemRandomNumberGenerator`) are distinct.

### AC-6b New token per visit
Given the details step appeared, was left by Back and was entered again
When the two `setupLink` values are compared
Then the tokens differ and `setupLink` was nil in between.

### AC-7 Handoff activity
Given the card is shown
When the current `NSUserActivity` is inspected
Then its `activityType` is `se.codecrave.antenna.setup`, `title` is "Set up Antenna on Apple TV", `webpageURL` equals `setupLink.url`, `isEligibleForHandoff` is true, and `isEligibleForSearch`, `isEligibleForPrediction` and `isEligibleForPublicIndexing` are false.

The pairing model polls the model context every 2 s on the injected clock while the card is shown (the store poll). CloudKit imports do not notify the onboarding context, so the poll is the observation point for AC-8 to AC-14. On entry the model snapshots the `id`s already in the store; only records outside the snapshot count as arrived. The poll fetches with a predicate on `createdAt` at or after `shownAt` minus 300 s, so it never loads the whole store on the main actor, and reads `kindRaw`, not the `kind` accessor, because `kind` maps unknown raw values to `.m3u`. The token is not checked on the TV (no `SourceRecord` field holds it, Open questions): the TV accepts the first qualifying new record. Tests await the poll tick; "after that poll" means after the tick completes, with no wall-clock wait.

### AC-8 M3U source arrives
Given the card is shown at time `shownAt` on the injected clock
When the store poll finds a `SourceRecord` whose `id` was not in the snapshot, with `kindRaw` `m3u`, non-nil `url` and `createdAt` at or after `shownAt` minus 300 s
Then after that poll the loading step (0006 step 4) is shown for that record.

### AC-8b The TV inserts nothing on arrival
Given AC-8's or AC-10's arrival
When the store is read after that poll
Then it holds the same `SourceRecord`s as before the poll; the TV inserted none.

### AC-8c Arrival tears down the link
Given AC-8's arrival
When the loading step is shown
Then `setupLink` is nil, the activity is invalidated and polling stops.

### AC-8d Arrival while the app was suspended
Given the card is shown and the app is moved to the background or the Apple TV sleeps
When the app returns to the foreground with a qualifying record already in the store
Then a poll runs at once and AC-8 or AC-10 applies exactly as during the wait, the root chooser does not replace the details step (Required of other specs), and AC-13's 120 s are measured from `shownAt` on the injected clock, not from ticks counted.

### AC-10 Xtream source arrives
Given the card is shown
When the store poll finds a `SourceRecord` whose `id` was not in the snapshot, with `kindRaw` `xtream`, non-nil `url` and `createdAt` at or after `shownAt` minus 300 s
Then after that poll `onboarding.qr.status` lists "<name> arrived from your iPhone" done and "The login hasn't reached this Apple TV." in the error style, `onboarding.qr.hint` does not exist, and `onboarding.qr.signInHere` exists. Whether the record has a readable credential is not checked: under ADR-0003 none can arrive on tvOS.

### AC-10b Name and Server take the arrived values
Given AC-10's state
When `onboarding.field.name` and `onboarding.field.server` are read
Then they hold the record's `name` and `url.absoluteString`, and neither is focusable while the form holds that record.

### AC-10c Login fields keep their text
Given text in `onboarding.field.username` and `onboarding.field.password` before AC-10's poll
When the view has updated
Then both fields hold the same text.

### AC-10d Form title on arrival
Given AC-10's state
When the form header is read
Then the title reads "Sign in on this Apple TV" and the subtitle reads "Server and name came from your iPhone.".

### AC-12a Focus on arrival
Given AC-10's state
When the view has updated
Then focus stays in that field if it was in an `onboarding.field.*`, and a right press on the remote from any `onboarding.field.*` moves focus to `onboarding.qr.signInHere`.

### AC-12c Focus on arrival outside the fields
Given AC-10's poll runs while focus is not in an `onboarding.field.*`
When the view has updated
Then `onboarding.qr.signInHere` has focus.

### AC-12b Sign in on this Apple TV
Given AC-10's state
When the user selects `onboarding.qr.signInHere`
Then focus moves to `onboarding.field.username`, the button disappears, and a later Connect verifies against the arrived record's `url`, runs 0006/AC-7, AC-8, AC-23, AC-26, AC-29, AC-31 and AC-33, then writes the Keychain item under that record's `credentialKey` without inserting a `SourceRecord`, as 0006/AC-24, and shows the loading step.

### AC-12d Missing credential key
Given AC-12b's Connect succeeds for a record whose `credentialKey` is nil
When the Keychain item is written
Then `credentialKey` is set to `id.uuidString` first and saved. This is the only change the TV makes to an arrived record; the field is optional (ADR-0002) and the Keychain item stays on this Apple TV (ADR-0003).

### AC-13 Nothing arrives
Given the card is shown and no record has arrived
When 120 s pass on the injected clock
Then `onboarding.qr.hint` reads "Nothing yet? Your iPhone needs Antenna installed, an internet connection and the same iCloud account as this Apple TV." and the code and status are unchanged.

### AC-14 Unusable records are ignored
Given the card is shown
When the store poll finds a `SourceRecord` whose `id` was in the snapshot, or with `url` nil, or with `createdAt` earlier than `shownAt` minus 300 s, or with `kindRaw` `stalker`, or with a `kindRaw` that is not a `SourceKind` case
Then `onboarding.qr.status` still reads "Waiting for your iPhone" and nothing else changes.

### AC-14b A source arrived that the card cannot use
Given a record outside the snapshot, inside the 300 s window, with non-nil `url` and a `kindRaw` that is `stalker` or not a `SourceKind` case, was found by the poll
When AC-13's 120 s pass
Then `onboarding.qr.hint` reads "A source arrived from iCloud that this Apple TV can't set up here. Update Antenna, or type the source here." instead of AC-13's text.

### AC-15 Typing on the TV still wins
Given the card is shown and the user has filled the form
When Connect succeeds on the TV (0006/AC-9)
Then the loading step is shown, `setupLink` is nil and the activity is invalidated.

### AC-15b Import after Connect on the TV
Given AC-15's Connect has succeeded
When a record for the same `kind` and `url` is imported afterwards
Then it stays in the store and the card shows nothing; removing or merging it is the Sources spec's (ADR-0002 follow-up).

### AC-15c Record found while Connect runs
Given Connect is running on the TV (0006/AC-30)
When the poll finds a qualifying record
Then the record is held and nothing changes on screen; if Connect succeeds, AC-15b applies to it; if Connect fails, AC-8, AC-10 or AC-14 applies to it after 0006's error is shown.

### AC-16 Menu and Back
Given the card is shown, before or after a record arrived
When the user presses Menu
Then 0006 step 2 is shown with the entered values kept (0006/AC-5), `setupLink` is nil, the activity is invalidated and polling stops; returning to the details step starts over with a new token (AC-6b) and a new snapshot, so the first poll evaluates only records inserted after the step was re-entered.

### AC-16b Menu after an Xtream arrival
Given AC-10's state
When the user presses Menu and then enters the details step again
Then Name and Server hold what the user had typed before the arrival (empty if nothing), both are focusable again, the arrived record stays in the store and is in the new snapshot, and a Connect for the same server and username updates that record's login as 0006/AC-24 says instead of inserting a second record.

### AC-17 Link opens the sheet from Apple TV
Given the injected entitlement provider reports entitled, on iOS, iPadOS or macOS, on any screen including 0006's welcome step
When the app receives a URL that `SetupLink(url:)` parses, through `onOpenURL` or an `NSUserActivityTypeBrowsingWeb` activity
Then in the next view update after the router handles it, `onboarding.fromTV` is presented as a sheet with navigation title "Set up Apple TV", `onboarding.fromTV.banner` reading "Opened from your Apple TV" with the second line "Fill this in here. The source syncs to the Apple TV through iCloud.", and below it the 0006 add-source form (`onboarding.type.*`, the clipboard banner per 0006/AC-17a and AC-18, `onboarding.field.*`, the lock note, `onboarding.connect`) with Xtream selected.

### AC-18 Handoff opens the same sheet
Given AC-17's Given
When the app continues an `NSUserActivity` of type `se.codecrave.antenna.setup` whose `userInfo["token"]` is a valid token
Then AC-17's Then holds with that token as the sheet's `pairingToken`.

### AC-19 Link that does not parse
Given AC-17's Given
When the app receives a URL on `SetupLink.host` for which `SetupLink(url:)` throws
Then the 0006 add-source sheet is presented with title "Add a source", no `onboarding.fromTV.banner`, and `pairingToken` nil; no error is shown.

### AC-19b Link from a newer version
Given AC-17's Given
When `SetupLink(url:)` throws `.unsupportedVersion`
Then AC-19's sheet is shown with `onboarding.fromTV.update` reading "This code is from a newer Antenna. Update Antenna on this <device> to set up your Apple TV from here." in 13 pt muted above the form.

### AC-20 Same token twice
Given `onboarding.fromTV` is presented, or has reached AC-24's sending view, for token T in this launch
When another URL or activity carrying T arrives
Then no second sheet is presented and the existing sheet keeps its state and its field values. After AC-28 has run for T in this launch, a URL or activity carrying T presents nothing.

### AC-20b Another token while a sheet is up
Given any add-source sheet (0006's or `onboarding.fromTV`), the sending view, 0006's connecting state or a ready sheet is presented
When a URL or activity with a token other than the one shown arrives
Then the presented sheet keeps its state and field values, nothing new is presented, and the new token is dropped.

### AC-21 Link while the paywall is shown
Given the entitlement provider reports not entitled and the paywall is shown
When a URL that parses arrives, and later the provider reports entitled
Then nothing is presented over the paywall; in the next view update after the provider flips, AC-17's sheet is presented with the link's token; a link that arrived before a relaunch is not kept.

### AC-22 Sources already on this iPhone
Given the store holds n `SourceRecord`s with non-nil `url`, n at least 1
When `onboarding.fromTV` appears
Then `onboarding.fromTV.existing` reads "This <device> already has 1 source. It appears on the Apple TV on its own when both use the same iCloud account." for n of 1 and "This <device> already has <n> sources. They appear on the Apple TV on their own when both use the same iCloud account." otherwise, in 13 pt muted under the banner; for n of 0 it does not exist.

### AC-23 Pasted whitespace is trimmed
Given Server, Playlist URL, Guide URL or Username holds a value with leading or trailing characters from `CharacterSet.whitespacesAndNewlines` (which includes U+00A0), on any platform and whether the sheet came from a link or not; Name and Password are not trimmed (0004 stores a whitespace-only name as-is; a password may contain a real space, Open questions)
When the user activates Connect
Then each listed value is trimmed of those characters before 0006/AC-6 validation and the account or playlist request uses the trimmed values; interior characters are untouched.

### AC-23b Trimmed values are what is kept
Given AC-23's Connect succeeds
When the saved record, the Keychain item and the fields are read
Then they hold the trimmed values.

### AC-23c Empty after trimming
Given a required field from AC-23's list holds only those characters
When the user activates Connect
Then `onboarding.error` reads 0006/AC-31's "Enter the <field name>." and no request is made.

### AC-24 Connect success shows the sending view
Given `onboarding.fromTV` with a non-nil `pairingToken`
When Connect succeeds and 0006/AC-9 has saved the record (and Keychain item)
Then the form is replaced in the same sheet by `onboarding.sending` with `onboarding.sending.row.saved` done reading "Saved on this <device>" with the source name beneath, `onboarding.sending.row.tv` in progress reading "Sending to your Apple TV…" with "Usually a few seconds" beneath, `onboarding.sending.continue` enabled reading "Continue on <device>", no `onboarding.fromTV.cancel`, and interactive dismissal disabled on iOS and iPadOS; the 0006 loading of channels and guide for the record starts as 0006/AC-9 says.

### AC-24b The sending view cannot be dismissed on macOS
Given AC-24's state on macOS
When the user presses Escape or Command-period
Then the sending view stays, so the sheet leaves only through `onboarding.sending.continue`.

### AC-25 iCloud confirms the upload
Given AC-24's state and the injected `SyncEventSource`
When it reports a successful export that started at or after the save
Then `onboarding.sending.row.tv` turns done reading "Handed to iCloud. Open Antenna on your Apple TV." with no detail, and `onboarding.sending.continue` becomes the primary (white) button; a successful export that started before the save, or a failed one, changes nothing.

### AC-26 Upload not confirmed in time
Given AC-24's state and the identity provider reporting signed in to iCloud
When 30 s pass on the injected clock without AC-25's event
Then `onboarding.sending.row.tv` reads "Not sent yet" with the detail "Check that this <device> is online and signed in to iCloud. It sends on its own once it can." in the error style, the indeterminate indicator is gone, and `onboarding.sending.continue` is the primary button.

### AC-26b Late confirmation
Given AC-26's state
When the `SyncEventSource` then reports a qualifying export
Then AC-25's state is shown.

### AC-27 Not signed in to iCloud
Given the identity provider reports not signed in
When Connect succeeds in `onboarding.fromTV`
Then `onboarding.sending.row.tv` reads at once "Not sent yet" with the detail "This <device> isn't signed in to iCloud, so the source can't reach your Apple TV. Sign in to iCloud in Settings and it sends on its own." in the error style, and no 30 s timer runs.

### AC-28 Continue on iPhone
Given AC-24's, AC-25's, AC-26's or AC-27's state
When the user activates `onboarding.sending.continue`
Then 0006's ready sheet (0006/AC-14b, AC-19b) is shown for the saved record with its rows in whatever state the loading started at AC-24 has reached, and the token is remembered as completed (AC-20).

### AC-28b Ready sheet over the shell
Given the shell (not onboarding) was showing when `onboarding.fromTV` was presented
When the user activates Start watching on the ready sheet
Then the sheet is dismissed, the playing channel is unchanged, `onboarding.addAnother` is absent from that ready sheet, and the new source is loaded into Live through 0010's reload on source insert without a relaunch. Blocked until 0010 has that criterion (Required of other specs).

### AC-28c Ready sheet over the welcome step
Given `onboarding.fromTV` was presented over 0006's welcome step on a first launch
When the Connect of AC-24 saves the record, and later the user activates Start watching on the ready sheet
Then the welcome step stays under the sheet until Start watching, the sheet is then dismissed and the shell is shown with the new source loaded, and `onboarding.addAnother` is absent from that ready sheet.

### AC-29 Connect errors unchanged
Given `onboarding.fromTV`
When Connect fails per 0006/AC-6, AC-7, AC-8, AC-23, AC-26, AC-29, AC-31 or AC-33
Then `onboarding.error` renders that criterion's text under the form, nothing is saved, the banner stays and the sending view is not shown.

### AC-30 Cancel before Connect
Given `onboarding.fromTV` with values entered and nothing saved
When the user activates `onboarding.fromTV.cancel`, swipes the sheet down (iOS, iPadOS) or presses Escape (macOS)
Then no `SourceRecord` or Keychain item exists, the token is forgotten, and the same link arriving again presents a fresh sheet with empty fields.

### AC-31 iPhone without Antenna
Given an iPhone with no Antenna installed
When the camera opens the AC-3 URL
Then Safari shows the page served from `Web/setup/index.html` in the repo, whose `<body>` text content, with tags removed and whitespace collapsed, is exactly "Antenna sets up your Apple TV from your iPhone. Get Antenna on the App Store"; whose `<head>` contains only `<meta>` and `<title>` elements; which contains exactly one `<a href>` whose host is `apps.apple.com` (the listing URL is a placeholder until the listing exists); and which contains no `<script`, `<iframe`, `<img` or `<link` element anywhere (styling is inline, by design).

### AC-32 Universal link plumbing
Given the entitlement files, the Info.plists and the association file in the repo
When they are read
Then `Config/Antenna.entitlements`, used by the Antenna target on iOS and macOS, has `com.apple.developer.associated-domains` containing `applinks:\(SetupLink.host)`; `Apps/Mobile/Info.plist` has `NSUserActivityTypes` containing exactly `se.codecrave.antenna.setup` and `Apps/TV/Info.plist` does not list it; and `Web/.well-known/apple-app-site-association` lists under `applinks.details[0].appIDs` one app id matching `^[A-Z0-9]{10}\.se\.codecrave\.antenna$` (the team id is public by design and is committed) with one `components` entry `{ "/": "/setup" }` and nothing else. Whether `Config/AntennaTV.entitlements` needs the domain too for a Handoff activity with a `webpageURL` is a device check (Open questions); this criterion says nothing about that file.

### AC-33 Reduce Motion
Given Reduce Motion is on
When `onboarding.sending.row.tv` or a tvOS status row is in progress
Then no indeterminate ring is shown and the row shows the static text "In progress" in its place.

### AC-34 VoiceOver rows
Given VoiceOver is on
When the focus reaches `onboarding.sending.row.saved`, `onboarding.sending.row.tv` or a row of `onboarding.qr.status`
Then each row is one element whose label is its state, title and detail in that order, for example "Done. Saved on this iPhone. My Provider".

## Deferred to the credential spec

These describe the Xtream login arriving on the Apple TV. They cannot happen under ADR-0003 and move to the spec that follows the ADR amending it, with `TV-Onboard-3-QR-Received.dc.html` as their board.

- Xtream source arrives with its login: the loading step is shown at once, as AC-8 does for M3U.
- Login arrives later: while the card shows "Waiting for the login…", a credential becoming readable for the record's `credentialKey` shows the loading step with no Keychain write by the TV.
- Login timeout: 60 s without a credential shows the AC-10 sign-in state, with a Keep waiting button (`onboarding.qr.keepWaiting`) that returns to waiting and restarts the timer.

## Dropped

- AC-9 Xtream source arrives with its login. Under ADR-0003 no login reaches tvOS; moved to "Deferred to the credential spec".
- AC-11 Login arrives later, with its 60 s timeout and Keep waiting. Same reason; moved to "Deferred to the credential spec".

## Required of other specs

- 0006: the Design section's TV-Onboard-3 side card becomes the not-signed-in fallback and gets the identifier `onboarding.keyboardCard`; when signed in to iCloud, this spec's card is shown (AC-1, AC-2). The step-3 line in 0006's User flow should say so. AC-21's form gains the arrived-from-iPhone subtitle when reached through AC-10 here. 0006/AC-19b gains "Set up Apple TV" as the title of the from-TV variant (AC-17). 0006/AC-4a, AC-4b and AC-31 gain "after trimming per 0036/AC-23" in their implementing PR, because the form is one view.
- 0006, root chooser: while onboarding is on the details step with `onboarding.qr` shown, the root is not re-evaluated; `SetupPairingModel` owns the transition to the loading step (AC-8) or the sign-in form (AC-10, AC-12a). Without this, a record landing in the store flips 0006/AC-1's condition and the root chooser and the pairing model race. This also holds when the app resumes from the background with the card shown (AC-8d). Re-evaluation resumes when onboarding is dismissed. On iOS, iPadOS and macOS the root is not re-evaluated while `onboarding.fromTV`, its sending view or its ready sheet is presented; it is re-evaluated when the sheet is dismissed (AC-28c).
- Landing order: 0006's implementing PR lands first, with `onboarding.keyboardCard`, the root-chooser hold and the trimming rows above; this spec's PR follows. AC-28b waits for 0010's reload criterion.
- 0010: reload on source insert. 0004 and 0010 both leave "reload channels when sources change" out of scope, so without it a source added from the shell (AC-28b) would not appear in Live until relaunch. 0010 needs a criterion (its AC-18 is the nearest) that a `SourceRecord` inserted while the shell is shown is loaded without relaunch. Hard dependency for AC-28b.
- 0010 and 0015: the sheet of AC-17 is presented over the shell on iOS, iPadOS and macOS; the implementing PR touches the root chooser 0006 owns.
- Paywall spec (ADR-0006 follow-up): keep the pending link of AC-21 for the session.

## Edge cases and failure modes

- Offline Apple TV: the card is shown (iCloud sign-in state is local), nothing arrives, AC-13's hint appears after two minutes. Nothing names the network as the cause because the TV cannot tell it apart from a wrong account.
- Offline iPhone: Connect fails per 0006/AC-8 before anything is saved. Going offline after the save leads to AC-26.
- Slow or huge source: arrival detection reads one record; channel counts are 0006's loading step and 0013's problem.
- Two sources sent from the iPhone while the TV waits: the first arriving record takes the TV to the loading step; the second is handled as 0006/AC-16c would after onboarding, or by 0010 and 0015 at the next load.
- Record arrives while the user types on the TV: for M3U the loading step replaces the form (the source they wanted is there). For Xtream, Name and Server are replaced by the arrived record's values and locked; Username and Password keep their text (AC-10).
- The user scans the same code on two iPhones: both sheets work; the first record to arrive is the one the card shows, the second stays in the store and is the Sources spec's to remove or merge (ADR-0002 follow-up).
- A screenshot of the QR shared with someone else: the link carries only a random token (AC-5) and opens an empty form on their phone; whatever they add lands in their own iCloud, never the TV owner's.
- Different iCloud accounts on the two devices: nothing arrives and AC-13's hint names the same iCloud account as one of three causes. The TV cannot tell this case apart, so it says no more.
- First launch on the TV with CloudKit's initial import still running: older records from the account land during the wait; the snapshot misses them, but AC-8's 300 s window on `createdAt` keeps them from counting as arrived unless one was created in the last five minutes.
- Large source on the iPhone: AC-24 starts 0006's channel and guide load on the iPhone too, because the user may also watch there and the ready sheet of AC-28 reports it. Open questions.
- `Web/` is a new top-level directory holding the fallback page and the association file; the implementing PR adds it to CLAUDE.md's Layout.
- tvOS has no sending view; the sending criteria (AC-24 to AC-28) run on iOS, iPadOS and macOS only.
- Clock skew between devices: AC-8's 300 s window tolerates it. A record older than that is left for the normal sync path (0004/AC-12).
- `createdAt` is a defaulted stored property already on `SourceRecord`; no schema change (ADR-0002).
- Credential lookup on the TV: not done by this card (AC-10). 0004/AC-10's note on read errors applies when the loading step runs.
- Token, link URL and activity `userInfo` are never written to a log, to `UserDefaults` or to SwiftData, and `SetupLink` and `PairingToken` expose only the token (no initialiser or property takes a `SourceRecord`, `SourceDescriptor`, `Credential`, device name or iCloud identifier); the impl-reviewer checks both by reading the diff.
- Apple TV not entitled: the paywall (ADR-0006) comes before onboarding, so the card is never shown (AC-1's Given).
- Entitlement lapses on the iPhone while the sheet is up: the paywall replaces everything at the next root evaluation (ADR-0006); a saved record stays.
- tvOS runs as current user: the identity provider, store and Keychain are already per profile; nothing extra.
- VoiceOver on tvOS: `onboarding.qr.code` is an image with the AC-1 label (AC-1); rows per AC-34.
- Universal link opened in Safari on an iPhone that has the app (long-press, or a tap after the user chose "Open in Safari" once): the fallback page shows; its App Store link opens the installed app's listing. Out of scope to do better.

## Test plan

`SetupLink`, `PairingToken` and `SetupLink.Error` live in `Packages/AntennaCore/Sources/AntennaCore/Setup/`. The tvOS side is a `SetupPairingModel` (`@MainActor`) owned by 0006's onboarding model, taking an injected `ModelContext`, `CredentialStore`, identity provider (reporting `CKContainer.accountStatus()`), clock and an activity recorder (`NSUserActivity` wrapped behind a protocol so tests see type, title, userInfo and invalidation). The store poll ticks on the injected clock every 2 s. The iPhone side is a `SetupLinkRouter` taking the entitlement provider and a `SyncEventSource` protocol (`successfulExports: AsyncStream<DateInterval>`) implemented over `NSPersistentCloudKitContainer.eventChangedNotification`. Identifiers added by this spec: `onboarding.qr`, `onboarding.qr.code`, `onboarding.qr.status`, `onboarding.qr.hint`, `onboarding.qr.signInHere`, `onboarding.fromTV`, `onboarding.fromTV.banner`, `onboarding.fromTV.existing`, `onboarding.fromTV.cancel`, `onboarding.fromTV.update`, `onboarding.sending`, `onboarding.sending.row.saved`, `onboarding.sending.row.tv`, `onboarding.sending.continue`, and `onboarding.keyboardCard` (added to 0006's card). Everything else reuses 0006's identifiers.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (tvOS, injected identity) | TBD |
| AC-1b | integration (model, `CIDetector` on the rendered image) | TBD |
| AC-2 | ui (tvOS) + integration | TBD |
| AC-2b | integration (one case per starting status) + ui (tvOS) | TBD |
| AC-2c | integration (identity provider flips back) | TBD |
| AC-3 | core | TBD |
| AC-4 | core (parameterised per error, non-canonical last character) | TBD |
| AC-4b | core (extra item, trailing slash, repeated item) | TBD |
| AC-5 | integration (activity recorder, URL query items) | TBD |
| AC-6a | core (injected generator, 10 000 distinct) | TBD |
| AC-6b | integration (step leave and return) | TBD |
| AC-7 | integration (activity recorder) | TBD |
| AC-8 | integration (in-memory ModelContainer, record inserted by the test, injected clock drives the poll) | TBD |
| AC-8b | integration (store count before and after) | TBD |
| AC-8c | integration (activity recorder) | TBD |
| AC-8d | integration (scene phase driven by the test, clock advanced while backgrounded) | TBD |
| AC-10 | integration + ui (tvOS) | TBD |
| AC-10b | ui (tvOS, field values, fields not focusable) | TBD |
| AC-10c | ui (tvOS) | TBD |
| AC-10d | ui (tvOS) | TBD |
| AC-12a | ui (tvOS, XCUIRemote right press) | TBD |
| AC-12c | ui (tvOS) | TBD |
| AC-12b | ui (tvOS) + integration (Keychain write under existing key, request URL equals record url) | TBD |
| AC-12d | integration (record with nil key) | TBD |
| AC-13 | integration (injected clock) + ui (tvOS) | TBD |
| AC-14 | integration (five records) | TBD |
| AC-14b | integration (stalker and unknown kind, injected clock) | TBD |
| AC-15 | integration | TBD |
| AC-15b | integration (import after Connect) | TBD |
| AC-15c | integration (success and failure of the running Connect) | TBD |
| AC-16 | ui (tvOS) + integration | TBD |
| AC-16b | integration (Menu after arrival, Connect updates the record) | TBD |
| AC-17 | ui (iOS and macOS, launch argument carrying the URL) + integration (router) | TBD |
| AC-18 | integration (router, activity) + ui (iOS and macOS) | TBD |
| AC-19 | integration + ui (iOS) | TBD |
| AC-19b | integration (router, `v=2`) | TBD |
| AC-20 | integration (router, before and after AC-28) | TBD |
| AC-20b | integration (router, each presented state) | TBD |
| AC-21 | integration (injected entitlement provider) | TBD |
| AC-22 | ui (iOS, 0, 1 and 3 records) | TBD |
| AC-23 | integration (each field, each character class) | TBD |
| AC-23b | integration (record, Keychain item, field text) | TBD |
| AC-23c | integration | TBD |
| AC-24 | ui (iOS) + integration | TBD |
| AC-24b | ui (macOS) | TBD |
| AC-25 | integration (fake sync-event source: qualifying, early, failed) | TBD |
| AC-26 | integration (injected clock) + ui (iOS) | TBD |
| AC-26b | integration (fake sync-event source) | TBD |
| AC-27 | integration (identity provider) | TBD |
| AC-28 | ui (iOS) | TBD |
| AC-28b | ui (iOS, fake engine) + integration (reload recorded on fake sources) | TBD |
| AC-28c | ui (iOS, empty store at launch) | TBD |
| AC-29 | integration (one error per cited criterion) + ui (one) | TBD |
| AC-30 | ui (iOS) + integration | TBD |
| AC-31 | integration (reads `Web/setup/index.html`) + device (camera to Safari) | TBD |
| AC-32 | integration (reads `Config/Antenna.entitlements`, `Apps/Mobile/Info.plist` and `Web/.well-known/apple-app-site-association`) | TBD |
| AC-33 | ui (iOS and tvOS, Reduce Motion launch argument) | TBD |
| AC-34 | ui (iOS and tvOS, accessibility labels) | TBD |

End-to-end arrival over real CloudKit and the real Handoff banner on an iPhone cannot run in CI (ADR-0002); they are on the device smoke list of the implementing PR, together with a check that tvOS advertises the activity at all, whether the TV target needs the associated domain for it, and that the association file is served over HTTPS with no redirect and as `application/json` (Open questions).

## Open questions

- Domain. `antenna.codecrave.se` is the assumed value of `SetupLink.host`, from the bundle id prefix. The ADR picks the real one and the host. The page and the association file are static, so a GitHub Pages or CDN bucket works; "Antenna has no servers" in the app copy stays true in spirit but the ADR should say so.
- Handoff from Apple TV. `NSUserActivity` exists on tvOS and the API accepts `isEligibleForHandoff`, but Apple's Handoff support page lists iPhone, iPad, Mac and Apple Watch only. If an Apple TV 4K on tvOS 26 never shows the activity on a nearby iPhone, AC-7 and AC-18 are dropped and the card's footer loses the App Switcher sentence. The implementing PR checks this on a device first.
- Export confirmation. AC-25 relies on `NSPersistentCloudKitContainer.eventChangedNotification` being posted for SwiftData's container; the header's sync-event rule says what happens if it is not. Export events do not name records, so AC-25 treats any successful export that started after the save as confirmation; the row never claims more than "Sent.". A wrong "Sent." is possible when the export carried only another record.
- Keep waiting. With no credential path on tvOS the Keep waiting button has nothing to wait for, so it is deferred with the credential criteria. The owner may prefer to keep it as a "not now" that hides the offer.
- Token has no verifier. With no schema change, the TV accepts any new record (AC-8) and the token only ties the two sheets together on the iPhone (AC-20); in practice it is a setup session id, and a source added at the same time by someone else on the same iCloud account would count as arrived. A `setupToken` field on `SourceRecord` (optional, so ADR-0002 allows it) would let the TV match exactly, at the cost of a schema ADR. Left out for now; the owner decides whether that ADR comes before implementation.
- Where trimming lives. AC-23 to AC-23c change 0006's form; they stay here because 0006 is on its own PR branch and this spec should not edit it. They can move to 0006 once that spec is merged.
- Loading on the iPhone. AC-24 starts the full channel and guide load on the iPhone for a source meant for the TV. Deferring it to Continue would save data on huge sources; kept as 0006 does so the ready sheet has something to report.
- "Handed to iCloud" (AC-25). Chosen over "Sent." because the export event does not prove the TV has the record.
- Paywall link (AC-21). Asserted here because the router is this spec's; the paywall spec may take it over.
- Trimming the password. Left out of AC-23 because a password with a real trailing space would break. Xtream passwords are generated alphanumerics in every provider message seen and the research names a stray space after a pasted URL as the common failure, so Password may be added once the owner decides.
- Timeouts: 120 s for the hint (AC-13) and 30 s for the upload (AC-26) are guesses. Measure on devices.
- Should the QR card also appear on the type step (0006 step 2) so the user never has to pick a type on the TV? Left to the details step because that is where the typing pain is.
