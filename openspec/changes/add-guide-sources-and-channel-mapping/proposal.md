# Proposal

## Why

Missing guide data is the most common support topic for IPTV players, and users blame the app when the grid says "No programme information". Antenna today downloads one guide per playlist and matches a channel only by the exact guide id the playlist gives it (`tvg-id`). A channel with no id, an id spelled differently from the guide's, or a guide that is missing half the channels leaves the user with no way to find out why and no way to fix it short of editing the playlist.

User stories served:
- "As a user whose guide does not match my channels, I want to pick the guide source and fix a channel's match by hand."
- "As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text."

Not reviewed yet.

## What Changes

- Several guides per playlist: the links the playlist itself names, the guide link saved with the source, the provider's own guide for an Xtream login, and links the user adds.
- A Guide row in each playlist's details in Sources and Settings, showing how many channels have no guide, opens the Guide sources screen.
- The Guide sources screen lists the guides with their status, and lets the user add, reorder, turn off, remove and retry them. Guides from the playlist or the provider can only be turned off, not removed. A turned-off guide is not downloaded.
- On a device the login of a guide link cannot reach, the guide's row offers to enter the link again.
- When two guides cover the same channel, the higher one in the list wins.
- A list of the playlist's channels that have no guide, each with a short reason.
- For a selected channel, why it has no guide, and a search over the guide's entries to pick the right one by hand.
- Removing a hand-picked match.
- Guide settings and matches sync across the user's devices through iCloud.
- Passwords in guide links stay private.

Out of scope:
- Merging programmes for one channel from several guides by time.
- Matching a channel to a guide entry of another playlist.
- Automatic matching by name when the playlist gives no guide id.
- Marking a channel "no guide, stop asking".
- Guide links in onboarding beyond its single guide field.
- A button from "No programme information" in the overlay, guide and browse screens into this screen.
- Where programmes are stored between launches, and how often guides refresh.
- Choosing the language of a guide that names channels in several languages.
- Cleaning up settings left behind by long-deleted playlists.

## Capabilities

### New Capabilities
- `guide-sources-and-channel-mapping`: several guides per playlist with order, on and off, add and remove; the channels-without-guide list with reasons; and hand-picked guide matches, all synced.

### Modified Capabilities
- `guide-data`: a source now uses every guide it names plus the user's added links, in the user's order, instead of a single link; a channel the user matched by hand gets programmes from the picked entry.

## Impact

- A `guide-data` revision lands first: the guide list per source replaces the single-link resolver, progress and failures are per guide, and every lookup of a channel's guide goes through one function that applies matches.
- Amends Sources and Settings (a Guide row in each playlist's details).
- Depends on: `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, change `add-first-run-onboarding`, change `add-tv-channel-overlay`, change `add-tv-guide-grid`, change `add-live-tv-on-iphone-ipad-mac`, change `add-search` (folding and token rules), change `add-sources-and-settings`.
- Depends on: the `m3u-playlists` follow-up that takes the stream link out of M3U channel ids. Until it ships, a hand-picked match for an M3U channel cannot be saved, because the saved id would carry the provider login.
- Blocked on: a decision in this change's design.md on how a source's guide settings are stored and synced. One record per source is assumed; a different shape reopens this change.
