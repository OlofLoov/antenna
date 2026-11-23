# Design

## Context

See proposal.md for why. What exists on 2026-11-23:

- `RecentsStore` keeps the last channel as a `LastChannelKey` (source id and
  channel id, no link) in `UserDefaults` under `shell.lastChannel`, per
  profile. `SessionTracker.load` writes it once a stream loads, on every
  platform.
- iPhone, iPad and Mac: `LiveRestore` reads the key at launch and
  `LiveModel.replay()` tunes the channel once Live shows and the key's source
  has loaded.
- Apple TV: `ShellModel.considerTune()` tunes the key's channel once its
  source loads within 10 seconds, else the first channel of the first source
  to finish.
- Logins: Xtream and Channels DVR keep one username and password in the
  Keychain under the source's `credentialKey`; an imported file keeps a list
  of `StreamCredential` there (`StreamLoginStore`). An M3U playlist's login,
  when it has one, is the `username` and `password` in the playlist link the
  source record holds. Stalker resolves a fresh address at each tune;
  Jellyfin links carry a sign-in key.
- `StreamHeaderBook` gives streams their source's User-Agent once the source
  loads, and a playlist entry's own headers live in memory only.

## Boards

No screen changes. The player, the Live list and the Apple TV full screen
look as they do; only when the picture starts changes. No board is needed.

## Decisions

### 1. Where the saved channel lives

Options:
- **UserDefaults**, next to `shell.lastChannel`. Ruled out: the hard
  constraints keep stream links out of `UserDefaults`, even with the login
  taken out.
- **SwiftData or CloudKit**. Ruled out: the channel is per device, and a
  synced record would carry links to every device.
- **A non-synchronizable Keychain item** holding the full link. Ruled out:
  every Keychain item the app writes is synchronizable, and once the login is
  out the record is not a secret.
- **A file in Application Support excluded from backup.** Works on iPhone,
  iPad and Mac, but tvOS gives apps only the caches folder for files, so
  Apple TV would need a second place.
- **A file in the caches folder** (chosen). Every platform has it, the system
  never backs it up or syncs it, and `SeenChannelsStore` and the guide already
  keep their files there. The system may empty it when storage runs low; the
  next launch then waits for the list, as today, and the next tune saves the
  channel again.

The file is `Caches/launch/channel-<profile id>.json`, one per profile, JSON
of `SavedChannel`. A file that is missing or cannot be read counts as nothing
saved.

### 2. What is saved, and how logins come out

`SavedChannel` (AntennaCore, `Recents/SavedChannel.swift`) holds the source
id, channel id, name, number, minor number, group, guide id, the logo link
and the stream link. Links are `SavedLink`: the scheme, host and port as one
string, the path split at `/`, and the query items, each part either text or
a mark naming a login by its index (`username(0)`, `password(0)`).

Options for taking the login out:
- **Store the Xtream stream id and rebuild the link with `XtreamClient`.**
  Exact for Xtream, but M3U playlists and imported files need their own path.
- **`PlaylistImport.stripCredentials` with placeholders in the text.** Knows
  three link shapes, and misses the `/<user>/<pass>/<id>` shape Xtream
  panels put in M3U playlists.
- **Compare each path part and query value with the source's logins**
  (chosen). Any part equal to a login's username or password becomes a mark,
  so the link shape does not matter, and the record holds no placeholder text
  that could be confused with a real value.

`SavedLink` refuses (returns nil, and the channel is not saved) when:
- the scheme is not http, https or file (a Stalker `stalker:` reference);
- the link has a user or password before the host, or a fragment;
- a query item whose name contains pass, pwd, user, token, auth, key, sign,
  secret, session or hash keeps a text value;
- any text part still contains a username or password of six or more
  characters. Shorter ones are only matched as a whole part, so a password
  such as `1234` does not refuse every link with a stream id like `12345`.

A channel whose playlist entry has its own headers is not saved: those
headers can carry a token and stay in memory only.

What a link can still carry: an M3U playlist from an unknown server can put
a token in a path part that matches no login and no query name above. That
link is saved as it is, in a file only this app on this device can read. The
playlist link that holds the same token already sits in the source record.

`SavedChannel.Login` holds a username and password, is not `Codable`, and
prints and dumps as `Login(redacted)`.

### 3. Where logins come back from

`LaunchLogins` (Apps, `Persistence/LaunchChannelStore.swift`) answers the
logins for a source, the same answer when saving and at launch:

| Kind | Logins | Saved |
|------|--------|-------|
| Xtream | the Keychain item under `credentialKey` | yes |
| M3U playlist | `username` and `password` from the playlist link, or none | yes |
| Imported file | the `StreamLoginStore` list, or none without an item | yes |
| Channels DVR | the Keychain item when there is a proxy login, else none | yes |
| Stalker, Jellyfin | | no |

A Keychain item that cannot be read answers nil: nothing is saved and
nothing starts early. A password changed on another device comes back new
at launch, since the mark names the login and not its old value.

### 4. Launch and the fresh list

The saved channel is used only when its key equals the stored
`LastChannelKey`. Deleting a source, switching a source to Xtream and
renaming channel ids already change or clear that key, so a stale file can
never tune the wrong channel; the file is deleted in those places too.

iPhone, iPad and Mac (`LiveModel`): `replay()` runs once Live shows, as
before, and now also after `sourcesChanged`. When the key's source has no
channels yet, has its login, and the saved channel rebuilds, it tunes it and
remembers the key in `restore.started`. A user pick clears it.

Apple TV (`ShellModel`): `considerTune()` tunes the saved channel while its
source is still loading, before the 10-second deadline, and remembers the key
in `launchStarted`. `tune` already cancels the deadline.

When the key's source finishes loading, both models call
`reconcileLaunch()` before anything else looks at the new channels:
- the playing channel is no longer the started one: nothing;
- the list has it and `SavedChannel.sameStream` says the link is the same,
  and the player shows no failure: the fresh `Channel` takes the saved one's
  place with no reload (`adopt`), so catch-up, the number and the guide id
  come from the list;
- the list has it with another link, or the start failed: `tune(fresh)`;
- the list lacks it: iPhone, iPad and Mac stop; Apple TV clears its stored
  key and runs `considerTune()`, which picks the first channel as for a
  missing channel today.

A failed source load leaves the started channel playing and keeps the key
for the next successful load.

`adopt` replaces the channel without telling the player it changed
(`PlayerModel.retitle`) and without restarting the ten-second count
(`SessionTracker.adopt`). The count, the post-load write in
`SessionTracker.load` and the post-load play in both models compare channels
by source and id, so a channel adopted mid-load still plays and counts.

Before the early tune, the source's User-Agent goes into `StreamHeaderBook`
for the stream's server, as an Xtream load does, so the early stream asks
with the same headers the later list would give it.

### 5. Writing and clean-up

`SessionTracker.remember(_:)` writes the key, as now, and calls `saved`, which
each model sets to build the `SavedChannel` from the source's logins and
write it, or delete the file when the channel cannot be saved. Multi-view
handing a channel back uses the same call.

`RecentsStore` gains `launch: LaunchChannelStore`, so tests, previews and UI
tests get their own folder with their own defaults. `RecentsStore.remove`
and `renameChannels` delete the file of every profile when it belongs to the
source. `ProfileKeys.prune` deletes the files of profiles that no longer
exist.

UI tests: `UITestingRecents.store` puts the folder under the temporary
folder and empties it unless `-ui-testing-keep-session` is passed. The
scripted logins for Live and the shell answer an Xtream fixture login and no
login for the playlists.

## Tests

- AntennaCore `SavedChannelTests`: round trips for the Xtream, panel M3U and
  query shapes; refusals; a changed password; a missing login; same-stream
  checks; and a pinning test that encodes saved channels and finds no
  username or password in the bytes.
- Apps `LiveRestoreTests` and TV `ShellModelTests`: the early tune before the
  list, adopt without reload, retune on a changed link, gone, failed start,
  a pick before the list, no early tune without a login, and the file holding
  no login.
- UI: `RestoreUITests` (iPhone) and `RecentsTVUITests` (Apple TV) relaunch
  into a scenario whose source never finishes and see the last channel play.

## Risks

- A provider that rotates a token inside the path makes the early tune fail;
  the fresh list then tunes again, so the viewer sees an error for as long as
  the list takes, then the channel.
- A purged caches folder costs one slow launch.
