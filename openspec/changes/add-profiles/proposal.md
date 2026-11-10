# Proposal

## Why

> As a family sharing one subscription, we want Dad, Mum and the kids each to keep our own favorites, history and hidden groups on the same channels, on the Apple TV and on our phones.

Most households have one IPTV subscription and several people watching it. Today everyone shares one Favorites list, one last channel and one set of hidden groups, so one person's sport channels crowd out another's cartoons.

Change `add-tvos-profiles` gave each Apple TV system user a separate Antenna instead. That only works on Apple TV, makes every person add the same sources and logins again, and does nothing on iPhone, iPad or Mac. This change replaces it with profiles inside Antenna that share the sources.

## What Changes

- Profiles inside Antenna, on every platform. Each has a name and a color, and every profile sees the same sources and logins.
- Each profile keeps its own favorites, hidden groups, watch progress, My list, recent searches and recently watched, plus, on each device, its last channel and its sound and subtitle picks per channel.
- With two or more profiles, a "Who's watching?" screen opens at launch. With one profile Antenna opens as it does today and shows no profile anywhere.
- Adding, renaming, recoloring and deleting profiles from that screen's Manage profiles. The last profile cannot be deleted. Up to 8 profiles.
- Switching profile from the Apple TV tab bar and from Settings on iPhone, iPad and Mac.
- Profiles sync through the user's iCloud. Which profile a device is on stays on that device.
- **BREAKING** for planned work: change `add-tvos-profiles` is withdrawn. Antenna does not opt in to Apple TV system users.

Out of scope:
- A PIN to leave a profile or to edit profiles, and anything that restricts what a profile can watch (a Kids mode, age ratings). Group locks stay with change `add-group-management`, which covers every profile.
- Pictures or avatars beyond a color and the initial.
- Different sources or logins per profile.
- Per-profile app settings such as the preferred languages or the stream quality.
- Moving data from before this change into a named profile. Antenna has not shipped; data from before is the first profile's.

## Capabilities

### New Capabilities
- `profiles`: profiles on one set of sources, the "Who's watching?" screen, managing and switching profiles, and what each profile keeps for itself.

### Modified Capabilities
- `favorites`: favorites belong to a profile and sync per profile.
- `tvos-shell`: the last channel on launch is the current profile's on this Apple TV, and the tab bar gains a profile button when there are two or more profiles.

## Impact

- New synced record for profiles and a profile id on favorite records (design.md). The changes that add their own per-person records, `add-group-management` (hidden groups), `add-watch-progress-sync` (progress, My list, recent searches) and `add-session-restore-and-recently-watched` (recently watched), keep them per profile; their design.md files say so.
- Per-device `UserDefaults` values `shell.lastChannel`, `recents.*` and `player.languages` are kept per profile.
- Withdraws change `add-tvos-profiles` and its board `TV-Onboard-1-OtherUser`. Change `add-top-shelf` depended on it and now depends on this change.
- Depends on: `favorites`, `source-management`, `channel-catalogue`, `tvos-shell`, change `add-tv-channel-overlay` (the Favorites group and favorite button), change `add-playback-engine` (language picks per channel).
- Not blocked on another change's decision. Profiles are managed from their own screen, so this change does not wait for `add-sources-and-settings`; it adds one Settings row.
