# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Onboard-SignIn-QR.dc.html` (waiting), `TV-Onboard-SignIn-QR-Failed.dc.html` (a delivered login did not work), `iPhone-SignIn-FromTV.dc.html` (the sheet before Send), `iPhone-SignIn-FromTV-Sent.dc.html` (picked up), all new in this change, and `TV-Onboard-3-QR-Received.dc.html`, drawn by `add-iphone-as-setup-device` for this change. `TV-Onboard-SignIn.dc.html` stays as the version for a TV not signed in to iCloud.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step", "Undrawn states are listed and drawn before implementation".

Not drawn yet: the TV card while it checks a delivered login, the TV card for a delivery it cannot read, the QR card in a source's details in Settings, the iPhone sheet while entering a missing login, while sending, not picked up, offline, not signed in to iCloud, code already used, and none of the sources on this device, and the third row on the setup sending screen. Task 1.2 draws them before the screens are built.

Today a login reaches an Apple TV only by typing it there. `CredentialStore` writes generic password items with `kSecAttrSynchronizable` true under service `se.codecrave.antenna.sources`; on tvOS such an item stays on the device because tvOS has no iCloud Keychain. Sign-in on the TV, in onboarding and in Settings, checks the login with `SourceConnector.probe` and writes it under the record's `credentialKey`, setting the key to the record id when it is nil. This change keeps all of that and adds a second way for the login to get to the place where the TV writes it.

## Goals / Non-Goals

**Goals:**
- A login reaches the TV readable only by the TV that showed the code, and only for ten minutes.
- No new path for a secret to land in SwiftData, logs, UserDefaults, identifiers or the link.
- The user confirms on the sending device what leaves it.

**Non-Goals:**
- A permanent copy of logins for Apple TV in iCloud.
- Pairing devices on different iCloud accounts.
- Changing how the TV checks and stores a login once it has one.

## Decision: how the login reaches the TV

Options considered:

1. **Sealed delivery through the user's private CloudKit database (chosen).** The TV makes a one-time key pair for each code and puts the public key in the QR code. The sending device seals the logins to that key with HPKE and saves the sealed box as one record in a zone of the user's private CloudKit database. The TV fetches the record by name, opens it with the private key it holds in memory, deletes it and forgets the key.
   - The public key travels only in the QR code and in Handoff, which runs only between the user's own devices, so the receiver is the TV the user is looking at, and only the TV holding the private key can open the box. Apple, CloudKit and the user's other devices see ciphertext.
   - The record lives in the scanning device's own iCloud account. A code shown by a TV on another account, including a hostile one, can never collect a delivery, because that TV cannot read the scanner's private database.
   - The key never leaves the TV's memory and is dropped after ten minutes, so a copy of the record kept somewhere is useless after that.
   - It works when the iPhone is on cellular or a guest Wi-Fi with client isolation, and needs no Local Network permission prompt.
   - It costs a CloudKit round trip and polling, a few seconds, and needs both devices signed in to the same iCloud account, which the source sync already needs.
   - It breaks the rule that a secret never travels outside the Keychain. See "Rule change" below.
2. **Local network with Network framework and Bonjour.** The TV advertises a service; the iPhone finds it from the code and sends the logins sealed to the same one-time key. Fast and no iCloud. Rejected: the iPhone shows the Local Network permission prompt in the middle of setup, client-isolated and guest networks block it, and a hostile TV on the same network that shows a code would receive whatever the user sends, since nothing ties the receiver to the user's account. It would also need the "never over the local network" rule relaxed.
3. **DeviceDiscoveryUI.** tvOS's own picker connects a tvOS app to its iOS app with an Apple-managed encrypted connection. Rejected for now: no QR code, the TV starts the pairing rather than the phone, Mac is not supported, it needs an app extension on iOS, and it is still the local network. Worth another look if the QR flow proves slow.
4. **Keep logins in SwiftData with CloudKit encryption.** Every device, the TV included, would read them from the synced store. Rejected here: it stores every login for good outside the Keychain and is the broader decision first-run onboarding names. This change does not need it.
5. **Sign in with Apple.** Cannot work. The logins belong to IPTV providers and media servers, not to the user's Apple ID.
6. **A web page served by the TV.** Rejected: it needs a local HTTP server in the TV app, which risks App Review, the login would pass through a browser on the phone, and it is the local network again.

### Rule change

The hard constraint today: "Secrets live only in the synchronizable iCloud Keychain, never in SwiftData, logs, identifiers or labels." `add-iphone-as-setup-device` adds "No password travels in the link, in iCloud records or over the local network."

The owner approved the exception on 2026-11-12, worded narrowly: "Secrets live only in the synchronizable iCloud Keychain, never in SwiftData, logs, identifiers or labels. The one exception is a login drop for an Apple TV: sealed with HPKE to a key that exists only in that Apple TV's memory, it may sit in the user's private CloudKit database for at most ten minutes, in the record's encrypted values, and is deleted when the TV picks it up." The local-network part stays as it is. Task 2.1 put this wording in `openspec/config.yaml` and CLAUDE.md.

## Decision: a new kind of synced record

The delivery is a CloudKit record written with the CloudKit API, not SwiftData, so no model and no schema migration.

- Container `iCloud.se.codecrave.antenna`, private database, zone `LoginDrops`, record type `LoginDrop`. SwiftData's mirroring zone is not touched.
- Record name `drop-<token>`, where `<token>` is the 22-character code from the link.
- Fields, all in `encryptedValues`: `enc` (the HPKE encapsulated key, `Data`), `box` (the sealed payload, `Data`), `v` (`Int64`, 1). No other fields. `creationDate` is the server's.
- The sender creates the zone if it is missing and saves with `CKModifyRecordsOperation` and `savePolicy = .ifServerRecordUnchanged` on a new record, so a second save for the same token fails with `serverRecordChanged`, which the sheet shows as "already used".
- Every device sweeps the zone on launch and on returning to the foreground: it fetches the zone and deletes `LoginDrop` records whose `creationDate` is more than 600 seconds ago. The sending sheet deletes its own record when it reaches 600 seconds with the sheet still open.
- The TV fetches `drop-<token>` by id every 3 seconds while the card shows, backing off by the `retryAfterSeconds` CloudKit returns on `requestRateLimited` or `zoneBusy`. A missing zone or record is "nothing yet". No subscription and no push.

## Cryptography

AntennaCore imports Foundation only, so sealing lives in the app and AntennaCore holds the formats.

- `Apps/Shared/Setup/LoginSeal.swift`: HPKE base mode, ciphersuite `HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly` from CryptoKit. `info` is the UTF-8 bytes of `se.codecrave.antenna.login.v1`. The authenticated data is the token's 22 ASCII bytes, so a box cannot be moved to another record name.
- `LoginReceiverKey` wraps `Curve25519.KeyAgreement.PrivateKey`. It is created when a code is shown, held only by the TV's model, never written to the Keychain, disk or logs, and released when the code is replaced or the card goes away.
- The public key travels as its 32-byte raw representation in base64url without padding, 43 characters.
- `Packages/AntennaCore/Sources/AntennaCore/Setup/LoginPayload.swift`: the sealed JSON, `{"v":1,"logins":[{"source":"<uuid>","username":"…","password":"…","login":"…"}]}`, with `login` present only for a Stalker portal that has one. `description` and `debugDescription` print counts only. Decoding rejects an unknown `v`, which the TV shows as a delivery it cannot read.
- Per kind: Xtream sends username and password; Stalker sends the MAC address in `username`, and the portal login and password when present, matching the Keychain item; Jellyfin sends username and password, never the device's access token; Channels DVR sends its proxy username and password, and a server without a `credentialKey` is never asked for.

## Link format

`SetupLink` from `add-iphone-as-setup-device` gains version 2.

- Setup card: `https://<host>/setup?v=2&t=<token>&k=<key>`.
- Sign-in card: `https://<host>/setup?v=2&t=<token>&k=<key>&s=<id>,<id>,…`, one to eight source ids, each the record UUID's 16 bytes in base64url without padding, 22 characters, in the TV's sign-in order.
- Parsing keeps the v1 checks and order and adds: for `v=2`, `k` missing is `.missingKey` and not 43 canonical base64url characters is `.malformedKey`; `s` with an empty, malformed or repeated id, or more than eight, is `.malformedSources`. `v=1` stays readable so a TV running the earlier build still works with a newer iPhone. An older iPhone reading `v=2` already shows "This code is from a newer Antenna", which is the right message.
- The URL is at most about 300 characters with eight ids, which is QR version 13 at error correction M, about 3.8 points per module in the 260-point area of the 300-point tile.
- Handoff keeps activity type `se.codecrave.antenna.setup` and sets `webpageURL` to the link; `userInfo` for a v2 offer is exactly `["link": <the link as a string>]`. The receiving device parses the link from there.
- No new path on the web host and no change to the association file or the fallback page.

## Board states and copy

`<device>` is "iPhone", "iPad" or "Mac". `<name>` is the source's name.

Apple TV, sign-in step and source details (signed in to iCloud):

- Waiting (`TV-Onboard-SignIn-QR`): the sign-in form on the left as `TV-Onboard-SignIn`. On the right `signIn.qr`, title "Send the login from your iPhone" at 30 pt, the white 300 pt tile `signIn.qr.code`, body at 22 pt `#D7DEE8` "Scan the code with your iPhone camera. Antenna there sends the login to this Apple TV, encrypted, through iCloud.", `signIn.qr.status` "Waiting for your iPhone" at 20 pt with a 12 pt accent dot, and a 20 pt muted footer "Prefer the remote? Type here; your iPhone offers its keyboard too."
- In onboarding with more than one source to sign in, the status reads "Waiting for your iPhone · <n> logins" and the form's muted line "<n> more source(s) to sign in after this one" stays. The code asks for the first eight in `sortOrder`; a new code asks for the rest once those are done.
- Checking, not drawn: the tile at 40% opacity, status "Login received. Checking with <name>…" with a 28 pt ring, one row per source in a multi-source delivery.
- A login that did not work (`TV-Onboard-SignIn-QR-Failed`): the form shows that source with empty fields and `onboarding.error` reading "The login from your iPhone didn't work here. <sentence>", where `<sentence>` is the sign-in's message for the failure, for example "Could not sign in. Check the username and password.". A new code shows in the card, status "Waiting for your iPhone".
- A delivery it cannot read, not drawn: `signIn.qr.status` in the error style "Something arrived from your iPhone that this Apple TV can't read." and `signIn.qr.hint` "Update Antenna on both, or type the login here." A new code shows.
- Nothing after 120 s: `signIn.qr.hint` "Nothing yet? Your iPhone needs Antenna installed, an internet connection and the same iCloud account as this Apple TV."
- After ten minutes the code and key are replaced silently; the status and hint stay.
- `signIn.qr.code` accessibility label: "QR code. Scan it with your iPhone to send the login to this Apple TV." Not focusable. When a delivery arrives, VoiceOver announces "Login received from your iPhone".
- Settings details: the same card to the right of the details' sign-in fields, asking for that one source. Not drawn.

Apple TV, setup card from `add-iphone-as-setup-device`:

- `TV-Onboard-3-QR-Received`: after a login source arrives, the second status row reads "Waiting for the login…" with a 28 pt ring. When the login arrives, "Checking the login…", then loading as onboarding's Connect. After 60 s without it the row turns into `TV-Onboard-3-QR-SignIn`'s "The login hasn't reached this Apple TV." and `onboarding.qr.signInHere` appears, while the TV keeps listening until the code's ten minutes end.
- A login that arrives before its source is held in memory until the source arrives or the code ends.

iPhone, iPad and Mac (iPad and Mac center the sheet at 390 pt):

- Sheet (`iPhone-SignIn-FromTV`): nav "Cancel", title "Sign in Apple TV". Heading "Sign in your Apple TV" at 22 pt, body at 15 pt "Your Apple TV asked for these logins. They're encrypted for that Apple TV only and go through your iCloud." Then `sendLogins.list`, one `sendLogins.row` per requested source this device has: name at 16 pt, type beneath at 13 pt muted, and on the right "Ready to send" with an accent check, or "Not on this <device>" with an `sendLogins.enter` button "Enter". Below, `sendLogins.missing` at 13 pt muted when some requested sources are absent: "1 source the Apple TV asked for isn't on this <device> yet. New sources can take a minute to arrive through iCloud." or "<n> sources …". Lock note "Logins stay in your iCloud Keychain on this <device>." `sendLogins.send` "Send to Apple TV" as the white primary button, disabled while no row is ready.
- Enter, not drawn: a sheet titled with the source name and the fields of the source's details for its kind, Cancel and Check. Check runs `SourceConnector.probe`, then writes the Keychain item as Settings does, and the row becomes "Ready to send". A failure shows the details' message under the fields.
- Sending, not drawn: `sendLogins.status` "Sending to your Apple TV…" with a 26 pt ring, rows read-only, Send hidden, no Cancel.
- Picked up (`iPhone-SignIn-FromTV-Sent`): status with an accent check "Your Apple TV picked up the logins." with "It checks them with the provider and signs in." beneath, and `sendLogins.done` "Done" as the primary button.
- Not picked up after 60 s, not drawn: status in the error style "Not picked up yet" with "Keep the sign-in open on the Apple TV. If the code there changed, scan the new one." A later pickup still turns it into Picked up. Done closes the sheet and leaves the delivery for the TV until its ten minutes end.
- Offline, not drawn: "Couldn't send. Check that this <device> is online, then try again." with `sendLogins.retry` "Try again".
- Not signed in to iCloud, not drawn: "This <device> isn't signed in to iCloud, so it can't send logins to your Apple TV. Sign in to iCloud in Settings, then scan the code again." Send disabled.
- iCloud storage full (`quotaExceeded`), not drawn: "Couldn't send because your iCloud storage is full."
- Already used, not drawn: "This code was already used. If the Apple TV still needs a login, it shows a new code."
- None of the sources here, not drawn: the list is replaced by "None of the sources this Apple TV asked for are on this <device>. Both need the same iCloud account, and new sources can take a minute to arrive." and only Done.
- Setup sending screen from `add-iphone-as-setup-device`, not drawn: a third row `onboarding.sending.row.login` for a login source, "Sending the login…", then "Your Apple TV picked up the login." or after 60 s "Login not picked up yet" with "You can also sign in on the Apple TV." Playlist sources have no third row. The login goes without asking, since the user typed it on this screen for that TV.
- Error style 15 pt on iOS and 22 pt on tvOS in `#FF5F57`. Done markers use the accent.

Both platforms: with Reduce Motion a status in progress reads "In progress" in place of the ring. With VoiceOver each row is one element read as state, name, detail, for example "Ready to send. Home provider. Xtream".

## Identifiers

New: `signIn.qr`, `signIn.qr.code`, `signIn.qr.status`, `signIn.qr.hint`, `sendLogins`, `sendLogins.cancel`, `sendLogins.list`, `sendLogins.row`, `sendLogins.enter`, `sendLogins.missing`, `sendLogins.send`, `sendLogins.status`, `sendLogins.retry`, `sendLogins.done`, `onboarding.sending.row.login`. Rows are told apart by their position in UI tests.

## Code layout

- AntennaCore `Setup/`: `SetupLink` v2 parsing and building, `LoginPayload`, and `LoginRequestPlan` (which sources a code asks for: no credential on this device, a kind with a login, Channels DVR only with a `credentialKey`, first eight in `sortOrder`).
- `Apps/Shared/Setup/`: `LoginSeal`, `LoginReceiverKey`, `LoginDropping` (protocol: `save(_:token:)`, `fetch(token:)`, `delete(token:)`, `sweep(olderThan:)`) with `CloudKitLoginDrops` and an in-memory fake for tests and previews.
- TV: `LoginReceiverModel`, `@MainActor`, owned by onboarding's sign-in model and by the source details model, taking the drop store, `CredentialStore`, the connector, the identity provider and a clock. It replaces the key and token every 600 s, polls every 3 s, and stops on leaving, on iCloud sign-out and once every requested source is signed in.
- iPhone, iPad and Mac: `SendLoginsModel` and `SendLoginsScreen` under `Apps/Shared/Views/Setup/`, opened by `SetupLinkRouter` for a v2 link with `s`. The setup sending screen gains a step that seals and saves the new source's login when the link had `k`.
- Nothing logs the token, key, link, payload or record name. `LoginPayload`, `LoginReceiverKey` and the drop types print redacted descriptions.

## Testing

On a simulator or in `swift test`:
- Link v1 and v2 parsing and every error, the payload encoding and its redacted description, and which sources a code asks for: AntennaCore tests.
- Seal and open round trip, a box opened with the wrong key or the wrong token failing, and a box for an unknown payload version: app unit tests on the iOS and tvOS simulators, since CryptoKit HPKE runs there.
- The TV's model against the fake drop store: pickup, a failed login, ten-minute replacement, two senders, sign-out, a login before its source.
- UI tests open the sheet with `xcrun simctl openurl` or a launch argument holding a v2 link, and the TV's sign-in with a fake drop store that delivers on a timer. They cover Send, Enter, the missing-source line, Picked up, Not picked up, offline and focus on the TV.
- Previews use the fake drop store and fixed keys.

Only on devices:
- Scanning the code with the iPhone camera and the universal link opening Antenna.
- CloudKit between two real devices on one account: save, fetch by id, delete, the sweep, rate limits, and the time from Send to pickup.
- The QR code's legibility from a couch at version 13.
- Handoff from the TV to an iPad or Mac.
Task 7.2 is a manual checklist for these, recorded in this file.

## Risks / Trade-offs

- [Ciphertext of a login sits in iCloud for up to ten minutes] → sealed to a key only one TV has in memory, deleted on pickup, swept after ten minutes. The owner approved the rule change on 2026-11-12.
- [Polling CloudKit every 3 seconds for up to ten minutes is about 200 requests] → only while the card is on screen, with backoff on rate limits. Measure on devices.
- [The sending device cannot tell a wrong-account TV from a slow one] → the sheet compares the requested ids with its own sources and says when it has none.
- [The 60-second "not picked up" and the 120-second TV hint are guesses] → measure on devices.
- Settled 2026-11-12: the TV does not ask before keeping a delivered login. It checks each login with the server and keeps what works, since only the user's own devices can write to their private database.
- Settled 2026-11-12: Send needs no Face ID. Keychain items here are readable after first unlock without it, and the sheet already lists what leaves the device before Send.
- The `iphone-as-setup-device` delta modifies requirements that exist only in that change. `openspec validate` passes, and archive works only after `add-iphone-as-setup-device` is archived.

## Implementation decisions

Owner decisions, 2026-11-12:

1. The sealed login may sit in the user's private CloudKit database for up to ten minutes. This is an approved exception to "secrets live only in the Keychain", and `openspec/config.yaml` and CLAUDE.md now say so in the narrow wording under "Rule change": HPKE-sealed login drops only, private database only, deleted on pickup, ten-minute expiry.
2. The `LoginDrops` zone outside SwiftData is approved. The sealed payload goes in `CKRecord.encryptedValues`, so CloudKit also encrypts it with the user's account keys on top of the HPKE seal.
3. No extra confirmation step: no "keep this login?" prompt on the TV and no Face ID before Send. Both open questions under "Risks / Trade-offs" are closed.

Made while building:

- `SetupKey` in AntennaCore holds the public key as text and bytes and reads only the canonical 43-character form, the same rule `PairingToken` follows. The two share one base64url reader, so a key or code with nonzero spare bits is rejected rather than read two ways.
- `SetupLink(token:key:sources:)` writes version 1 without a key and version 2 with one, and drops sources when there is no key. A version 1 link ignores `k` and `s`, so an older TV's link reads as before. A Handoff user info with both `link` and `token` reads the link first.
- Channels DVR servers with a proxy login count as login arrivals on the setup card. `SetupArrivals.Candidate` gained `hasCredentialKey`, and a server whose record names a Keychain item waits for its login like an Xtream source. Without a key it still loads at once.
- `LoginPayload` keeps the version under the JSON key `v` but names the Swift property `version`, since the lint rules refuse one-letter names.
- The undrawn states from "Board states and copy" are drawn as new boards copied from the drawn ones, each changing only the status area: `TV-Onboard-SignIn-QR-Checking`, `TV-Onboard-SignIn-QR-Unreadable`, `TV-Settings-SignIn-QR`, `iPhone-SignIn-FromTV-Sending`, `iPhone-SignIn-FromTV-NotPickedUp`, `iPhone-SignIn-FromTV-Offline`, `iPhone-SignIn-FromTV-NotSignedIn`, `iPhone-SignIn-FromTV-Used`, `iPhone-SignIn-FromTV-None`, `iPhone-SignIn-FromTV-Enter` and `iPhone-Onboard-2-FromTV-Login`. "iCloud storage full" uses the Offline board with its own sentence. `TV-Onboard-3-QR-Received` already shows "Waiting for the login…" and its copy did not change.
- The container diagram names what crosses the CloudKit edge, so it now lists the sealed TV logins next to sources and favorites.
- The sweep reads the `LoginDrops` zone with `recordZoneChanges(inZoneWith:since: nil)` and deletes the `LoginDrop` records created more than ten minutes ago. A query would need an index on `creationDate` in the CloudKit schema; reading the zone needs none, and the zone holds a handful of records at most.
- `LoginDropSweep` runs the sweep each time the scene becomes active, which covers launch and the return to the foreground. It runs only when `ubiquityIdentityToken` is set, so a simulator build without iCloud never creates a `CKContainer`. UI tests sweep their in-memory store instead.
- `CloudKitLoginDrops` keeps its own copy of the container id: `CloudKitIdentity` is main-actor isolated through its protocol, and the drop store runs off the main actor.
- `LoginSealTests` runs in both `AntennaTests` and `AntennaTVTests`; `project.yml` adds the file to the tvOS test target, as it does for `TopShelfItems.swift`.
- Pickup empties the record rather than deleting it. The TV removes `enc` and `box` and keeps the empty `LoginDrop` record until the sweep, so a second iPhone that sends to the same code still gets `serverRecordChanged` and says the code was used. Deleting the record would let the second save succeed and wait forever for a TV that moved on. The secret is gone on pickup either way. The sending sheet reads an empty record as picked up.
- `LoginKeeper` holds the check-and-keep the Apple TV sign-in already did (probe, Keychain item under the credential key, the key set on a record without one). Typed sign-in, a delivered login, the setup card's login and the Settings card all go through it.
- `LoginReceiverModel` serves the sign-in step and the Settings card; `SetupPairingModel` keeps its own code for the setup card. The setup card's code is not replaced after ten minutes, since a source may be on its way under it; it stops listening for a login then. An unreadable delivery on the setup card is ignored and the TV falls back to "Sign in on this Apple TV" after the minute, because the setup card has no drawn state for it.
- A Channels DVR server with a proxy login joins the Apple TV sign-in (`SourceDescriptor.signsInOnAppleTV`), so onboarding's sign-in step and its code ask for it. The Settings card leaves it out: the details screen shows no login fields for Channels DVR today.
- The Settings card shows whenever the details of a login source without its login are open on a TV signed in to iCloud, beside the existing "Sign in on this Apple TV" button, rather than only after the button. A delivered login that does not work shows its sentence in the card's status line.
- When the setup card's minute runs out, "Sign in on this Apple TV" appears and takes focus, as it did on arrival before this change.
- The checking state on the sign-in step dims the code to 40% as the board draws; the waiting board's 40% tile reads as a drawing slip and the app shows the waiting code at full strength so it scans.
- UI tests: `-ui-testing-login-drops <mode>` puts one in-memory drop store under the run and stands in for the iPhone, `-ui-testing-signin-sources <n>` seeds sources without logins, and `UITESTING_LOGIN_WAIT_SECONDS` replaces the setup card's minute. Every other UI test run gets a receiver that reports no iCloud account, so no unsigned build reaches CloudKit. The scripted onboarding server answers `xtream.test` with an active account.
- `SetupInbox` routes a version 2 link with source ids to "Sign in your Apple TV" and one without to "Set up Apple TV"; the sheet modifier picks the screen. This stands in for the `SetupLinkRouter` named under "Code layout", as `add-iphone-as-setup-device` already decided for its own sheet. Send marks the code used for the rest of the launch.
- `LoginDelivery` seals and saves, then asks every 2 seconds whether the record is still waiting. An empty record or a missing one counts as picked up. Both the sheet and the setup sending screen use it, so the minute, the ten-minute delete and the error states behave the same in both.
- "Not signed in to iCloud" shows after Send rather than when the sheet opens: the iCloud check is part of sending. Send then stays disabled, as the board draws. A requested source of a kind without a login counts as "not on this device".
- Enter uses `LoginKeeper` on the iPhone too, so an entered login is checked and kept in the iCloud Keychain under the source's credential key, as Settings would. Its sheet shows the details' sentence for a refused login.
- The setup sending screen's third row says "Login not sent" with "You can also sign in on the Apple TV." when the save fails outright, a state the board does not draw.
- UI tests on iPhone reuse `-ui-testing-signin-sources 3` and `-ui-testing-login-drops <mode>`: `pickup` has a stand-in TV take each delivery after a second, `offline`, `quota` and `used` fail the save, `signedOut` reports no iCloud account, and `UITESTING_PICKUP_WAIT_SECONDS` replaces the minute. Home provider's login sits in an in-memory Keychain for the run.
