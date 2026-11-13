# Proposal

## Why

> As a viewer who switched my panel playlist to Xtream, I want Recents, the channel my Apple TV opens on, my sound and subtitle picks and my guide matches to keep working.

`add-xtream-panel-links` moves favorites and own-group channels to the Xtream ids when a playlist becomes an Xtream source. Everything else that remembers a channel still holds the old playlist id: Recents empties, the Apple TV opens on the first channel instead of the last one, a channel forgets the sound track and subtitles picked on it, and a hand-picked guide match stops applying. After this change the switch moves all of them with the same channel map.

## What Changes

- The switch moves the channels in Recents and the last channel on this device, for every profile.
- The switch moves the sound and subtitle picks made on each channel on this device, for every profile.
- The switch moves hand-picked guide matches, which sync, so every device sees them on the new ids.
- Nothing stored gains a link or a login: only ids that hold none are written.

Out of scope:
- Recents, last channel and language picks on other devices. They are kept per device and the old channel list exists only on the device that switched. They refill as the user watches.
- Switching back from Xtream to a playlist.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `source-management`: the switch to Xtream also moves recents, the last channel, language picks and guide matches.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `add-xtream-panel-links` (archived), `add-session-restore-and-recently-watched` (archived), the per-channel language picks and the hand-picked guide matches.
- Data: no schema change. Values in `UserDefaults` and the synced guide settings payload are rewritten in place.
- Blocked on: nothing.
