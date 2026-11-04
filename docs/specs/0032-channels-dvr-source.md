# 0032. Channels DVR server as a live source

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- Builds on specs 0001 (M3U parsing), 0002 (XMLTV parsing), 0004 (sources, `SourceRecord`, `SourceLoader`), 0013 (catalogue, numbers), 0014 (guide download and join), 0016 (error shape and secret-free descriptions, followed here). Changes it needs in those specs are listed under "Required of other specs".
- Blocked on: the 0001, 0013 and 0014 revisions listed under "Required of other specs", and 0004's injectable `SourceLoader` seam with the `SourceLoadResult` type defined there. AC-1 to AC-7, AC-9, AC-11, AC-12 and AC-15 to AC-17 can be implemented and tested before any of them; AC-8, AC-10 and AC-19 wait for the 0001 revision. Basic auth (AC-6, AC-6a, AC-6b, AC-13) is implemented in the client now but not offered in the add-source form until the playback spec sends per-source headers with stream requests; LAN servers are not affected.
- ADR needed: none. The new `SourceKind` case is a string raw value in an existing defaulted column (`kindRaw`), so the ADR-0002 schema is unchanged; Basic auth credentials go to the Keychain exactly as ADR-0003 describes; streams are HLS and take the `AVPlayer` route ADR-0001 already names for HLS. The stream format choice (AC-2) is a query parameter and is reversible, so it is an open question, not an ADR.
- Type names: `ChannelsDVRClient`, `ChannelsDVRClient.ChannelsDVRError`, `ChannelsDVRStatus`, `ChannelsDVRVersion` and `HTTPBasicCredential` are new in AntennaCore. This spec writes the error without the `ChannelsDVRClient.` prefix.

## Design

Boards: none, no UI. The add-source form, the loading checklist and the Sources list are 0006 and the Sources and Settings spec; this spec only hands them typed results.
Design rules that apply: none.

## Problem

Channels DVR users already own a server on their LAN that exposes a clean, numbered channel lineup and a matching XMLTV guide. On Android they point TiviMate at its M3U and XMLTV URLs; on Apple TV they have no client that keeps the server's channel numbers and ids, and they script around players that renumber by playlist order (research note, complaint 12 and the tvOS shopping list "Exposes channel ID's"). Typing two long URLs with query parameters on a TV remote is also the kind of setup step the onboarding spec exists to remove.

### Why a source kind of its own

A Channels DVR server could be added today as a plain M3U source. It is not, because six things differ and all of them live in one place if the server is its own kind:

1. The user enters one address (host, or host and port) and Antenna derives the playlist, guide and status URLs from it (AC-1, AC-2). A plain M3U source needs two pasted URLs and the query parameters typed by hand.
2. The server tells us what it is. `GET /status` answers with its version (AC-3 to AC-5), so a wrong address, a sleeping NAS and a device that is offline are three different, nameable failures instead of "could not parse playlist".
3. The playlist carries the server's own lineup semantics: `tvg-chno` is the number the user set in Channels, including ATSC numbers like `6.1`, `tvg-id` is the channel id the guide keys on, and `tvg-name` is the broadcaster call sign while the title is the name the user knows (AC-7 to AC-10). A plain M3U source would show "KGWDT" instead of "NBC" and drop every `6.1`.
4. Channel ids must survive the server's address changing. A home server moves between a LAN IP, a `.local` name and a remote hostname; 0001's fallback ids embed the stream URL, so every favorite would break on a DHCP change. This kind keys ids on the lineup, never on the host (AC-9).
5. Remote access through a reverse proxy uses Basic auth. A plain M3U source has nowhere to keep that credential except the URL, which ADR-0003 rejects (AC-6, AC-13).
6. Recordings and DVR scheduling, if the owner decides to ship them, need the same server address and credential. Storing the server as its own kind now means that spec adds endpoints, not a migration.

## Scope

In:
- `SourceKind.channelsDVR` with raw value `"channelsdvr"`. `SourceDescriptor.url` holds the normalised server base URL (AC-1); `epgURL` is nil and the guide URL is derived by 0014's resolver; `credentialKey` is nil for a LAN server and set when the user gave a Basic auth username and password.
- `ChannelsDVRClient` in AntennaCore: `init(server: URL, credential: HTTPBasicCredential? = nil, session: URLSession = .shared)`, pure URL builders `playlistURL()`, `guideURL()`, `statusURL()`, the static normaliser `serverURL(from: String) -> URL?`, `status()` and `channels()` over the network, and the pure functions `decodeStatus(_: Data) throws -> ChannelsDVRStatus` and `channels(fromPlaylist: Data) throws -> [Channel]` that the network calls compose. `channels(fromPlaylist:)` applies the AC-11 header rule, decodes UTF-8 with replacement characters, runs 0001's parser with `nameSource: .title` and hands the `Playlist` to the pure `static func channels(mapping: Playlist) -> [Channel]`, which assigns ids (AC-9); `channels()` adds only the request. Constants `defaultPort` (8089) and `guideDuration` (7 days in seconds, 604 800).
- `ChannelsDVRStatus` (`version: ChannelsDVRVersion?`, `versionText: String`, `prerelease: Bool?`, `booted: Bool?`, `subscription: String?`) and `ChannelsDVRVersion` (`Comparable`, `init(year:month:day:build:)`, `init?(parsing:)` over the server's `yyyy.MM.dd.HHmm` text). The version is reported, never gated on.
- `HTTPBasicCredential` (`init?(username:password:)`, nil when the username is empty or contains a colon), sent as an `Authorization: Basic` header on every request the client makes. Stored by the app layer through `CredentialStore` under `SourceRecord.credentialKey` (0004/AC-4 applies with this kind).
- `ChannelsDVRError`: `.offline`, `.unreachable(URLError.Code)`, `.transport(URLError.Code)`, `.notAChannelsServer`, `.starting`, `.unauthorized`, `.httpStatus(Int)`, `.malformed`, `.credentialUnreadable`. A missing credential is not an error; the loader reports it as `SourceLoadResult.waitingForCredential` (AC-13).
- Channel mapping on top of 0001's parser: ids keyed on the lineup, title-first names, decimal numbers (AC-7 to AC-10).
- `SourceLoader` (0004) case for the kind: status check, playlist fetch, and failure isolation (AC-13, AC-14). The guide needs no call from the loader; 0014 resolves `guideURL()` from `kind` and `url`.
- Streams requested as HLS with the original codecs (`format=hls&codec=copy`), which ADR-0001 routes to `AVPlayer`.

Out (explicitly):
- Recordings, recording schedules, passes and the DVR library. Pending the owner's recording decision (research note, "Recording, or an explicit decision not to ship it in v1"); a later spec after that decision.
- The remote-access `session` token that `*.u.channelsdvr.net` URLs need. It expires after about 30 days and has no refresh path we control; a later revision of this spec once the owner has a server to test against.
- Bonjour or network discovery of servers on the LAN. A later onboarding revision.
- The add-source form, type card and loading checklist rows for this kind. 0006 revision, listed below.
- Showing the server version and reachability in Settings. Sources and Settings spec.
- Per-source stream format, bitrate or codec settings. Needs a `SourceRecord` field and therefore an ADR.
- Channels DVR collections, favourites, hidden channels and `filter=` exports. The `ANY` lineup is the whole lineup the user has enabled in Channels.
- Channels' client API (`/api/...`), TVE logins, custom channel management, comskip.
- Caching the playlist between launches. 0004 lists it out; the source refresh spec owns it.
- Sending the Basic auth header with stream requests. Playback spec, listed below.

Required of other specs:
- 0001: `M3UParser` gains an option `nameSource` with cases `.tvgName` (today's behaviour, default) and `.title` (the text after the comma wins, `tvg-name` only when the title is empty), and `Channel` gains `minorNumber: Int?` so `tvg-chno="6.1"` yields `number` 6 and `minorNumber` 1 instead of `number` nil. Integer values are unchanged. AC-8 and AC-10 of this spec depend on both.
- 0013: `number(for:)` returns `ChannelNumber(major: Int, minor: Int?)` whose `description` is "6.1" for a minor number and "6000" without one; ordering (0013/AC-6a) compares `(major, minor)` with nil `minor` before 0; `match(digits:)` (0013/AC-12) keeps its `String` input and treats the digits as a major number, so "6" matches 6, then 6.1, 6.2 in minor order, and leaves entering a dot to the open question below; the 1...99 999 ceiling in 0013/AC-5a applies to `major` alone. This changes an interface that 0007, 0008, 0009, 0010 and 0012 render as "<number>": every consumer that renders a number uses `ChannelNumber.description`, and 0008's entry path is unchanged until the dot-entry question is settled. 0013/AC-4 already passes provider numbers through unchanged, which is what Channels DVR users ask for.
- 0014: `GuideURLResolver.resolve` gains the row "Channels DVR without `epgURL`: `ChannelsDVRClient.guideURL()` built from `url`"; the download request carries the source's `Authorization: Basic` header when it has a credential; 0014/AC-12's `.unauthorized` mapping applies to this resolver-built URL as it does to the Xtream one; 0014/AC-1a and AC-1b apply to this kind when `credentialKey` is non-nil: no request, `.credentialMissing` with keys `.unavailable`, or `.credentialUnreadable` with keys `.failed`. The loader never calls `register(epgURLs:for:)` for this kind.
- 0004: `SourceLoader.load` returns `SourceLoadResult`: `.loaded([Channel])` or `.waitingForCredential`, and throws on failure; the `.m3u` and `.xtream` cases keep their behaviour through the new type. For this kind `ChannelsDVRClient.serverURL(from:)` replaces 0004/AC-1's scheme check: nil yields "Enter a valid server address." and the record stores the normalised URL. Unknown `kindRaw` on an older build still falls back to `.m3u` (0004 edge case); for this kind that fetches the server base URL as a playlist, gets HTML or a 404, and yields zero channels without touching the credential.
- 0006: a "Channels DVR" type card with a Server field (required, URL keyboard on every platform) and, under "Remote access", Username and Password. The Remote access fields are not shown until the playback spec's per-source headers are Implemented; until then `credentialKey` is always nil for this kind. When shown: both empty means no credential; one filled and not the other is 0006/AC-31's "Enter the <field name>."; nil from `HTTPBasicCredential.init` for a colon is 0004/AC-5's path. Connect validates through `serverURL(from:)` as above; nil reads "Enter a valid server address.", or "Enter the username and password under Remote access, not in the address." when the text had userinfo; 0006/AC-24's duplicate check compares normalised URLs. Error copy: `.unreachable` and `.transport` reuse 0006/AC-23, `.offline` reuses 0006/AC-8 (whose Given gains `ChannelsDVRError.offline`), `.httpStatus(n)` reuses 0006/AC-29 with that status, `.malformed` reuses 0006/AC-33, `.notAChannelsServer` reads "No Channels DVR server at <host>.", `.starting` reads "Channels DVR is starting. Try again in a moment.", `.unauthorized` reuses 0006/AC-7's text when a credential was sent and reads "This server asks for a username and password. Enter them under Remote access." when none was. When the failure is `.offline` or `.unreachable` and the host is a private IPv4 address, an IPv6 link-local address or a `.local` name, on iOS, iPadOS or macOS the copy adds "Allow local network access for Antenna in Settings." The checklist has a "Server" row reading "Channels DVR <versionText>" and no login or movies row. 0006/AC-21's Given becomes "every `SourceRecord` that needs a credential (Xtream, or this kind with non-nil `credentialKey`) lacks a readable Keychain item"; sources that need none load as usual; for this kind the step shows Server prefilled, Username and Password empty, and Connect runs AC-5 and AC-12 of this spec before writing the Keychain item.
- 0010: `.unreachable` counts as a failed source (0010/AC-20, AC-21) and is never shown with the offline text, which stays reserved for `.offline`; 0010/AC-20's offline test gains `ChannelsDVRError.offline`. `.waitingForCredential` is the state 0010/AC-18 and AC-24 render.
- `project.yml`: `NSLocalNetworkUsageDescription` on the Antenna target, copy "Antenna connects to your Channels DVR server on your home network." tvOS shows no prompt and needs no key.
- Playback spec (ADR-0001 follow-up): the engine accepts per-source HTTP headers, because stream URLs inside the playlist point at the same server and a reverse proxy with Basic auth rejects them without the header.

## User flow

As 0006 will render it once revised; this spec supplies the behaviour behind each step.

1. User picks Channels DVR as the source type and types the server address as shown in the Channels DVR web admin, for example `192.168.1.20:8089` or `nas.local`. Remote users may add a username and password for their reverse proxy.
2. Connect normalises the address (AC-1), calls `/status` (AC-5) and, when the server answers, downloads the playlist (AC-12). The error cases name the host, the server, or the device being offline.
3. The source is saved with the server URL; the credential, if any, goes to the Keychain.
4. On every load the loader repeats the status check and the playlist download. 0014 resolves the guide URL from the record and downloads seven days of guide (AC-2).
5. Channels appear with the numbers and names the user set in Channels DVR. Favorites keep working when the server's IP changes.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Server address normalisation
Given the texts in the table below
When `ChannelsDVRClient.serverURL(from:)` runs
Then the result is the URL in that row: surrounding whitespace is trimmed; `http://` is prepended when no scheme is present; port 8089 is appended only when the text had neither a scheme nor a port; the host is lowercased; query, fragment and a trailing slash are removed; a path is kept; an IPv6 literal is accepted only in brackets; a scheme other than `http` or `https`, an empty host, no host, or any userinfo yields nil, so a password typed into the address never reaches `SourceRecord.url` (ADR-0003).

| Text | Result |
|------|--------|
| `192.168.1.20` | `http://192.168.1.20:8089` |
| ` 192.168.1.20:8089 ` | `http://192.168.1.20:8089` |
| `nas.local` | `http://nas.local:8089` |
| `nas.local:8090` | `http://nas.local:8090` |
| `NAS.Local:8089` | `http://nas.local:8089` |
| `nas.local/` | `http://nas.local:8089` |
| `nas.local/channels` | `http://nas.local:8089/channels` |
| `http://nas.local:8089/` | `http://nas.local:8089` |
| `http://nas.local` | `http://nas.local` |
| `https://abc.u.channelsdvr.net:8089` | `https://abc.u.channelsdvr.net:8089` |
| `https://home.example.net/channels/?x=1#f` | `https://home.example.net/channels` |
| `[fe80::1]` | `http://[fe80::1]:8089` |
| `[fe80::1]:8090` | `http://[fe80::1]:8090` |
| `fe80::1` | nil |
| `http://alice:secret@nas.local` | nil |
| `http://alice@nas.local` | nil |
| `ftp://nas.local` | nil |
| `http://` | nil |
| `` | nil |

### AC-2 Endpoint URLs
Given a client for server `http://nas.local:8089` and one for `https://home.example.net/channels`
When `playlistURL()`, `guideURL()` and `statusURL()` are built
Then they are `http://nas.local:8089/devices/ANY/channels.m3u?format=hls&codec=copy`, `http://nas.local:8089/devices/ANY/guide/xmltv.xml?duration=604800` and `http://nas.local:8089/status`; for the second server the same paths follow `/channels` (`https://home.example.net/channels/devices/ANY/channels.m3u?format=hls&codec=copy`); `duration` equals `ChannelsDVRClient.guideDuration` and no request is issued.

### AC-3 Status decodes
Given the body `{"version":"2022.08.16.2108","prerelease":true,"booted":true,"subscription":"active"}`
When `decodeStatus(_:)` runs
Then `versionText` is "2022.08.16.2108", `version` is `ChannelsDVRVersion(year: 2022, month: 8, day: 16, build: 2108)`, `prerelease` is true, `booted` is true and `subscription` is "active"; for `{"version":"2025.03.01.0012"}` the three optionals are nil; for `{"version":"2025.03.01.0012-dev"}` `versionText` is the full string and `version` is parsed from its leading digit groups; for `{"version":"custom"}` `version` is nil and `versionText` is "custom".

### AC-3a Not a Channels DVR server
Given bodies `{}`, `[]`, `"2022.08.16.2108"`, `{"ver":"1"}`, `{"version":123}`, an HTML page, and empty `Data`
When `decodeStatus(_:)` runs
Then each throws `.notAChannelsServer`; a body is a Channels DVR status only when it is a JSON object with a string `version` key.

### AC-4 Version ordering
Given the texts "2022.08.16.2108", "2022.08.16.2109", "2022.08.17.0001", "2023.01.01.0000", "2023.1.1", "2023.01.01" and "abc"
When `ChannelsDVRVersion(parsing:)` runs and the results are compared
Then the first four parse and are strictly increasing in that order; "2023.1.1" and "2023.01.01" parse to `(2023, 1, 1, 0)` and compare equal to each other and to "2023.01.01.0000"; "abc" and any text with fewer than three leading digit groups yield nil; comparison is numeric per component, never lexical.

### AC-5 Status outcomes
Given a `URLProtocol` stub and the responses below
When `status()` runs, parameterised
Then the outcome is the one in that row and exactly one GET to `statusURL()` is issued in every row. For a 200 body the checks run in the order `.notAChannelsServer` (AC-3a), then `.starting`; the first that applies wins.

| Response | Outcome |
|----------|---------|
| 200, AC-3 body | returns the status |
| 200, AC-3 body with `"booted":false` | throws `.starting` |
| 200, `version` nil per AC-3 ("custom") | returns the status; an unparseable version is never a reason to refuse |
| 200, HTML body, `{}` or `{"booted":false}` without `version` | throws `.notAChannelsServer` |
| 404 | throws `.notAChannelsServer` |
| 401 or 403 | throws `.unauthorized` |
| 500, 502, 503 | throws `.httpStatus(n)` |
| `URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` | throws `.offline` |
| `URLError` `.cannotConnectToHost`, `.cannotFindHost`, `.timedOut`, `.dnsLookupFailed` | throws `.unreachable(code)` |
| any other `URLError` | throws `.transport(code)` |
| response that is not `HTTPURLResponse` | throws `.httpStatus(-1)` |

### AC-5a Cancellation
Given the calling task is cancelled while a `status()` or `channels()` request is in flight
When the call returns
Then it throws `CancellationError`, not `ChannelsDVRError` (as 0016/AC-10a).

### AC-6 Request shape and Basic auth
Given a client with credential username `alice` and password `p@ss:wörd`, and a second client without a credential
When `status()` and `channels()` run on each, with the stub recording requests
Then every request of the first client carries exactly one `Authorization` header equal to `Basic ` followed by the Base64 of the UTF-8 bytes of `alice:p@ss:wörd` (a colon in the password is kept), and the second client's requests carry no `Authorization` header.

### AC-6a Credential construction
Given the pairs (`alice`, `x`), (`al:ice`, `x`), (``, `x`) and (`alice`, ``)
When `HTTPBasicCredential(username:password:)` runs
Then the first and fourth are non-nil and the second and third are nil: RFC 7617 cannot carry a colon in the user id, and an empty user id is no credential; an empty password with a user id is allowed.

### AC-6b Request configuration
Given either client of AC-6
When `status()` and `channels()` run with the stub recording requests
Then every request has `httpShouldHandleCookies` false and `cachePolicy` `.reloadIgnoringLocalCacheData`; the status request has `timeoutInterval` 10 and the playlist request 30.

### AC-7 Channel mapping, channel-id mode
Given a playlist consisting of `#EXTM3U` followed by the entry
```
#EXTINF:-1 channel-id="nbc" tvg-id="nbc" tvg-chno="6000" tvg-logo="https://img.example/s28717.png?w=360&h=270" tvc-guide-stationid="20378" tvg-name="KGWDT" group-title="HD",NBC
http://nas.local:8089/devices/ANY/channels/6000/hls/master.m3u8?codec=copy
```
When `channels(fromPlaylist:)` runs
Then one `Channel` is returned with `id` "channelsdvr#id#nbc", `name` "NBC", `number` 6000, `minorNumber` nil, `epgID` "nbc", `group` "HD", `logoURL` `https://img.example/s28717.png?w=360&h=270`, `streamURL` the line that follows, `hasCatchup` false and `catchupDays` nil.

### AC-8 Channel mapping, number mode and ATSC numbers
Given a playlist consisting of `#EXTM3U`, the entry `#EXTINF:-1 tvg-id="6.1" tvg-chno="6.1" tvg-name="KGWDT" group-title="HD",NBC` and the entry `#EXTINF:-1 tvg-id="6000" tvg-chno="6000" tvg-name="CNN",CNN`, each followed by a stream URL
When `channels(fromPlaylist:)` runs
Then the first channel has `id` "channelsdvr#id#6.1", `number` 6, `minorNumber` 1 and `epgID` "6.1"; the second has `id` "channelsdvr#id#6000", `number` 6000, `minorNumber` nil and `epgID` "6000". Depends on the 0001 revision under "Required of other specs".

### AC-9 Ids come from the lineup, not the host
Given two playlists that are byte-identical except that every URL's host is `192.168.1.20:8089` in one and `abc.u.channelsdvr.net:8089` in the other, each consisting of `#EXTM3U` and four entries in this order: `tvg-id="7" tvg-chno="7"`; `tvg-chno="4"` and no `tvg-id`; `tvg-id="4"` and no `tvg-chno`; neither attribute
When both are mapped
Then the ids are "channelsdvr#id#7", "channelsdvr#no#4", "channelsdvr#id#4" and "channelsdvr#pos#4" (the 1-based index of the entry among emitted entries, as 0001's fallback); the three forms never collide with each other; the `id#` and `no#` forms use the attribute text as written, so `tvg-chno="6.1"` without `tvg-id` yields "channelsdvr#no#6.1"; the ids are equal across the two playlists and `streamURL` differs. Two entries that share a `tvg-id` keep the same id; they are not deduplicated here and 0013/AC-11a lists both.

### AC-10 Name precedence
Given a playlist consisting of `#EXTM3U` and entries with `tvg-name="KGWDT"` and title "NBC"; `tvg-name="KGWDT"` and an empty title; and neither
When `channels(fromPlaylist:)` runs
Then the names are "NBC", "KGWDT" and "" respectively, and no entry is skipped for an empty name (0001 edge case). Depends on the 0001 `nameSource: .title` option.

### AC-11 Playlist body shapes
Given bodies: a playlist with 412 entries; `#EXTM3U` alone; the same preceded by a UTF-8 BOM and blank lines; an HTML page; and empty `Data`
When `channels(fromPlaylist:)` runs
Then the first returns 412 channels, the second and third return zero channels without an error, and the fourth and fifth throw `.malformed`; a body counts as a playlist when its first non-whitespace text after an optional BOM starts with `#EXTM3U`.

### AC-12 Playlist fetch outcomes
Given a `URLProtocol` stub and the responses below
When `channels()` runs, parameterised
Then the outcome is the one in that row, exactly one GET to `playlistURL()` is issued, and no request to `statusURL()` is issued by `channels()`.

| Response | Outcome |
|----------|---------|
| 200, the 412-entry playlist | returns 412 channels |
| 200, HTML page | throws `.malformed` (AC-11) |
| 401 or 403 | throws `.unauthorized` |
| 404 | throws `.httpStatus(404)`; the "not a server" judgement belongs to `status()` |
| 500, 502, 503 | throws `.httpStatus(n)` |
| `URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` | throws `.offline` |
| `URLError` `.cannotConnectToHost`, `.cannotFindHost`, `.timedOut`, `.dnsLookupFailed` | throws `.unreachable(code)` |
| any other `URLError`, `.secureConnectionFailed` and `.badServerResponse` among them | throws `.transport(code)` |
| response that is not `HTTPURLResponse` | throws `.httpStatus(-1)` |

### AC-13 Credential missing or unreadable
Given three `SourceRecord`s of this kind: one with `credentialKey` non-nil whose Keychain item is absent on this device, one whose Keychain read fails with a status other than not-found, and one with `credentialKey` nil
When `SourceLoader.load` runs for each with a stubbed session and a fake `CredentialStore`
Then no request is issued for the first two; the first returns `.waitingForCredential` (0010/AC-18 and AC-24 render it); the second throws `.credentialUnreadable` and is recorded as failed (as in 0004); the third performs no Keychain read and returns `.loaded` after the AC-14 requests.

### AC-14 Loader order and failure isolation
Given three sources in `sortOrder`: an M3U source, a Channels DVR source whose `/status` fails with `.unreachable(.cannotConnectToHost)`, and a Channels DVR source that answers both calls
When the loader runs
Then the second source issues one status request and no playlist request and is recorded as failed with that error, the first and third sources' channels are listed, the third source issued exactly one status and one playlist request in that order, the fake `GuideStore` received `update(channels:)` followed by `refreshIfStale(now:)` for the third source and no `register(epgURLs:for:)` call for either Channels DVR source, and the second source triggered no `GuideStore` call at all.

### AC-15 No secrets in descriptions
Given a client for `https://home.example.net:8443/channels` with username `alice-7f3e` and password `s3cr3t-9b2a`
When `String(describing:)` and `String(reflecting:)` are read for `HTTPBasicCredential`, `ChannelsDVRClient`, `.unauthorized`, `.unreachable(.cannotConnectToHost)` and `.httpStatus(503)`, and `(error as NSError).userInfo` for each error
Then none contains `alice-7f3e`, `s3cr3t-9b2a`, the Base64 of `alice-7f3e:s3cr3t-9b2a`, or `:8443`; `String(describing:)` and `String(reflecting:)` of the credential are the literal `HTTPBasicCredential`; `String(describing:)` of the client equals `home.example.net`; both types conform to `CustomStringConvertible` and `CustomDebugStringConvertible` (as 0016/AC-8).

### AC-16 Mapping is fast
Given the `Playlist` parsed from a Channels-style playlist of 50 000 entries generated in the test from the AC-7 line
When `channels(mapping:)` runs over it
Then it completes in under 200 ms in a debug `swift test` run on the reference machine named in the test; benchmark, not CI-gated, enabled by `ANTENNA_BENCHMARKS=1` as 0016/AC-9 defines.

### AC-17 Source kind raw value
Given `SourceKind.channelsDVR`
When its raw value, `CaseIterable` membership and a `Codable` round trip are read
Then the raw value is "channelsdvr", `SourceKind(rawValue: "channelsdvr")` is `.channelsDVR`, `allCases` contains it after `.stalker`, and a `SourceDescriptor` of this kind with `epgURL` nil and `credentialKey` "k" encodes and decodes equal to itself.

### AC-19 Guide ids match without mapping
Given the playlist fixture of AC-7 and AC-8 and a guide fixture exported by the same server (`<channel id="nbc">`, `<channel id="6.1">`, `<channel id="6000">`, each with `<display-name>`, `<lcn>` and `<icon>`, and programmes on each)
When the guide is parsed with `XMLTVParser` and the playlist with `channels(fromPlaylist:)`
Then every key of `channelNames` equals the `epgID` of exactly one channel, `<lcn>` and `<icon>` are ignored without error (0002/AC-9), and every programme's `channelID` is one of those keys, so 0014's join by `GuideKey` needs no manual mapping.

## Edge cases and failure modes

- Offline versus server down: the device being offline (`.offline`) and the server not answering (`.unreachable`) are different states with different copy; a LAN server is often reachable while the internet is not, and the reverse. There is no reachability pre-check; both come from the `URLError` of the status request (as 0014).
- Local network permission denied (iOS, iPadOS, macOS): the first request to a private address fails with a `URLError` whose code varies by OS release (`.notConnectedToInternet` is common, which maps to `.offline`); 0006's Settings hint therefore keys on the host, not the error case (Required of other specs). The code mapping is verified on device before the implementing PR. tvOS has no prompt.
- Redirects are followed by `URLSession`'s default, so a proxy that upgrades `http` to `https` works and a `*.u.channelsdvr.net` login redirect ends as the AC-5 HTML case; a 3xx that is not followed surfaces as `.httpStatus(3xx)`. "One GET to `statusURL()`" in AC-5 and AC-12 means the request as issued, before redirects.
- NAS asleep: `/status` times out after 10 s (AC-6) and the source fails with `.unreachable(.timedOut)`; the next load retries. No backoff in this spec.
- Server restarting: `booted: false` is `.starting`; the loader treats it as a failed load for this attempt and 0010's Retry runs it again.
- Prerelease builds (`prerelease: true`) are accepted; `subscription` is decoded and reported, never gated on, because the lineup export works whether or not the DVR subscription is active (open question).
- Version text that does not parse is accepted (AC-5), so a future version scheme does not lock users out. `/status` is an identity check, not a version gate.
- Remote `*.u.channelsdvr.net` URLs without the `session` token answer 401 or redirect to a login page; the first is `.unauthorized`, the second is a 200 HTML body and therefore `.notAChannelsServer` on status and `.malformed` on the playlist. Both are reported as what they are; the token itself is out of scope.
- Reverse proxy with Basic auth: the header is sent on status, playlist and guide (0014 row). Stream URLs in the playlist point at the same proxy, so playback needs the header too (Required of other specs). Until the playback spec adds it, 0006 does not show the Remote access fields, so no source of this kind has a credential and nothing lists channels it cannot play.
- The guide URL is derived, so `SourceRecord.epgURL` set by hand still wins per 0014/AC-1's first row; a user can point the guide elsewhere.
- Seven days of guide for a 400-channel lineup is a few tens of megabytes of XML; 0014/AC-20's limits apply and a server that exceeds them fails with `.tooLarge` on the guide only; channels still load.
- Huge lineups: Channels lineups are hundreds to a few thousand channels; the mapping pass is linear and AC-16 bounds it at the 50 000 scale the other specs use.
- Malformed `tvg-chno` ("6.", "6.1.2", "abc"): `number` and `minorNumber` follow the 0001 revision's rules; this spec asserts only the integer and one-dot cases (AC-8).
- Duplicate `tvg-id` within one lineup (the same station on two sources that Channels did not merge): equal ids, both listed by 0013/AC-11a, favorites resolve to the first in All channels order (0013/AC-8).
- Two servers added as two sources: ids are equal across them when the lineups match; 0013's `RowKey` includes `sourceID`, so rows stay distinct.
- Older app build receiving a record of this kind through CloudKit: `kindRaw` "channelsdvr" falls back to `.m3u` (0004 edge case) and fetches the base URL, which yields HTML and zero channels. Nothing crashes and the credential is not read.
- Credential not yet synced from iCloud Keychain: AC-13, with 0010/AC-18 copy. On tvOS, Keychain items do not sync (0006's open ADR); 0006/AC-21's sign-in step covers this kind (Required of other specs).
- First launch with an empty store: nothing here runs; 0006 shows onboarding.
- Secrets: the client never logs a URL or a header; errors carry status codes and `URLError.Code` only (AC-15). Playlist and status URLs carry no secret in this spec, so 0014/AC-15 redaction is not needed for them but still applies where the app logs any URL.

## Test plan

Fixtures under `Tests/AntennaCoreTests/Fixtures/ChannelsDVR/`: `channels.m3u` (channel-id mode, 412 entries), `channels-numbers.m3u` (number mode with `6.1`), `status.json`, `status-not-booted.json`, `status-prerelease.json`, `login.html`, `guide.xml`. Network behaviour uses a `URLProtocol` stub registered on an injected `URLSession`, as 0003 and 0016 do. No test opens a socket.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (parameterised over the rows) | TBD |
| AC-2 | core | TBD |
| AC-3 | core (`decodeStatus`, fixtures) | TBD |
| AC-3a | core (parameterised) | TBD |
| AC-4 | core (parameterised) | TBD |
| AC-5 | core (`URLProtocol` stub, parameterised over the rows) | TBD |
| AC-5a | core (`URLProtocol` stub, task cancelled) | TBD |
| AC-6 | core (`URLProtocol` stub recording requests) | TBD |
| AC-6a | core (parameterised) | TBD |
| AC-6b | core (`URLProtocol` stub recording requests) | TBD |
| AC-7 | core (fixture) | TBD |
| AC-8 | core (fixture; after the 0001 revision) | TBD |
| AC-9 | core (two generated playlists) | TBD |
| AC-10 | core (after the 0001 revision) | TBD |
| AC-11 | core (parameterised) | TBD |
| AC-12 | core (`URLProtocol` stub, parameterised over the rows) | TBD |
| AC-13 | integration (fake `CredentialStore`, stubbed session; after 0004's loader seam) | TBD |
| AC-14 | integration (stubbed session, fake `GuideStore` recording calls) | TBD |
| AC-15 | core (parameterised) | TBD |
| AC-16 | core benchmark (`channels(mapping:)`), `ANTENNA_BENCHMARKS=1` | TBD |
| AC-17 | core | TBD |
| AC-19 | core (both fixtures) | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Stream format: AC-2 asks for `format=hls&codec=copy`, the server's default remux, because `AVPlayer` plays it today with HDR and the ADR-0001 demuxer does not exist yet. When the demuxer ships, `format=ts` gives the raw MPEG-TS the ADR prefers; one query parameter either way, and a revision of AC-2.
- Guide path: the brief and the Channels web admin show `/devices/ANY/guide/xmltv.xml`; forum posts use `/devices/ANY/guide/xmltv` with the same `duration` parameter. The implementing PR confirms against a live server; AC-2 changes if `.xml` is wrong.
- Minimum server version: dropped from this spec because no value could be set without a server to test against. If a minimum turns out to matter (the `channel-id` attribute and the `format` parameter both predate 2021), `ChannelsDVRVersion` is already `Comparable` and AC-5 gains a row.
- `guideDuration` of 7 days matches what Channels users pass to TiviMate. Channels serves up to its own guide horizon (about 14 days); longer costs download size under 0014/AC-20.
- Subscription state: the spec never gates on `subscription`. If the lineup export turns out to need an active DVR subscription, AC-5 gains a row and 0006 gains copy.
- The `session` token for `*.u.channelsdvr.net`: it is a secret, so it would be a Keychain item like the password, sent as a `session` query item or `Cookie` header. Deferred until the owner has a remote server to test; remote users can use a reverse proxy with Basic auth, a VPN or Tailscale meanwhile.
- Name precedence (AC-10) and `minorNumber` (AC-8) change 0001; an alternative is to leave 0001 alone and have Channels users see call signs and lose `6.1` channels, which is what every plain M3U player does today.
- How a tvOS user enters a minor number: the Siri Remote has no digit keys and 0008's hardware-keyboard entry has no dot. Proposed for 0008: "6" matches 6, then 6.1, 6.2 on repeated select, or a dot key when a keyboard has one.
- Ids keyed on `tvg-id` (AC-9) break favorites when the user toggles Channels' "use channel ids in M3U" option, because `tvg-id` flips between "nbc" and "6000". Keying on `tvg-chno` instead breaks on renumbering. `tvg-id` was chosen because it is what the guide keys on and what the option is for.
- Whether a new `SourceKind` case deserves an ADR despite leaving the schema unchanged. This spec says no.

## Dropped

- AC-18 (streams take the MPEG-TS route): removed in review round one. It only re-tested `EngineRouter`'s default branch, and the stream format moved to HLS (AC-2) so that Channels DVR sources play on the `AVPlayer` path that exists today.
