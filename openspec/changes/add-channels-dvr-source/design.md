# Design

## Context

Boards: none, no UI. The add-source form, the loading checklist and the sources list belong to `add-first-run-onboarding` and `add-sources-and-settings`.

Design-system requirements that apply: none.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

## Goals / Non-Goals

**Goals:**
- A Channels DVR source kind in AntennaCore that tidies one address, checks status, maps the lineup and points the guide at the server.

**Non-Goals:**
- Recordings, server discovery, and Channels DVR's own remote-access key.
- Sending the proxy password with stream requests. Until playback does, the form hides the username and password fields, so no source is listed that cannot play.

## Decisions

- The spec text before the trim (commit 19e8729) holds the address table, the status and lineup outcome tables, the error cases, the type sketch and the full list of changes other capabilities need. Start from it.
- Addresses: `/devices/ANY/channels.m3u?format=hls&codec=copy`, `/devices/ANY/guide/xmltv.xml?duration=604800` and `/status`. Default port 8089. HLS goes to `AVPlayer` under adr-0001, so Channels DVR sources play on the path that exists today.
- Ids are `channelsdvr#id#<tvg-id>`, else `channelsdvr#no#<tvg-chno>`, else `channelsdvr#pos#<n>`. Keying on `tvg-id` matches the guide. It breaks favorites if the user flips Channels DVR's "use channel ids in M3U" option.
- Other capabilities: `m3u-playlists` gains a title-first name option and a minor channel number; `channel-catalogue` orders and shows numbers as major and minor; `guide-data` resolves the guide address from the source and sends the proxy password; the `source-management` loader returns loaded or waiting-for-credential; `add-first-run-onboarding` gains the type card, a Server field, wording per error and the local-network hint; `add-live-tv-on-iphone-ipad-mac` shows unreachable as a failed source; `project.yml` gains `NSLocalNetworkUsageDescription` ("Antenna connects to your Channels DVR server on your home network.").
- No new decision record is needed. The new kind is a new string in the existing `kindRaw` column, and the proxy password goes to the Keychain as adr-0003 says.
- Requests keep no cookies and no cache. The status request times out after 10 s and the lineup after 30 s.
- The status check never refuses a server for its version or subscription text. A version that does not parse is still accepted.
- Cancellation throws `CancellationError`, not a Channels DVR error.
- Benchmark under `ANTENNA_BENCHMARKS=1`: mapping 50 000 lineup entries under 200 ms in a debug run.
- Dropped: a requirement that streams take the MPEG-TS route. It only re-tested the router's default branch, and the stream format moved to HLS.

## Risks / Trade-offs

- Open question: ask the server for raw MPEG-TS once the adr-0001 demuxer exists, instead of HLS? Can be decided at implementation; one setting either way.
- Open question: is the guide path `/devices/ANY/guide/xmltv.xml` or `/devices/ANY/guide/xmltv`? Can be decided at implementation against a live server.
- Open question: how a tvOS user types a number like 6.1 with the remote. Decided in `add-tv-zap-bar-and-number-entry`.
- Open question: does the lineup export need an active Channels DVR subscription? If so, the Connect requirement gains a case and onboarding gains wording.
- Open question: Channels DVR's own remote-access sign-in key, deferred until the owner has a remote server to test.
- [Local network permission refused on iPhone, iPad or Mac] → the first request to a home address fails, often looking like "offline", so onboarding adds a hint to allow local network access whenever the address is a home one. Apple TV asks no such permission.
- [The proxy password never syncs to Apple TV] → onboarding's Apple TV sign-in step must accept Channels DVR sources, or the source waits for its credential forever.
