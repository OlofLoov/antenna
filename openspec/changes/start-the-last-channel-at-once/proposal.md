## Why

The living-room viewer and the on-the-go viewer open Antenna to watch the
channel they had on. Today the app keeps no channel list between launches, so
every start downloads and reads the whole list first. For an Xtream or M3U
source that is 10 to 40 MB, and the picture waits for all of it. The owner
approved saving only the last channel, enough to tune it, so launch can start
that one channel while the list and the guide load behind it as they do now.

Afterwards the viewer opens the app and the channel they left on starts
without waiting for the list, on iPhone, iPad, Mac and Apple TV.

## What Changes

- Each time a channel's stream loads, the device saves that one channel for
  launch: its name, number, group, guide id, logo and stream link, with every
  login taken out of the links.
- At launch, when the saved channel is the last channel and its source has a
  login on the device, the app puts the login back from where it keeps it
  (the Keychain for Xtream, imported files and Channels DVR, the playlist link
  for an M3U playlist) and tunes the channel before the source's list has
  loaded.
- The full list and the guide load as before. When the list arrives the fresh
  channel wins: the same stream plays on without a reload, a changed link is
  tuned again, and a channel that is gone stops on iPhone, iPad and Mac, or
  gives way to the first channel on Apple TV, as a missing channel does today.
- The saved channel is a small file in the app's caches folder, one per
  profile, never synced and never backed up.

Out of scope:
- Saving the channel list, the groups or the guide between launches.
- Stalker portals and Jellyfin servers. Their stream links come from the
  server at each tune or carry a sign-in key, so their channels wait for the
  list as today.
- A channel whose link keeps something that looks like a login the app cannot
  take out (a `user:pass@` part, or a query value named like a token or
  password), or whose playlist entry asks for its own headers. It waits for
  the list as today.
- Any change to the guide, Recents or the session.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-restore-and-recently-watched`: adds "The last channel starts
  before its source loads", "The fresh list decides" and "What is saved for
  launch holds no login"; changes "The last channel plays again" and "Links
  with passwords are never stored" to allow the saved link with its logins
  taken out.
- `tvos-shell`: "Back to the last channel on launch" plays a channel saved
  for launch at once, without waiting for its source or the 10 seconds.

## Impact

- AntennaCore: a saved-channel record and the code that takes logins out of
  a link and puts them back, with tests.
- Apps: a store for the file, the login lookup per source kind, the launch
  tune and the check against the fresh list in `LiveModel` and `ShellModel`,
  the write in `SessionTracker`, and clean-up when a source or profile is
  deleted.
- Builds on `session-restore-and-recently-watched` and
  `tvos-shell/back-to-the-last-channel-on-launch` as they are. Blocked on
  nothing.
- No new container or dependency, so the C4 diagrams stay as they are.
