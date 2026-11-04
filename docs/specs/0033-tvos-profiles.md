# 0033. tvOS profiles: runs as current user

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0004, 0006
- Platforms: tvOS. iOS, iPadOS and macOS appear only in AC-1b and AC-6, which say what must not happen there.
- Builds on specs 0006 (root chooser, welcome step, AC-21 sign-in step, AC-34 initial focus, AC-35 iCloud note), 0015 (shell launch, last channel in `UserDefaults`), 0028 (session restore and recently watched channels, `RecentsStore` over `UserDefaults`), 0012 and 0029 (recent searches, first in `UserDefaults`, then as a synced `RecentSearchRecord`), 0014 (per-device guide timestamp and cache), 0004 and 0005 (synced records). Sets the rule the planned settings spec (0023) inherits: on tvOS nothing Antenna stores is shared between users of one Apple TV.
- No ADR needed. No new record or store. ADR-0002 already lists "works per tvOS profile with runs-as-current-user" as a consequence; this spec turns it into criteria. The one alternative that would need an ADR is under Open questions.

## Design

Boards: `docs/design/boards/TV-Onboard-1-OtherUser.dc.html` (tvOS welcome step with the several-users hint, `profiles.hint`). Every other screen is one of 0006's or 0015's boards, unchanged: `TV-Onboard-1.dc.html` is the welcome step without the hint (AC-4), `TV-Onboard-SignIn.dc.html` is the per-user sign-in step (AC-9a), `TV-Shell-Loading.dc.html` and `TV-Shell-Empty.dc.html` (0015) are what a user sees right after a switch while their sources load.
Design rules that apply: DR-2, DR-4, DR-11, DR-12, DR-13, DR-14. Deviation: DR-11, the hint sits on an `onboarding.` board but carries `profiles.hint`, because this spec owns it and 0006's identifier list stays as it is.
States on the board: the hint, one line at 22 pt in `#A7B0BF` with a 24 pt two-person glyph, centred, 104 pt from the bottom, above 0006's iCloud note (`onboarding.icloudNote`) at 56 pt; not focusable; initial focus is 0006/AC-34's.
Not drawn: the hint with the iCloud note absent (0006/AC-35, not signed in): same line, same position, the note gone. To be drawn before the implementing PR.

## Problem

An Apple TV in a household has several users, each with their own Apple Account, and tvOS switches between them from Control Center. Without the User Management entitlement Antenna would run as the Apple TV's Default User, so whoever added a source first would decide what everyone sees, one person's Xtream login would play for the whole household, and favorites and My list from different people would land in one list. With the entitlement tvOS gives each user their own container, Keychain and iCloud, and Antenna needs no profile picker of its own.

## Scope

In:
- The tvOS target declares `com.apple.developer.user-management` with the value `runs-as-current-user-with-user-independent-keychain`. tvOS 26 is the floor (ADR-0004), so this is the value Apple documents for tvOS 16 and later; it behaves as `runs-as-current-user`.
- Required outside the repo: User Management (Runs as Current User) enabled on the `se.codecrave.antenna.tv` App ID in the developer account before the first device build. CI builds with `CODE_SIGNING_ALLOWED=NO`, so a device install that fails with an entitlement mismatch is this, not AC-1a.
- No in-app profile picker and no profile model. tvOS is the picker. The deprecated `TVUserManager` members (`currentUserIdentifier`, `currentUserIdentifierDidChangeNotification`, `userIdentifiersForCurrentProfile`, `presentProfilePreferencePanel`, `TVAppProfileDescriptor`) are never referenced in `Apps/`; the impl-reviewer greps for them.
- Per user, because the system separates them: every store Antenna opens lives in the current user's container, whichever spec owns it. That is the ADR-0002 container (`SourceRecord`, `FavoriteRecord`, the 0029 records, the 0023 settings record), the Keychain of ADR-0003, `UserDefaults` (0015 last channel, 0028 recents and session, 0012 recents until 0029 lands), the 0014 guide timestamp and cache, and the StoreKit entitlement cache of ADR-0006.
- Per device, shared between users: nothing. `CredentialStore` never uses the user-independent Keychain.
- The welcome step of 0006 gains a hint on tvOS when the Apple TV has more than one user, read from `TVUserManager.shouldStorePreferencesForCurrentUser` each time the welcome step appears, including a return from the background.
- What a user sees after a switch: tvOS ends the process and relaunches Antenna as the new user; the new user's own 0006 or 0015 state appears; the previous user's state is intact when they switch back. Nothing is written on termination: the last channel is written at tune time (0015/AC-8) and the 0028 session state before each handler returns (0028/AC-10), so Antenna has no termination hook of its own.
- Accessibility identifier prefix `profiles.`; the only element is `profiles.hint`.

Out (explicitly):
- Sharing a source or a login between users of one Apple TV. Would need the user-independent Keychain for the credential and a non-iCloud store for the source; a later "shared sources" spec, if ever.
- A marker that tells one user that another user has sources. Open question; needs an ADR because it stores a non-secret in the Keychain.
- The paywall screen and entitlement checks (ADR-0006 follow-up spec). Whether the unlock follows the tvOS user is under Edge cases; the paywall spec owns the criterion.
- Settings content (0023), recently watched channels and session restore (0028), synced recents (0029). They follow the per-user rule; their specs own the screens.
- Top Shelf extension (0015 out; it also runs as the current user when it exists).
- Moving data stored before the entitlement existed. Antenna has not shipped, so no Default User data exists.
- iOS, iPadOS and macOS behaviour. Those devices are personal and unchanged.

## User flow

1. A household has two users on the Apple TV, set up in Settings, Users and Accounts. User A opens Antenna, passes the paywall (DR-14), adds an Xtream source in 0006 and watches.
2. User B holds the TV button, opens Control Center and switches user. tvOS shows its switching screen, ends Antenna's process and relaunches it as B.
3. B has no sources: the welcome step appears with the hint "Each user on this Apple TV has their own sources. Another user's are not shown here. Switch user in Control Center to use theirs." under the usual copy. B adds their own source or switches back.
4. B added an Xtream source on their iPhone earlier. It arrives through B's iCloud without its login (Keychain items do not sync to tvOS, 0006 header). B sees "Sign in on this Apple TV" (0006/AC-21) and enters the login once. It is saved for B only.
5. A switches back. Antenna relaunches as A and A's last channel plays (0015/AC-2a). A never saw B's source or sign-in, and B never saw A's.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1a Entitlement on the tvOS target
Given `Config/AntennaTV.entitlements`
When it is read as a property list
Then the key `com.apple.developer.user-management` holds an array with exactly one string, `runs-as-current-user-with-user-independent-keychain`.

### AC-1b No entitlement on the other targets
Given `Config/Antenna.entitlements`
When it is read as a property list
Then the key `com.apple.developer.user-management` is absent.

### AC-2 No profile picker
Given tvOS, an entitled provider, and a store state from the test plan's matrix
When the app reaches its root view
Then the root is the view 0006/AC-1, AC-2 or AC-21 names for that store state, and the view hierarchy contains no element with a `profiles.` identifier other than `profiles.hint`.

### AC-3 Hint when the Apple TV has more than one user
Given tvOS, an entitled provider, a store with no `SourceRecord` whose `url` is non-nil, and the injected user-separation provider reporting true
When the welcome step is shown
Then `profiles.hint` exists and reads "Each user on this Apple TV has their own sources. Another user's are not shown here. Switch user in Control Center to use theirs."; pressing down from `onboarding.help` leaves focus on `onboarding.help`.

### AC-4 No hint on a single-user Apple TV
Given the state of AC-3 with the provider reporting false
When the welcome step is shown
Then `profiles.hint` does not exist and the step matches 0006/AC-1.

### AC-3b Hint follows the provider on return
Given AC-3 with the injected provider reporting false and `profiles.hint` absent
When the provider flips to true and the app returns from the background to the welcome step
Then `profiles.hint` exists.

### AC-5a Hint only on the welcome step
Given the state of AC-3
When the user moves to the type step, the details step, or the help screen (0006/AC-25)
Then `profiles.hint` does not exist.

### AC-5b No hint on the sign-in step
Given tvOS, the provider reporting true, and every `SourceRecord` Xtream with no readable Keychain item
When the root is 0006/AC-21
Then `profiles.hint` does not exist.

### AC-6 No hint on iOS, iPadOS or macOS
Given the welcome sheet on iOS, iPadOS or macOS with an empty store
When it is shown
Then `profiles.hint` does not exist.

### AC-7 Hint gate on a real Apple TV
Given a tvOS build with the AC-1a entitlement on an Apple TV with one configured user (test a) and with two (test b), the current user having no source
When Antenna launches to the welcome step
Then `profiles.hint` is absent in a and present in b.

### AC-8a Sources belong to the user
Given an Apple TV with users A and B, A with one loaded source, B with no source and no iCloud data
When B becomes the current user and Antenna launches
Then B sees `onboarding.welcome` with `profiles.hint`; switching back shows A's shell with A's last channel (0015/AC-2a) and no onboarding step.

### AC-9a Sign in on this Apple TV is per user
Given B's iCloud holds an Xtream `SourceRecord` with no Keychain item on this Apple TV
When B becomes the current user and Antenna launches
Then 0006/AC-21 is shown; after Connect the shell shows, and on B's next launch the shell shows without a sign-in step.

### AC-9b B's sign-in does not touch A
Given AC-9a completed and A has a readable credential for A's own source
When A becomes the current user
Then A's shell shows without a sign-in step.

### AC-10 Credentials never use the shared Keychain
Given `CredentialStore`
When the query for `save`, `load` or `delete` is built for any key
Then it contains `kSecAttrSynchronizable` true and does not contain `kSecUseUserIndependentKeychain`.

### AC-11 Last channel is per user
Given A tuned to channel X and B tuned to channel Y on the same Apple TV
When A becomes the current user and Antenna launches
Then channel X plays per 0015/AC-2a; B's return plays Y.

### AC-12 Recent searches are per user
Given A searched for "sport" and B has never searched
When B opens Search with an empty field
Then no `search.recent.<n>` exists (0012/AC-11); A's entry is listed again when A returns.

### AC-13 Guide cache is per user
Given A's guide for source S completed within the last 12 hours and B adds the same source S
When B's loading step runs
Then `onboarding.row.guide` goes through "Downloading the guide" (0006/AC-12a); the download is not skipped because of A's copy.

### AC-14 Switch mid-playback
Given A is watching channel X full screen
When A switches to B and back
Then B's launch is 0006/AC-1, 0006/AC-21 or 0015/AC-2a or AC-2b over B's own store, and A's launch plays X per 0015/AC-2a.

### AC-16a Switch during the loading step keeps the source
Given A is on 0006's loading step with a `SourceRecord` saved
When A switches to B and back
Then A's launch does not show onboarding and A's `SourceRecord` and Keychain item exist (0006/AC-20).

### AC-16b Switch during Connect saves nothing
Given A activated Connect with 0006/AC-30's delayed-stub launch argument so the request is still running
When A switches to B and back
Then A's launch shows the welcome step and no `SourceRecord` and no Keychain item exist for A.

## Dropped

- AC-5 (hint only on the welcome step): its Given, an empty store, cannot reach the 0006/AC-21 step. Split into AC-5a and AC-5b.
- AC-8b (A's state survives B's session): the same observation as AC-11 and AC-8a's second clause.
- AC-9 (sign in per user): four assertions over two users; split into AC-9a and AC-9b, with "written while running as B" replaced by the observable "survives B's next launch".
- AC-15 (switching back resumes A without extra saving): "no termination hook" is code shape, not behaviour. The reasoning is in Scope; the observation is AC-14.
- AC-17 (the unlock is per Apple Account): the paywall spec does not exist and Apple's entitlement page names the data container, iCloud and Keychain, not StoreKit. Moved to Edge cases; the paywall spec owns the criterion.

## Edge cases and failure modes

- The unlock is checked in the current user's process. Whether `Transaction.currentEntitlements` follows the tvOS user or the Apple TV's Media and Purchases account is verified on device before the paywall spec cites this one. If it follows the user, a second user without the unlock or Family Sharing sees the paywall (DR-14).
- Offline after a switch: the new user's launch follows 0015/AC-10 and AC-11 or 0006/AC-8; the hint needs no network.
- Huge source: the new user's launch repeats 0015's loading state for their own sources; the 10 second deadline of 0015/AC-2b applies per launch.
- Sync lag: B's `SourceRecord` can arrive while B's welcome step is on screen. The root chooser is 0006's; this spec adds no rule to dismiss welcome when a record arrives (0006 open question).
- Credential not yet synced: on tvOS the Keychain never syncs (0006 header), so every user signs in once per Apple TV. Two users with the same provider login both type it; the provider counts connections per login (0006/AC-11), which does not change because one Apple TV plays one stream.
- Two tvOS users signed in to the same Apple Account: two containers syncing one CloudKit database. Sources and favorites merge through CloudKit; each user still signs in to Xtream once (AC-9a); last channel and recents stay separate.
- Current user not signed in to iCloud: the store works locally and nothing syncs (0004 edge case); `onboarding.icloudNote` is absent (0006/AC-35) and the hint keeps its position (Design, Not drawn).
- A user added in Settings while Antenna is suspended: the gate is re-read when the welcome step appears, including on return from the background, so the hint is correct the next time the step is on screen without a cold launch (AC-3b).
- A build without the AC-1a entitlement is not a supported configuration; AC-1a is the guard. The provider's value in such a build is undefined and untested.
- Guide download in progress at a switch: the process ends; 0014/AC-14 resumes the download at that user's next launch.
- Disk: 0014's cache is held once per user. Two users with the same source hold two copies.
- Malformed data: none introduced; the provider value is a `Bool`.
- Focus and remote: the hint is static text; the focus order of 0006's welcome step is unchanged (0006/AC-34).
- VoiceOver: the hint is read as one element, before the iCloud note, in layout order.
- Logs: no log line carries a user identifier or user name (ADR-0003 spirit; the identifier API is deprecated and unused, Scope).
- The impl-reviewer checks the Scope member list and AC-10's key by reading `Apps/` and `Config/`.

## Required of other specs

- 0015, Scope: "Last watched channel is per device, in `UserDefaults`" becomes "per device and, on tvOS, per user (0033)". No criterion changes.
- 0028, header: "Recents and the restored session are per device in `UserDefaults`" becomes "per device and, on tvOS, per user (0033)".
- 0012, Scope, if it ships before 0029: "Recent searches, local to the device" becomes "local to the device and, on tvOS, to the user (0033)". 0029 needs no change; its synced records are per user through each user's iCloud.
- 0014, header and AC-13: the per-device timestamp and cache are per user on tvOS; add the double-download consequence to its edge cases.
- 0006, Design: list `TV-Onboard-1-OtherUser.dc.html` as a state of the welcome step owned by 0033. Copy on four boards changes so it matches AC-9a: `TV-Onboard-3.dc.html` and `TV-Onboard-SignIn.dc.html`, "Saved in the Keychain on this Apple TV." becomes "Saved on this Apple TV, for this user only."; `TV-Onboard-5.dc.html`, "The login stays on this Apple TV." becomes "The login stays on this Apple TV, for this user only."; `TV-Onboard-Help.dc.html`, the Xtream paragraph ends "The login is saved on this Apple TV, for this user only."
- 0023, when written: state that settings are per user on tvOS and cite this spec.

## Test plan

The user-separation value sits behind a protocol `UserSeparationProviding` with one property, `separatesUsers: Bool`; the production type wraps `TVUserManager` under `#if os(tvOS)` in `Apps/TV/Platform.swift`, tests inject a constant. AC-1a and AC-1b read the entitlements files from the repository through `#filePath`. AC-2's matrix is three store states (empty; sources with readable credentials; Xtream sources without credentials) times the provider true and false, six launches. AC-10 needs `CredentialStore.baseQuery(key:)` made `internal` for `@testable import`; it runs in the AntennaTV test bundle and checks the query for the key name string `kSecUseUserIndependentKeychain`, so the test compiles without the tvOS-only constant. `project.yml` has no test target yet: the implementing PR adds an `AntennaTVTests` unit bundle and an `AntennaTVUITests` bundle if 0015 has not already, and `scripts/check-specs.sh` requires the citations to live under `Apps/`. AC-3b uses a mutable injected provider and `XCUIDevice` to background and foreground the app. Everything that involves two users is `device`: the tvOS simulator has one user, so those criteria are a manual two-user check on an Apple TV 4K with the fake-engine launch arguments of 0015 where they help. Identifiers: `profiles.hint`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1a | integration (plist read) | TBD |
| AC-1b | integration (plist read) | TBD |
| AC-2 | ui (tvOS, six-launch matrix) | TBD |
| AC-3 | ui (tvOS, injected provider) | TBD |
| AC-3b | ui (tvOS, mutable injected provider, background and return) | TBD |
| AC-4 | ui (tvOS, injected provider) | TBD |
| AC-5a | ui (tvOS, per step) | TBD |
| AC-5b | ui (tvOS, fake credential store) | TBD |
| AC-6 | ui (iOS and macOS) | TBD |
| AC-7 | device (one user, then two) | manual |
| AC-8a | device | manual two-user check |
| AC-9a | device | manual two-user check |
| AC-9b | device | manual two-user check |
| AC-10 | integration (`@testable`, tvOS test bundle) | TBD |
| AC-11 | device | manual two-user check |
| AC-12 | device | manual two-user check |
| AC-13 | device | manual two-user check |
| AC-14 | device | manual two-user check |
| AC-16a | device | manual two-user check |
| AC-16b | device (delayed stub) | manual two-user check |

## Open questions

- Entitlement value. This spec picks `runs-as-current-user-with-user-independent-keychain` because Apple's entitlement page says to use it instead of `runs-as-current-user` for tvOS 16 and later. On tvOS 26 the two behave the same. Overturn if the owner prefers the older value for familiarity.
- Hint gate. The spec assumes `shouldStorePreferencesForCurrentUser` is false when the Apple TV has one user and true when it has several, from Apple's sentence "This property might be false if people share a device, but don't configure multiple users on that device." AC-7 verifies it on device before acceptance. If it is true on single-user devices as well, drop the gate and move the sentence into "What is a source?" (0006/AC-25).
- Hint accuracy. The hint shows whenever the Apple TV has several users, whether or not another user has sources, because the current user's process cannot see another user's container. A marker in the user-independent Keychain ("someone on this Apple TV has a source") would make it exact; it needs an ADR because it puts a non-secret in the Keychain, and 0006 would carry the criterion.
- Nothing shared. Last channel, recents and the guide cache are per user. The alternative, one shared last channel so the TV resumes the same picture after a switch, has no shared store to live in short of the Keychain marker above.
- Second user without the unlock. If the StoreKit entitlement follows the tvOS user, B sees the paywall unless Family Sharing covers them, and the store listing (ADR-0006 follow-up) should say that Family Sharing is on.
- Copy. "Switch user in Control Center" is the tvOS path (hold the TV button). Confirm against the current tvOS wording before the implementing PR.
