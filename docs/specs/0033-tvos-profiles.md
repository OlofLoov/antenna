# 0033. tvOS profiles: each Apple TV user has their own Antenna

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0004, 0006
- Builds on specs: 0004, 0005, 0006, 0012, 0014, 0015, 0023, 0028, 0029
- Needs from other specs: 0015, 0028, 0012, 0014 and 0023 state that their on-device state is per user on tvOS; 0006 changes board copy to "for this user only" on `TV-Onboard-3`, `TV-Onboard-SignIn`, `TV-Onboard-5` and `TV-Onboard-Help`.
- Platforms: tvOS. AC-1a and AC-5a also check that iOS, iPadOS and macOS are unchanged.
- User stories: US-25

## Summary

For households where several people share one Apple TV, each with their own user in the Apple TV's settings. Once this ships, Antenna keeps each person's sources, logins, favorites, last channel, recent searches and progress separate, and switching user in Control Center switches Antenna along with it. There is no profile picker inside Antenna; the Apple TV's own user switching is the picker. Nothing is shared between users of one Apple TV, not even a source both people subscribe to.

## Design

Boards: `docs/design/boards/TV-Onboard-1-OtherUser.dc.html`, `docs/design/boards/TV-Onboard-1.dc.html`, `docs/design/boards/TV-Onboard-SignIn.dc.html`, `docs/design/boards/TV-Shell-Loading.dc.html`, `docs/design/boards/TV-Shell-Empty.dc.html`.
Design rules that apply: DR-2, DR-4, DR-11, DR-12, DR-13, DR-14.
Not drawn: the hint with the iCloud note absent (user not signed in to iCloud).

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

An Apple TV in a household often has several users, each with their own Apple Account, and tvOS switches between them from Control Center. Without opting in, Antenna would run as the Apple TV's default user: whoever added a source first would decide what everyone sees, one person's provider login would play for the whole household, and everyone's favorites would land in one list. Apple lets an app opt in so each user gets their own storage, passwords and iCloud, which makes a profile picker of Antenna's own unnecessary.

## Scope

In:
- Opting the Apple TV app in to running as whichever user is current. iPhone, iPad and Mac do not change.
- No profile picker and no profile settings inside Antenna.
- Everything Antenna stores on Apple TV belongs to the current user: sources, logins, favorites, settings, last channel, recently watched, recent searches, progress and the downloaded guide.
- Nothing is stored for the Apple TV as a whole.
- A hint on the first setup screen when the Apple TV has more than one user, so a new user knows why they see no sources.
- After a switch, the new user sees their own setup or their own channels; the previous user's state is intact when they come back.

Out (explicitly):
- Sharing a source or a login between users of one Apple TV.
- Telling one user that another user has sources.
- The paywall screen and purchase checks (0024).
- The screens of settings (0023), recently watched (0028) and synced activity (0029); they follow the per-user rule.
- The Top Shelf.
- Moving data stored before this change; Antenna has not shipped.
- iPhone, iPad and Mac, which are personal devices.

## User flow

1. A household has two users on the Apple TV. User A opens Antenna, adds a provider and watches.
2. User B switches user in Control Center. tvOS closes Antenna and opens it again as B.
3. B has no sources, so the welcome screen appears with the hint "Each user on this Apple TV has their own sources. Another user's are not shown here. Switch user in Control Center to use theirs." B adds their own source or switches back.
4. If B added a provider on their iPhone earlier, it arrives through B's iCloud without the password, because Apple TV does not receive synced passwords. B signs in once on this Apple TV, for B only.
5. A switches back. Antenna opens as A and A's last channel plays. A never saw B's source or sign-in, and B never saw A's.

## Acceptance criteria

### AC-1a Antenna runs as the person using the Apple TV
Given the Apple TV app and the iPhone, iPad and Mac app as built
When their system permissions are read
Then the Apple TV app is opted in to running as the current user, and the other apps are not.

### AC-2 No profile picker of Antenna's own
Given an Apple TV in any setup state: no sources, sources ready, or sources waiting for a password
When Antenna opens
Then the user lands on the same screen as without this spec (welcome, channels, or sign-in), and no profile chooser appears.

### AC-3 A hint when the Apple TV has several users
Given an Apple TV with more than one user, and a current user with no sources
When the welcome screen is shown
Then the hint "Each user on this Apple TV has their own sources. Another user's are not shown here. Switch user in Control Center to use theirs." is shown below the usual text.

### AC-4 No hint with one user
Given an Apple TV with one user and no sources
When the welcome screen is shown
Then there is no hint and the screen is the welcome screen of 0006.

### AC-5a The hint appears only on the welcome screen
Given the Apple TV has several users
When the user goes on to choose a source type, enter details, read help, or is asked to sign in to a synced source, or opens the welcome screen on iPhone, iPad or Mac
Then the hint is not shown.

### AC-8a Each person sees their own sources
Given users A and B on one Apple TV, A with a source, B with none
When A, mid-playback or not, switches to B, and later back
Then B sees the welcome screen with the hint, and A comes back to their own channels with their last channel playing and no setup step.

### AC-9a Each person signs in once on this Apple TV
Given B's iCloud holds a provider whose password is not on this Apple TV
When B opens Antenna
Then B is asked to sign in, sees channels after connecting, and is not asked again on later launches, while A's own sign-in is untouched.

### AC-10 Passwords are never stored for the whole Apple TV
Given user A signs in to a provider on this Apple TV
When user B opens Antenna on it
Then A's password is not available to B; it is stored only for A.

### AC-11 What Antenna remembers is per person
Given A and B have each used Antenna on the same Apple TV
When either opens Antenna
Then they see their own last channel, recently watched channels and recent searches.

### AC-16a Switching mid-setup leaves no half-added source
Given A is adding a source
When A switches to B and back, either after the source was saved or while Antenna was still connecting
Then a saved source is still there with its password and A goes straight to channels, and an unfinished one left nothing behind, so A starts at the welcome screen.

## Edge cases

- A user is added in the Apple TV's settings while Antenna is in the background: the hint is right the next time the welcome screen appears, without restarting Antenna.
- B adding the same source as A downloads the guide again rather than using A's copy.
- Offline after a switch: the new user's launch behaves as 0015 and 0006 describe; the hint needs no network.
- A large source: each user waits for their own sources to load after a switch.
- B's source arrives through iCloud while B's welcome screen is open: what happens is 0006's rule; this spec adds none.
- Two users with the same provider login each type it once.
- Two Apple TV users signed in to the same Apple Account: their sources, favorites, recent searches, progress and My list merge through iCloud; each still signs in once; last channel and recently watched stay separate.
- A user not signed in to iCloud: everything works on the device and nothing syncs; the hint stays in place.
- A guide download running at a switch stops and resumes the next time that user opens Antenna.
- Two users with the same source keep two copies of the guide on disk.
- VoiceOver reads the hint as one element before the iCloud note.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1a | integration |
| AC-2 | ui |
| AC-3 | ui + device (one-user and two-user Apple TV) |
| AC-4 | ui |
| AC-5a | ui |
| AC-8a | device (two users; the simulator has one) |
| AC-9a | device |
| AC-10 | integration |
| AC-11 | device |
| AC-16a | device |

## Open questions

- Does the unlock follow the Apple TV user or the purchase account? Checked on a device before acceptance; if per user, a second user without Family Sharing sees the paywall.
- Antenna decides whether to show the hint from a tvOS setting that Apple says may be false when people share a device without separate users. If it turns out true on single-user Apple TVs too, the hint moves into the "What is a source?" help and AC-3 and AC-4 change. Checked on a device before acceptance.
- The hint shows whenever there are several users, whether or not anyone else has sources, because Antenna cannot see other users' data. Making it exact needs a marker shared across users and an ADR; that would change AC-3.
- Nothing is shared, so a switch does not resume the same picture. A shared last channel would need the same shared marker and would change AC-11.
- Confirm "Switch user in Control Center" against the current tvOS wording. Can be decided in the plan.

## Notes for the plan

- Entitlement `com.apple.developer.user-management` = [`runs-as-current-user-with-user-independent-keychain`] in `Config/AntennaTV.entitlements`, absent from `Config/Antenna.entitlements`. Apple documents this value for tvOS 16 and later; on tvOS 26 it behaves as `runs-as-current-user`. The App ID `se.codecrave.antenna.tv` needs User Management enabled in the developer account before the first device build; CI signs nothing.
- Never reference the deprecated `TVUserManager` members (`currentUserIdentifier`, its change notification, `userIdentifiersForCurrentProfile`, `presentProfilePreferencePanel`, `TVAppProfileDescriptor`) in `Apps/`.
- The hint reads `TVUserManager.shouldStorePreferencesForCurrentUser` each time the welcome screen appears, behind an injectable provider in `Apps/TV/Platform.swift`. Identifier `profiles.hint`, owned here though it sits on an onboarding board (DR-11 deviation); not focusable.
- `CredentialStore` queries carry `kSecAttrSynchronizable` true and never `kSecUseUserIndependentKeychain` (ADR-0003). No log line carries a user identifier or name.
- Nothing is written on termination: the last channel is written at tune time and the 0028 session on each change, so tvOS ending the process at a switch loses nothing.
- 0012's amendment applies only if it ships before 0029. 0014's amendment adds the double guide download to its edge cases.
- 0006 lists `TV-Onboard-1-OtherUser.dc.html` as a welcome state owned here, and board copy changes to "for this user only": `TV-Onboard-3.dc.html` and `TV-Onboard-SignIn.dc.html` ("Saved on this Apple TV, for this user only."), `TV-Onboard-5.dc.html` ("The login stays on this Apple TV, for this user only."), `TV-Onboard-Help.dc.html` (the Xtream paragraph ends "The login is saved on this Apple TV, for this user only.").
- Tests: a `UserSeparationProviding` protocol with a constant in tests; entitlement files read through `#filePath`; the Keychain check tests the query for the key name as a string so it compiles off tvOS. The implementing PR adds the tvOS unit and UI test bundles if 0015 has not.

## Dropped

- Split earlier (kept for history): AC-5 into AC-5a and AC-5b, because an empty store cannot reach the sign-in step; AC-9 into AC-9a and AC-9b, because it held four assertions over two users.
- Dropped earlier: AC-8b repeated AC-11; AC-15 ("no termination hook") described code, not behavior; AC-17 (whether the purchase follows the user) belongs to the paywall spec and is now an open question.
- Merged into AC-1a: AC-1b.
- Merged into AC-3: AC-7.
- Moved to Edge cases: AC-3b, AC-13.
- Merged into AC-5a: AC-5b, AC-6.
- Merged into AC-8a: AC-14.
- Merged into AC-9a: AC-9b.
- Merged into AC-11: AC-12.
- Merged into AC-16a: AC-16b.
