# Design

## Context

Boards: none, no UI. The add-source form, the loading checklist and the sources list belong to `add-first-run-onboarding` and `add-sources-and-settings`.

Design-system requirements that apply: none.

## Goals / Non-Goals

**Goals:**
- A Channels DVR source kind in AntennaCore that tidies one address, checks status, maps the lineup and points the guide at the server.

**Non-Goals:**
- Recordings, server discovery, and Channels DVR's own remote-access key.
- Sending the proxy password with stream requests. Until playback does, the form hides the username and password fields, so no source is listed that cannot play.

## Decisions

- Address rules, outcome tables, errors and their wording, the type sketch and what other capabilities change are in the sections below.
- Addresses: `/devices/ANY/channels.m3u?format=hls&codec=copy`, `/devices/ANY/guide/xmltv.xml?duration=604800` and `/status`. Default port 8089. HLS plays through `AVPlayer`, so Channels DVR sources play on the path that exists today. Raw MPEG-TS would need the FFmpeg demux path, which does not exist yet.
- Ids are `channelsdvr#id#<tvg-id>`, else `channelsdvr#no#<tvg-chno>`, else `channelsdvr#pos#<n>`. Keying on `tvg-id` matches the guide. It breaks favorites if the user flips Channels DVR's "use channel ids in M3U" option.
- Other capabilities change too: `m3u-playlists`, `channel-catalogue`, `guide-data`, `source-management`, `add-first-run-onboarding`, `add-live-tv-on-iphone-ipad-mac` and `project.yml`. The list is under Changes other capabilities need.
- No new decision is needed. The new kind is a new string in the existing `kindRaw` column, so the synced schema does not change. The proxy password goes to the synchronizable iCloud Keychain like every other secret, never into SwiftData, and the record holds only its credential key.
- Requests keep no cookies and no cache. The status request times out after 10 s and the lineup after 30 s.
- The status check never refuses a server for its version or subscription text. A version that does not parse is still accepted.
- Cancellation throws `CancellationError`, not a Channels DVR error.
- Benchmark under `ANTENNA_BENCHMARKS=1`: mapping 50 000 lineup entries under 200 ms in a debug run.
- No requirement checks that streams take the MPEG-TS route. It would only re-test the router's default branch, and streams are HLS.

## Addresses

`ChannelsDVRClient.serverURL(from:)` trims whitespace, prepends `http://` when no scheme is present, appends port 8089 only when the text had neither a scheme nor a port, lowercases the host, and removes query, fragment and a trailing slash. A path is kept. An IPv6 literal is accepted only in brackets. Another scheme, an empty or missing host, or any userinfo gives nil, so a password typed into the address never reaches the synced record.

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
| empty | nil |

Endpoints follow the server URL and its path. For `http://nas.local:8089` they are `http://nas.local:8089/devices/ANY/channels.m3u?format=hls&codec=copy`, `http://nas.local:8089/devices/ANY/guide/xmltv.xml?duration=604800` and `http://nas.local:8089/status`. For `https://home.example.net/channels` the playlist is `https://home.example.net/channels/devices/ANY/channels.m3u?format=hls&codec=copy`. `duration` equals `guideDuration`, and building a URL issues no request.

## Status and lineup outcomes

A status body counts only when it is a JSON object with a string `version`. `{"version":"2022.08.16.2108","prerelease":true,"booted":true,"subscription":"active"}` decodes to `versionText` "2022.08.16.2108", `version` (2022, 8, 16, 2108) and the three flags. `{"version":"2025.03.01.0012"}` leaves the flags nil. `2025.03.01.0012-dev` keeps the full text and parses the leading number groups. `custom` keeps the text with `version` nil. `{}`, `[]`, a bare string, `{"ver":"1"}`, `{"version":123}`, HTML and an empty body are not a Channels DVR server.

`ChannelsDVRVersion(parsing:)` reads `yyyy.MM.dd.HHmm`, needs at least three leading number groups, and compares each component as a number, never as text. "2023.1.1", "2023.01.01" and "2023.01.01.0000" are equal.

`status()` issues one GET to the status URL. For a 200 body the checks run in this order and the first that applies wins: not a Channels DVR server, then starting.

| Status response | Outcome |
|-----------------|---------|
| 200, full status body | returns the status |
| 200, the same with `"booted":false` | `.starting` |
| 200, version text that does not parse | returns the status |
| 200, HTML, `{}` or `{"booted":false}` without `version` | `.notAChannelsServer` |
| 404 | `.notAChannelsServer` |
| 401 or 403 | `.unauthorized` |
| 500, 502, 503 | `.httpStatus(n)` |
| `URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` | `.offline` |
| `URLError` `.cannotConnectToHost`, `.cannotFindHost`, `.timedOut`, `.dnsLookupFailed` | `.unreachable(code)` |
| any other `URLError` | `.transport(code)` |
| not an `HTTPURLResponse` | `.httpStatus(-1)` |

`channels()` issues one GET to the playlist URL and no status request. A body is a playlist when its first non-whitespace text after an optional BOM starts with `#EXTM3U`. `#EXTM3U` alone gives zero channels and no error.

| Lineup response | Outcome |
|-----------------|---------|
| 200, a playlist | its channels |
| 200, HTML or an empty body | `.malformed` |
| 401 or 403 | `.unauthorized` |
| 404 | `.httpStatus(404)`; only `status()` judges "not a server" |
| 500, 502, 503 | `.httpStatus(n)` |
| `URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` | `.offline` |
| `URLError` `.cannotConnectToHost`, `.cannotFindHost`, `.timedOut`, `.dnsLookupFailed` | `.unreachable(code)` |
| any other `URLError`, `.secureConnectionFailed` and `.badServerResponse` among them | `.transport(code)` |
| not an `HTTPURLResponse` | `.httpStatus(-1)` |

Loader order per source: no Keychain read when `credentialKey` is nil; a credential absent on this device returns `.waitingForCredential` with no request; a failed Keychain read throws `.credentialUnreadable` with no request. Then one status request, then one playlist request. A failed status stops that source, which makes no playlist request and no guide call. The loader never registers guide URLs for this kind, because `guide-data` resolves the guide from the source.

Redirects follow `URLSession`'s default, so an `http` to `https` upgrade works and a remote-access login redirect ends as the HTML case.

## Errors and wording

`ChannelsDVRError` has `.offline`, `.unreachable(URLError.Code)`, `.transport(URLError.Code)`, `.notAChannelsServer`, `.starting`, `.unauthorized`, `.httpStatus(Int)`, `.malformed` and `.credentialUnreadable`. A missing credential is not an error. Cancellation throws `CancellationError`.

Wording `add-first-run-onboarding` shows for each:

| Case | Text |
|------|------|
| address `serverURL(from:)` turns down | "Enter a valid server address." |
| the same, when the text had a username or password | "Enter the username and password under Remote access, not in the address." |
| `.unreachable`, `.transport` | "Could not reach <host>. Check the address and try again." |
| `.offline` | "You're offline. Connect to the internet and try again." |
| `.httpStatus(n)` | "The server answered with an error (<status>). Check the address and try again." |
| `.malformed` | "The server replied with something Antenna could not read." |
| `.notAChannelsServer` | "No Channels DVR server at <host>." |
| `.starting` | "Channels DVR is starting. Try again in a moment." |
| `.unauthorized`, credential sent | "Could not sign in. Check the username and password." |
| `.unauthorized`, no credential sent | "This server asks for a username and password. Enter them under Remote access." |
| one Remote access field filled, the other empty | "Enter the <field name>." |

When the failure is `.offline` or `.unreachable` and the host is a private IPv4 address, an IPv6 link-local address or a `.local` name, iPhone, iPad and Mac add "Allow local network access for Antenna in Settings." The hint keys on the host because a refused local network permission often shows up as `.notConnectedToInternet`. The loading checklist has a "Server" row reading "Channels DVR <versionText>" and no login or movies row.

## Interface sketch

```swift
public enum SourceKind { case channelsDVR = "channelsdvr" }   // listed after .stalker

public struct HTTPBasicCredential: Sendable, Hashable {
    init?(username: String, password: String)   // nil for an empty username or one with a colon
}

public struct ChannelsDVRVersion: Sendable, Comparable {
    init(year: Int, month: Int, day: Int, build: Int)
    init?(parsing: String)                       // yyyy.MM.dd.HHmm
}

public struct ChannelsDVRStatus: Sendable, Hashable {
    var version: ChannelsDVRVersion?
    var versionText: String
    var prerelease: Bool?
    var booted: Bool?
    var subscription: String?
}

public struct ChannelsDVRClient: Sendable {
    static let defaultPort = 8089
    static let guideDuration = 604_800          // 7 days in seconds

    init(server: URL, credential: HTTPBasicCredential? = nil, session: URLSession = .shared)
    static func serverURL(from: String) -> URL?

    func playlistURL() -> URL
    func guideURL() -> URL
    func statusURL() -> URL

    func status() async throws -> ChannelsDVRStatus
    func channels() async throws -> [Channel]

    static func decodeStatus(_ data: Data) throws -> ChannelsDVRStatus
    static func channels(fromPlaylist: Data) throws -> [Channel]
    static func channels(mapping: Playlist) -> [Channel]
}
```

- `channels(fromPlaylist:)` applies the playlist header rule, decodes UTF-8 with replacement characters, runs the M3U parser with `nameSource: .title`, and hands the `Playlist` to `channels(mapping:)`, which assigns ids. `channels()` adds only the request.
- The source record holds the normalized server URL, no guide URL, and a `credentialKey` only when the user gave a proxy username and password.
- Every request carries `Authorization: Basic` with the Base64 of the UTF-8 `username:password`, a colon in the password kept. A client without a credential sends no `Authorization` header.
- The credential prints as the literal `HTTPBasicCredential`, and the client prints as its host name.

Mapping examples:

- `#EXTINF:-1 channel-id="nbc" tvg-id="nbc" tvg-chno="6000" tvg-logo="https://img.example/s28717.png?w=360&h=270" tvc-guide-stationid="20378" tvg-name="KGWDT" group-title="HD",NBC` gives id `channelsdvr#id#nbc`, name "NBC", number 6000, `epgID` "nbc", group "HD", and the logo as written.
- `tvg-id="6.1" tvg-chno="6.1"` gives id `channelsdvr#id#6.1`, number 6, minor number 1, `epgID` "6.1".
- Without `tvg-id`, `tvg-chno="4"` gives `channelsdvr#no#4` and `tvg-chno="6.1"` gives `channelsdvr#no#6.1`. With neither attribute the id is `channelsdvr#pos#<n>`, the 1-based index among emitted entries.
- Two entries sharing a `tvg-id` keep the same id and both are listed.
- Names: the title after the comma, `tvg-name` only when the title is empty, and "" when both are empty. No entry is skipped for an empty name.

## Changes other capabilities need

- `m3u-playlists`: the parser gains `nameSource` with `.tvgName` (today's behavior, the default) and `.title` (the text after the comma wins, `tvg-name` only when the title is empty). `Channel` gains `minorNumber: Int?`, so `tvg-chno="6.1"` gives number 6 and minor number 1 instead of no number. Whole numbers are unchanged.
- `channel-catalogue`: `number(for:)` returns `ChannelNumber(major: Int, minor: Int?)`, whose `description` is "6.1" with a minor number and "6000" without. Ordering compares `(major, minor)` with a nil minor before 0. Number entry keeps its `String` input and treats the typed number as the major number, so "6" matches 6, then 6.1, 6.2 in minor order. The 1 to 99,999 ceiling applies to the major number only. Every screen that shows a number uses `ChannelNumber.description`.
- `guide-data`: the resolver gains the row "Channels DVR without a guide address: `guideURL()` built from the source URL". The download carries the source's `Authorization: Basic` header when it has a credential, and a 401 or 403 maps to unauthorized as for Xtream. With a `credentialKey` and no readable item there is no request, and the guide reports the credential as missing or unreadable.
- `source-management`: `SourceLoader.load` returns `SourceLoadResult`, either `.loaded([Channel])` or `.waitingForCredential`, and throws on failure. M3U and Xtream keep their behavior through the new type. For this kind `serverURL(from:)` replaces the URL scheme check and the record stores the normalized URL. An older build that does not know `channelsdvr` falls back to M3U, fetches the server base URL, gets HTML and lists no channels without reading the credential.
- `add-first-run-onboarding`: a "Channels DVR" type card with a required Server field (URL keyboard on every platform) and, under "Remote access", Username and Password. The Remote access fields stay hidden until playback sends per-source headers, so until then `credentialKey` is always nil for this kind. Both fields empty means no credential. The duplicate check compares normalized URLs. Wording and the local network hint are under Errors and wording. The Apple TV sign-in step covers every source that needs a credential (Xtream, or this kind with a `credentialKey`). For this kind it shows Server prefilled and Username and Password empty, and Connect runs the status check and the lineup download before writing the Keychain item.
- `add-live-tv-on-iphone-ipad-mac`: `.unreachable` counts as a failed source and never shows the offline text, which stays for `.offline`. `.waitingForCredential` is the waiting-for-credential state it already renders.
- `project.yml`: `NSLocalNetworkUsageDescription` on the Antenna target, "Antenna connects to your Channels DVR server on your home network." Apple TV shows no prompt and needs no key.
- Playback: the engine accepts per-source HTTP headers, because stream URLs in the lineup point at the same server and a reverse proxy with Basic auth turns them down without the header.

## Risks / Trade-offs

- Open question: ask the server for raw MPEG-TS once the FFmpeg demux path for raw MPEG-TS exists, instead of HLS? `format=ts` would ask for it. Can be decided at implementation; one setting either way.
- Open question: is the guide path `/devices/ANY/guide/xmltv.xml` or `/devices/ANY/guide/xmltv`? Can be decided at implementation against a live server.
- Open question: how a tvOS user types a number like 6.1 with the remote. Decided in `add-tv-zap-bar-and-number-entry`.
- Open question: does the lineup export need an active Channels DVR subscription? If so, the Connect requirement gains a case and onboarding gains wording.
- Open question: Channels DVR's own remote-access sign-in key, deferred until the owner has a remote server to test.
- [Local network permission refused on iPhone, iPad or Mac] → the first request to a home address fails, often looking like "offline", so onboarding adds a hint to allow local network access whenever the address is a home one. Apple TV asks no such permission.
- [The proxy password never syncs to Apple TV] → onboarding's Apple TV sign-in step must accept Channels DVR sources, or the source waits for its credential forever.
