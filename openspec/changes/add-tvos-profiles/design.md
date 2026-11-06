# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Onboard-1-OtherUser.dc.html`, `TV-Onboard-1.dc.html`, `TV-Onboard-SignIn.dc.html`, `TV-Shell-Loading.dc.html`, `TV-Shell-Empty.dc.html`.

Design-system requirements that apply: "Focus is the lifted white card", "Text stays above the platform caption floor", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall".

Not drawn yet: the hint with the iCloud note absent (user not signed in to iCloud).

## Goals / Non-Goals

**Goals:**
- Per-user storage on Apple TV by opting in to the system's user management, with no Antenna-side profile model.

**Non-Goals:**
- A marker shared across users. Antenna cannot see other users' data, so the hint shows whenever there are several users.
- Moving data stored before this change.

## Decisions

- Entitlement `com.apple.developer.user-management` = [`runs-as-current-user-with-user-independent-keychain`] in `Config/AntennaTV.entitlements`, absent from `Config/Antenna.entitlements`. Apple documents this value for tvOS 16 and later. On tvOS 26 it behaves as `runs-as-current-user`. CI signs nothing.
- Never reference the deprecated `TVUserManager` members (`currentUserIdentifier`, its change notification, `userIdentifiersForCurrentProfile`, `presentProfilePreferencePanel`, `TVAppProfileDescriptor`) in `Apps/`.
- The hint reads `TVUserManager.shouldStorePreferencesForCurrentUser` each time the welcome screen appears, behind an injectable provider in `Apps/TV/Platform.swift`. Identifier `profiles.hint`, owned here though it sits on an onboarding board, a deviation from "Accessibility identifiers follow the board". Not focusable.
- `CredentialStore` queries carry `kSecAttrSynchronizable` true and never `kSecUseUserIndependentKeychain`. No log line carries a user identifier or name.
- Nothing is written on termination. The last channel is written at tune time and the session record on each change, so tvOS ending the process at a switch loses nothing.
- The `add-search` amendment applies only if it ships before `add-watch-progress-sync`. The `guide-data` amendment covers the double guide download.
- Board copy changes to "for this user only": `TV-Onboard-3.dc.html` and `TV-Onboard-SignIn.dc.html` ("Saved on this Apple TV, for this user only."), `TV-Onboard-5.dc.html` ("The login stays on this Apple TV, for this user only."), `TV-Onboard-Help.dc.html` (the Xtream paragraph ends "The login is saved on this Apple TV, for this user only.").
- Tests: a `UserSeparationProviding` protocol with a constant in tests; entitlement files read through `#filePath`; the Keychain check tests the query for the key name as a string so it compiles off tvOS. The implementing PR adds the tvOS unit and UI test bundles if the tvOS shell has not.
- Several requirements need two users on a device, which the simulator does not have. Those run as device tests.

## Risks / Trade-offs

- Open question: does the unlock follow the Apple TV user or the purchase account? Checked on a device before acceptance. If per user, a second user without Family Sharing sees the paywall.
- Open question: Antenna decides whether to show the hint from a tvOS setting that Apple says may be false when people share a device without separate users. If it turns out true on single-user Apple TVs too, the hint moves into the "What is a source?" help and the two hint requirements change. Checked on a device before acceptance.
- Open question: making the hint exact needs a marker shared across users and a decision on where it lives, and would change the hint requirement.
- Open question: nothing is shared, so a switch does not resume the same picture. A shared last channel would need the same shared marker and would change the per-person memory requirement.
- Open question: confirm "Switch user in Control Center" against the current tvOS wording. Can be decided at implementation.
- [Two users with the same source keep two copies of the guide on disk] → accepted; each waits for their own sources to load after a switch.
