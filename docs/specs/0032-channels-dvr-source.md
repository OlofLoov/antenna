# 0032. Channels DVR server as a live source

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0001, 0002, 0004, 0013, 0014, 0016
- Needs from other specs: 0001, a title-first name option and a minor channel number (AC-7, AC-19 wait on it); 0004, a loader that can report a source waiting for its credential (AC-13 waits on it); 0013, numbers with a part after the dot; 0014, a guide address worked out from the source, sent with the proxy password; 0006, the Channels DVR card, Server field, error wording, the local-network hint and Channels DVR sources in its Apple TV sign-in step; 0010, an unreachable server shown as a failed source.
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- User stories: US-6, US-7

## Summary

Channels DVR is a TV server people run at home; it already holds a tidy channel lineup with the user's own channel numbers and a matching guide. This spec lets a Channels DVR user add the server by typing one address, and see its channels with the names and numbers they set in Channels DVR, plus seven days of guide. Favorites keep working when the server's address changes. Support for a password-protected proxy is built in but stays hidden in the form until playback can send the password with streams. It does not cover recordings, server discovery on the home network, or Channels DVR's own remote-access sign-in, and it draws no screens.

## Design

Boards: none, no UI. The add-source form, the loading checklist and the sources list are 0006 and 0023.
Design rules that apply: none.
Not drawn: nothing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Channels DVR users on Apple TV have no player that keeps the server's channel numbers and ids; players renumber by playlist order and show broadcaster call signs such as "KGWDT" instead of "NBC". Adding the server as a plain playlist today means typing two long links with settings in them on a TV remote, and every favorite breaks when the server's home network address changes. Treating the server as its own kind of source fixes all three in one place, and gives recordings a home later if the owner decides to ship them.

## Scope

In:
- A Channels DVR source kind. The user types one address; Antenna works out the playlist, guide and status addresses from it.
- A status check that tells a Channels DVR server apart from a wrong address, a server still starting up, and a device that is offline.
- Channel names, numbers (including over-the-air numbers like 6.1) and ids taken from the server's lineup.
- An optional username and password for a reverse proxy (a web server in front of Channels DVR that asks for a password), kept in the Keychain.
- Loading the source alongside others without one failing server holding up the rest.
- Streams requested in the format Apple's player plays today.

Out (explicitly):
- Recordings, schedules and the recordings library, until the owner decides on recording.
- The sign-in key that Channels DVR's own remote-access addresses need.
- Finding servers on the home network automatically.
- The add-source form and the loading checklist rows: a 0006 revision.
- Showing the server version and reachability in Settings: 0023.
- Choosing stream format, bitrate or codec per source.
- Channels DVR collections, favorites, hidden channels and filtered exports.
- Channels DVR's own app interface, TV Everywhere logins and channel management.
- Keeping the playlist between launches.
- Sending the proxy password with stream requests: the playback spec.

## User flow

1. The user picks Channels DVR and types the server address as the Channels DVR web admin shows it, for example `192.168.1.20:8089` or `nas.local`.
2. Connect tidies the address, checks the server is there, and downloads the lineup. If it fails, the message says whether the address is wrong, the server is unreachable, or the device is offline.
3. The source is saved; the username and password, if any, go to the Keychain.
4. Each load repeats the check and the lineup download. 0014 downloads seven days of guide.
5. Channels appear with the names and numbers set in Channels DVR. Favorites keep working when the server's address changes.

## Acceptance criteria

### AC-1 Type the address the way Channels DVR shows it
Given a user who types a server address as an IP, a `.local` name or a remote host name, with or without `http://`, a port, a path or a trailing slash
When the form checks it
Then Antenna turns it into one tidy server address, adding `http://` and port 8089 only when the user gave neither; an address with a username or password typed into it, another scheme such as `ftp`, or no host is turned down, so a password never ends up in the synced source.

### AC-5 Connect says what it found
Given an address that points at a working Channels DVR server, a server that is still starting, something that is not Channels DVR, a server that asks for a password, a server with an error, an unreachable host, or a device with no network
When the user taps Connect
Then a working server is accepted whatever its version, and the app gets its version text for the checklist; each of the other cases gets its own error (starting, not a Channels DVR server, needs a password, server error, unreachable, offline), and "unreachable" and "offline" are never confused.

### AC-6 Reach a remote server behind a password
Given a source with a proxy username and password, and a source without one
When either source talks to its server
Then the first sends the username and password with every request, a colon in the password included, and the second sends none.

### AC-7 Channels keep the names and numbers you set
Given a lineup where channels have a display name, a call sign, a channel number and a group, some numbered like 6.1
When the source loads
Then each channel shows the display name (the call sign only when the display name is empty), its number as set in Channels DVR including the part after the dot, its group, its logo and its stream, with no catch-up.

### AC-9 Favorites survive an address change
Given the same lineup fetched once from the server's home address and once from its remote address
When the channels are compared
Then every channel has the same identity both times, never derived from the server's address.

### AC-11 An empty or wrong lineup is handled
Given a lineup download that returns a full lineup, an empty lineup, a web page, nothing at all, or a server error
When the source loads
Then a full lineup gives all its channels, an empty one gives no channels and no error, and a web page, an empty answer or a server error fails with an error that says which.

### AC-13 A source waits for its password to sync
Given a remote source whose password has not reached this device yet, a source whose password cannot be read, and a home source with no password
When the source loads
Then the first sends nothing and shows as waiting for its credential, the second sends nothing and shows as failed, and the third loads without touching the Keychain.

### AC-14 One unreachable server does not hold up the rest
Given a playlist source, a Channels DVR server that cannot be reached, and a Channels DVR server that answers
When the app loads every source
Then the first and third sources' channels are listed and the unreachable one shows as failed without asking for its lineup or guide.

### AC-15 Passwords never show up in messages or logs
Given a remote source with a username and password on a server with a port
When the source, its sign-in details or any error is printed or logged
Then none shows the username, password, their encoded form or the port, and the source prints as the server's host name only.

### AC-19 The guide lines up without manual matching
Given a lineup and the guide file (XMLTV, the common guide format) exported by the same server
When both are loaded
Then every guide channel matches exactly one Antenna channel and every programme lands on a channel, so the user never has to match channels to the guide by hand, and the guide is fetched from the server with no guide link for the user to add.

## Edge cases

- Offline versus server down: a home server is often reachable when the internet is not, and the other way round; the two get different messages.
- Local network permission refused on iPhone, iPad or Mac: the first request to a home address fails, often looking like "offline", so 0006 adds a hint to allow local network access whenever the address is a home one. Apple TV asks no such permission.
- A sleeping NAS fails as unreachable after a short wait; the next load tries again.
- A server that is restarting fails this load as "starting"; Retry in 0010 tries again.
- Remote Channels DVR addresses without their own sign-in key answer with a password demand or a login page and fail as such.
- Remote access through a password-protected proxy also needs the password on stream requests. Until the playback spec sends it, the form hides the username and password fields, so no source is listed that cannot play.
- A proxy username that is empty or contains a colon is turned down, because the standard sign-in format cannot carry it.
- Apple TV: the proxy password never syncs there; 0006's sign-in step must accept Channels DVR sources, or AC-13 waits forever.
- Turning Channels DVR's "use channel ids in M3U" option on or off changes every channel's identity and drops its favorites.
- A guide link the user sets by hand still wins over the server's own guide.
- A guide over the size limits of 0014 fails on its own; the channels still load.
- An older Antenna that receives this kind of source through iCloud treats it as a playlist, gets a web page and lists no channels without crashing.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core |
| AC-5 | core |
| AC-6 | core |
| AC-7 | core |
| AC-9 | core |
| AC-11 | core |
| AC-13 | integration |
| AC-14 | integration |
| AC-15 | core |
| AC-19 | core |

## Open questions

- Ask the server for raw MPEG-TS once the ADR-0001 demuxer exists, instead of HLS? Can be decided in the plan; one setting either way.
- Is the guide path `/devices/ANY/guide/xmltv.xml` or `/devices/ANY/guide/xmltv`? Can be decided in the plan against a live server.
- How does a tvOS user type a number like 6.1 with the remote? Decided in 0008.
- Does the lineup export need an active Channels DVR subscription? If so, AC-5 gains a case and 0006 gains wording.
- Channels DVR's own remote-access sign-in key: deferred until the owner has a remote server to test.

## Notes for the plan

- The text of this spec before the trim (commit 19e8729) holds the address table, the status and lineup outcome tables, the error cases, the type sketch and the full list of changes other specs need. Start from it.
- Addresses: `/devices/ANY/channels.m3u?format=hls&codec=copy`, `/devices/ANY/guide/xmltv.xml?duration=604800` and `/status`; default port 8089. HLS goes to `AVPlayer` under ADR-0001.
- Ids are `channelsdvr#id#<tvg-id>`, else `channelsdvr#no#<tvg-chno>`, else `channelsdvr#pos#<n>`. Keying on `tvg-id` matches the guide; it breaks favorites if the user flips Channels DVR's "use channel ids in M3U" option.
- Other specs: 0001 gains a title-first name option and a minor channel number; 0013 orders and shows numbers as major and minor; 0014 resolves the guide address from the source and sends the proxy password; 0004's loader returns loaded or waiting-for-credential; 0006 gains the type card, a Server field, wording per error and the local-network hint; 0010 shows unreachable as a failed source; `project.yml` gains `NSLocalNetworkUsageDescription` ("Antenna connects to your Channels DVR server on your home network.").
- No ADR needed: the new kind is a new string in the existing `kindRaw` column, and the proxy password goes to the Keychain as ADR-0003 says.
- Requests keep no cookies and no cache; the status request times out after 10 s and the lineup after 30 s.
- The status check never refuses a server for its version or subscription text; a version that does not parse is still accepted.
- Cancellation throws `CancellationError`, not a Channels DVR error.
- Benchmark under `ANTENNA_BENCHMARKS=1`: mapping 50 000 lineup entries under 200 ms in a debug run.

## Dropped

- AC-18 (streams take the MPEG-TS route): removed in review round one; it only re-tested the router's default branch, and the stream format moved to HLS (Notes for the plan) so Channels DVR sources play on the `AVPlayer` path that exists today.
- Moved to the implementation plan: AC-5a, AC-6b, AC-16, AC-17.
- Merged into AC-1: AC-2.
- Merged into AC-5: AC-3, AC-3a, AC-4.
- Merged into AC-6: AC-6a.
- Merged into AC-7: AC-8, AC-10.
- Merged into AC-11: AC-12.
- Required of other specs: moved to the Needs from other specs line and Notes for the plan.
