# Proposal

## Why

A provider playlist arrives with hundreds of groups the user never watches, names they would not choose, adult channels next to the kids' ones, and an order the provider picked. Users of TiviMate, the closest competitor, name hiding, locking, renaming and reordering groups among the reasons they stay, and merging several playlists into one guide is the feature they praise most. Antenna shows every provider group as it arrives and remembers no change to that list.

User stories served:
- "As a user with several subscriptions, I want them merged into one channel list and one guide, so I do not switch between apps or lists."
- "As a user with thousands of channels, I want to hide, rename, reorder and lock groups, and make my own, so the list shows what I watch."

Not reviewed yet.

## What Changes

"Channel lists" means every place that lists groups or channels: the overlay over live TV on Apple TV, the sidebar on iPad and Mac, the group buttons on iPhone, the guide, and All channels.

- Hide a group. It leaves the channel lists, and stays out of search unless the user turns that on for this device.
- Lock a group behind a four-digit passcode, set once for the whole iCloud account. While locks are closed on a device, nobody can see or play a locked channel there, and Lock now closes them by hand.
- Change the passcode after entering the current one.
- The Groups screen, the guide opened on a locked group, and locking another group all ask for the passcode first while locks are closed.
- Rename a provider's group or one of the user's own groups. Favorites and other settings follow the group through a rename.
- Reorder groups. Favorites and All channels always stay at the top.
- The user's own groups: create, rename, pick channels from any playlist, reorder, delete. They behave like any other group, which is how several playlists become one guide.
- A Groups screen on every platform, opened from a Groups row in Sources and Settings.
- A list of settings for groups that no longer exist in any playlist, each with a Remove button.
- Every change syncs to the user's other devices through iCloud.

Out of scope:
- Hiding or locking movie and series categories.
- Shortcuts on group rows in the channel lists (long press, swipe, menu).
- Hiding, reordering or renumbering single channels.
- Sorting the user's own group by channel number.
- Locking the whole app, Favorites or All channels.
- Time limits and content ratings.
- A passcode on Settings itself.
- Importing group setups from other players.
- Resetting the passcode on Apple TV without another Apple device.

## Capabilities

### New Capabilities
- `group-management`: hiding, locking, renaming and reordering groups, the user's own groups, the passcode, and syncing those settings.

### Modified Capabilities
- `channel-catalogue`: the group list follows the user's order and leaves out hidden groups and, while locks are closed, locked ones.

## Impact

- Three new synced records (group settings, group members, passcode check value) and a group policy in the catalogue.
- Amends the channel overlay, zap bar, guide grid, Live on iPhone, iPad and Mac, search, the catalogue and the tvOS shell (group lists, group names, which group shows after one disappears, the channel restored at launch), and Sources and Settings (a Groups row).
- Depends on: `favorites`, `channel-catalogue`, `tvos-shell`, change `add-tv-channel-overlay`, change `add-tv-zap-bar-and-number-entry`, change `add-tv-guide-grid`, change `add-live-tv-on-iphone-ipad-mac`, change `add-search`, change `add-sources-and-settings`.
- Depends on: the `m3u-playlists` follow-up that takes the stream link out of M3U channel ids. Until it ships, a channel from an M3U playlist cannot be saved into the user's own group, because the saved id would carry the provider login.
- Blocked on: a new decision record for the three synced records that amends adr-0003 (credentials in iCloud Keychain) for the passcode check value.
