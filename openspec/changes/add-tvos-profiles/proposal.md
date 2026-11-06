# Proposal

## Why

> As a family sharing one Apple TV, I want each person's favorites, history and progress kept separate.

An Apple TV in a household often has several users, each with their own Apple Account, and tvOS switches between them from Control Center. Without opting in, Antenna runs as the Apple TV's default user. Whoever added a source first decides what everyone sees, one person's provider login plays for the whole household, and everyone's favorites land in one list. Apple lets an app opt in so each user gets their own storage, passwords and iCloud, which makes a profile picker of Antenna's own unnecessary.

Not reviewed yet.

## What Changes

- The Apple TV app opts in to running as whichever user is current. iPhone, iPad and Mac do not change.
- No profile picker and no profile settings inside Antenna. The Apple TV's own user switching is the picker.
- Everything Antenna stores on Apple TV belongs to the current user: sources, logins, favorites, settings, last channel, recently watched, recent searches, progress and the downloaded guide. Nothing is stored for the Apple TV as a whole.
- A hint on the first setup screen when the Apple TV has more than one user, so a new user knows why they see no sources.
- After a switch, the new user sees their own setup or their own channels, and the previous user's state is intact when they come back.

Out of scope:
- Sharing a source or a login between users of one Apple TV.
- Telling one user that another user has sources.
- The paywall screen and purchase checks.
- The screens of settings, recently watched and synced activity, which follow the per-user rule.
- The Top Shelf.
- Moving data stored before this change. Antenna has not shipped.
- iPhone, iPad and Mac, which are personal devices.

## Capabilities

### New Capabilities
- `tvos-profiles`: each Apple TV user has their own Antenna, with a hint on the welcome screen when the Apple TV has several users.

### Modified Capabilities
- `tvos-shell`: on-device state such as the last channel belongs to the current Apple TV user.
- `guide-data`: the downloaded guide on Apple TV belongs to the current user, so two users with the same source each download it.

## Impact

- Platforms: tvOS. iOS, iPadOS and macOS are checked to be unchanged.
- Depends on: `source-management`, `favorites`, `guide-data`, `tvos-shell`, and the changes `add-first-run-onboarding`, `add-search`, `add-sources-and-settings`, `add-session-restore-and-recently-watched`, `add-watch-progress-sync`.
- Needs from other changes: `add-session-restore-and-recently-watched`, `add-search` and `add-sources-and-settings` state that their on-device state is per user on tvOS. The `add-search` amendment applies only if it ships before `add-watch-progress-sync`.
- Needs from `add-first-run-onboarding`: board copy changes to "for this user only" on `TV-Onboard-3`, `TV-Onboard-SignIn`, `TV-Onboard-5` and `TV-Onboard-Help`, and it lists `TV-Onboard-1-OtherUser` as a welcome state owned here.
- The App ID `se.codecrave.antenna.tv` needs User Management enabled in the developer account before the first device build.
