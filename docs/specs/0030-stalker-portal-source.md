# 0030. Stalker portal source: handshake, channels and guide

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0005
- ADR needed (precondition): a resolution step in the playback path for sources whose stream URL is minted at tune time. Stalker's `create_link` is the first such source; catch-up and timeshift URLs will be the next. The criteria below assume the likely outcome: `Channel.streamURL` holds a `stalker://` reference and the app resolves it through `StalkerClient.playableURL(for:)` before `EngineRouter` (AC-16, AC-17). That ADR must be Accepted before this spec moves to Accepted, because a `stalker://` URL reaching today's `EngineRouter.route(for:)` would go to `.demuxer`.
- ADR needed: AntennaCore imports `CryptoKit` for the MD5 and SHA-256 device identity of AC-4, which portals bind to the MAC on first login and which must match what StbEmu and TiviMate send for the same MAC. ADR-0005 says "imports Foundation only"; a superseding ADR widens that to Foundation and CryptoKit, or AC-4 changes to a Foundation-only derivation and gives up compatibility with portals that lock the device id.
- Blocked on: both ADRs above. AC-4, AC-16 and AC-17 cannot be implemented until they are Accepted; every other criterion can.
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, plus the app-layer Keychain mapping of AC-25; no UI)
- Builds on specs 0003 and 0016 (the Xtream client is the pattern: tolerant decoding, typed errors, request-shape tests over a `URLProtocol` stub), 0004 (source storage, `SourceKind.stalker`, 0004/AC-13), 0013 (catalogue input), 0014 (guide source). Supersedes 0004/AC-13 (Stalker is no longer inert) and 0006/AC-3's disabled Stalker card. Resolves 0004's open question "Should the Stalker option be hidden until the portal handshake ships?": it ships here.
- Type names: `StalkerClient.StalkerError` and `StalkerClient.DecodedList` are nested as 0016 nests `XtreamError` and `DecodedList`; this spec writes them without the prefix. `StalkerCredentials`, `StalkerDevice`, `StalkerChannel`, `StalkerGenre`, `StalkerProfile`, `StalkerAccountInfo`, `StalkerStreamReference`, `DecodedEPG` and `MACAddress` are top-level types in AntennaCore like `XtreamLiveStream`. `StalkerClient.init` takes `StalkerCredentials`, a `URLSession`, a clock and a `TimeZone` and nothing else; it has no store to write to (ADR-0005).

## Design

Boards: none, no UI. The add-source form fields this spec needs are listed under "Required of other specs"; 0006 and 0023 own the screens and their boards (`TV-Onboard-3-Stalker.dc.html`, `iPhone-Onboard-2-Stalker.dc.html`).
Design rules that apply: none here. DR-8, DR-11 and DR-15 apply to the specs that render Stalker channels and the form.

## Problem

A Stalker (Ministra) portal is addressed by a portal URL and a MAC address, not by a playlist URL or a username. Antenna can save such a source today (0004/AC-13) but loads nothing from it, so a user whose provider only offers a portal sees an empty app after paying (ADR-0006). Portals also mint stream URLs per tune with a short-lived token, so the Xtream pattern of building a URL from stored credentials does not carry over.

## Scope

In:
- `MACAddress`: parsing, normalisation and validation of the user's MAC (AC-1).
- Portal URL normalisation and endpoint discovery: `/stalker_portal/server/load.php`, `/server/load.php`, `/portal.php` (AC-2, AC-3).
- `StalkerCredentials` (portal URL, MAC, optional login and password) and `StalkerDevice`, the fixed MAG250 identity every request carries (AC-4).
- `actor StalkerClient` with: `sessionConfiguration()` (static), `handshake()`, `profile()`, `accountInfo()`, `genres()`, `allChannels()`, `playableURL(for:)`, `epgRequest(period:)`, `invalidateToken()`, `logoBase`; the token held in memory only, one in-flight handshake shared by concurrent calls (AC-5 to AC-9a, AC-16, AC-22).
- Token refresh: one re-handshake and retry when the portal rejects the token, and the same path on `invalidateToken()` for callers that fetch with their own session (AC-10, AC-10a, AC-11, AC-11a).
- Decoding exposed as pure static functions over `Data`: `decodeHandshake`, `decodeProfile`, `decodeAccountInfo`, `decodeGenres(_:)`, `decodeChannels(_:host:)`, `decodeLink(_:)`, `decodeEPG(_:epgIDs:)` (AC-12 to AC-15, AC-18, AC-23, AC-24).
- Mapping to `Channel` with ids `stalker#<host>#<id>`, group names from genres, and `groupOrder(for:)` for 0013 (AC-14, AC-15).
- `StalkerStreamReference`: the `stalker://` URL placed in `Channel.streamURL` and parsed back at tune time (AC-16).
- `StalkerError` mirroring `XtreamError`, and redaction of MAC, token, login, password and derived device ids in every error and description (AC-19, AC-20, AC-21).
- The app-layer mapping from a `CredentialStore.Credential` to `StalkerCredentials`, including the `login` field the Keychain payload gains (AC-25).
- A decoding benchmark for a portal with 50 000 channels (AC-26).

Out (explicitly):
- Any UI. The form fields, their copy and the loading-checklist rows are 0006 (onboarding) and 0023 (sources and settings).
- Fetching, scheduling, progress and size limits for the guide: 0014. This spec provides the request and the decoder only.
- Paged channel lists (`get_ordered_list`, `get_fav`, `set_fav`): a 0030 follow-up, if a portal that truncates `get_all_channels` is found.
- VOD, series and radio (`type=vod`, `type=series`, `type=radio`): a later Stalker VOD spec, paired with 0011.
- Catch-up and timeshift (`get_simple_data_table` archive rows, `create_link` with an archive `cmd`): the catch-up spec that also covers Xtream timeshift.
- Recording (`allow_pvr`), parental lock (`censored`), server messages (`get_events`, `send_log`).
- Playback of the resolved URL: ADR-0001 and the playback spec.
- The "credential not yet synced" screens: 0010/AC-18, 0010/AC-24, 0015/AC-11 and 0006/AC-21 already cover a source whose Keychain item is absent, and apply unchanged.
- A custom serial number or device id per source (StbEmu lets users type them). AC-4 always derives both from the MAC; a later 0030 follow-up adds overrides if users with bound custom ids report it.
- Re-resolving a link whose token expires during playback: the playback spec, which calls `playableURL(for:)` again on a stream error.
- Hidden Xtream behind a portal: some providers expose both. The user adds whichever they hold; no detection.

Required of other specs:
- 0006: enable the Stalker card and segment (supersedes 0006/AC-3) and add a details form `AC-4c` with Name (optional), Portal URL, MAC address, Login (optional), Password (optional, with `onboarding.field.showPassword`), identifiers `onboarding.field.portal`, `onboarding.field.mac`, `onboarding.field.login`, `onboarding.field.password`. The MAC field uses an ASCII-capable keyboard, no autocorrection, and accepts the forms AC-1 accepts, so a user on tvOS can type twelve hex digits without separators; the field does not insert colons as the user types, and Connect stores the AC-1 `description` form. Connect runs `handshake()` then `profile()` (then `accountInfo()` for the signed-in row) before saving, as 0006/AC-9 does for Xtream. Error copy for `StalkerError`: `.portalNotFound` reads "Could not find a portal at <host>. Check the address and try again."; `.unauthorized` and `.deviceRefused` read "The portal did not accept this device." followed by the portal's redacted message when there is one; `.transport`, `.badStatus` and `.decoding` map to 0006/AC-8, AC-23, AC-29 and AC-33 unchanged. Malformed MAC: `onboarding.error` reads "Enter a MAC address like 00:1A:79:12:34:56." The checklist login row for Stalker reads "Connected" with "Account active until <date>" from `StalkerAccountInfo.expiresAt` when non-nil, formatted as a date only in `TimeZone(identifier: "UTC")` so a date-only `end_date` never shows the day before (AC-18). 0006/AC-21 (Sign in on this Apple TV) covers Stalker records with Portal URL prefilled and MAC, Login and Password empty.
- 0023: the same fields in the edit-source form, and the Stalker row in the sources list shows the portal host, never the MAC.
- 0014: add a Stalker row to AC-1: "Stalker without `epgURL`: the portal's own guide through `StalkerClient.epgRequest(period:)` and `decodeEPG(_:epgIDs:)`, fetched with `URLSession.bytes(for: URLRequest)`". `GuideDecoder`'s XML sniff is skipped for that path; the size limits of 0014/AC-20 and the error mapping of 0014/AC-12 apply. Because 0014 fetches with its own session, AC-10's retry does not run for it: on 401, 403 or a body that is exactly `Authorization failed.`, 0014 calls `StalkerClient.invalidateToken()` (AC-11a) and requests `epgRequest(period:)` once more; a second rejection is `GuideError.unauthorized`. The 0014 edge case "A Stalker source with `epgURL` set still downloads its guide; every programme is unmatched" no longer holds once AC-15 sets `epgID`.
- 0004 (on main): AC-13 must be marked superseded by 0030 in a follow-up PR to 0004; this PR does not edit it. The loader calls `StalkerClient.allChannels()` and `genres()` for `.stalker` sources, maps the result through AC-14 and AC-15 with the client's `logoBase`, and passes `groupOrder(for:)` to 0013 as it does for Xtream categories. A Keychain item whose `username` AC-1 rejects, or whose mapping of AC-25 yields nil, is 0004/AC-10's credential-less case. 0004/AC-13 is superseded.
- App layer: `CredentialStore.Credential` gains `login: String?` with a default of nil, so items saved before this spec decode unchanged, and `Credential.stalkerCredentials(portal:)` is the one place a Keychain item becomes `StalkerCredentials` (AC-25). The app holds one `StalkerClient` per `SourceRecord.id` for the life of the process and hands that instance to the loader, the guide store and the playback resolver, so two instances never invalidate each other's token. The Keychain item reuses `username` for the MAC (AC-25).
- 0001 follow-up (the spec that owns `Channel` and already plans to hash `streamURL` out of `Channel.id`, per 0013's header): `Channel` gains `CustomStringConvertible`, `CustomDebugStringConvertible` and `CustomReflectable` that print `streamURL` as scheme and host only, so `String(reflecting:)` or `dump` of a Stalker channel never shows its `cmd` or MAC. `Channel` is never persisted; `FavoriteRecord` stores `channelID` only. Until that lands, app code must not log a `Channel` value.
- 0016: hoist `DecodedList<T>` to a top-level AntennaCore type so this spec reuses it. Until then `StalkerClient.DecodedList` is a separate generic with the same `items` and `skipped`.
- Playback spec: before `EngineRouter.route(for:)`, a `streamURL` whose scheme is `stalker` goes through `StalkerClient.playableURL(for:)` on the client chosen by `Channel.sourceID` (0013/AC-1), never by the reference's host; the resolved URL is routed, held for that one tune and never stored or logged in the clear (it carries a token). A reference that fails to resolve, including `notAStalkerChannel`, is a playback failure shown as the playback spec's generic failure state, not a routing fallback to `.demuxer`. Zapping away cancels the task running `playableURL(for:)` (AC-9a).

## User flow

1. The user picks Stalker portal in the add-source form (0006 or 0023) and enters the portal URL from the provider, the MAC address the provider registered, and, when the portal asks for one, a login and password.
2. Connect handshakes with the portal and reads the profile. A refused device or an unreachable portal shows under the form; nothing is saved.
3. On success the source is saved. The MAC, login and password go to the Keychain; the portal URL goes to `SourceRecord.url`.
4. The loader fetches genres and channels, and channels appear in the catalogue grouped by genre, numbered by the portal's numbers.
5. Tuning a channel asks the portal for a link, which carries a short-lived token. The link plays through the engine ADR-0001 chooses.
6. The guide (0014) reads the portal's EPG for the next days.
7. On another device the source arrives through CloudKit and its credential through iCloud Keychain; until the credential arrives the source waits, as 0010/AC-18 describes.

## Wire detail

Portals speak one GET endpoint. Every request has `type` and `action` query items, ends with `JsHttpRequest=1-xml`, and answers JSON whose payload is under the key `js`. The headers below are what every MAG box sends; portals reject requests without them.

| Header | Value |
|--------|-------|
| `Cookie` | `mac=<MAC with ":" as %3A>; stb_lang=en; timezone=<TimeZone identifier>` |
| `User-Agent` | `Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3` |
| `X-User-Agent` | `Model: MAG250; Link: Ethernet` |
| `Referer` | `<normalised portal URL>/c/` |
| `Authorization` | `Bearer <token>`, on every request after the handshake |

| Call | Query items in order (before `JsHttpRequest=1-xml`) |
|------|-------------------------------------------------------|
| `handshake()` | `type=stb`, `action=handshake`, `token=` (empty) |
| `authorize()` (only when `login` is non-nil) | `type=stb`, `action=do_auth`, `login`, `password`, `device_id`, `device_id2` |
| `profile()` | `type=stb`, `action=get_profile`, `hd=1`, `ver`, `num_banks=2`, `sn`, `stb_type=MAG250`, `client_type=STB`, `image_version=218`, `video_out=hdmi`, `device_id`, `device_id2`, `signature`, `auth_second_step=1`, `hw_version=1.7-BD-00`, `not_valid_token=0`, `metrics`, `hw_version_2`, `timestamp`, `api_signature=262`, `prehash=` |
| `accountInfo()` | `type=account_info`, `action=get_main_info` |
| `genres()` | `type=itv`, `action=get_genres` |
| `allChannels()` | `type=itv`, `action=get_all_channels` |
| `playableURL(for:)` | `type=itv`, `action=create_link`, `cmd=<cmd>`, `series=`, `forced_storage=`, `disable_ad=0`, `download=0`, `force_ch_link_check=0` |
| `epgRequest(period:)` | `type=itv`, `action=get_epg_info`, `period=<hours>` |

The fixed values are constants on `StalkerDevice.mag250`. `ver` is the literal `ImageDescription: 0.2.18-r14-pub-250; ImageDate: Fri Jan 15 15:20:44 EET 2016; PORTAL version: 5.6.1; API Version: JS API version: 328; STB API version: 134; Player Engine version: 0x566`. `metrics` is the JSON string `{"mac":"<MAC>","sn":"<sn>","type":"STB","model":"MAG250","uid":"","random":"<random from the handshake, or "" when absent>"}` with no whitespace. `sn`, `device_id`, `device_id2`, `hw_version_2` and `signature` are derived from the MAC (AC-4). Every query value is percent-encoded with the RFC 3986 unreserved set as the only characters left bare (0016/AC-1), so `ver` and `metrics` arrive with their spaces, quotes, braces and `;` encoded. Request-shape tests compare the decoded `URLComponents.queryItems` in order, except where a criterion quotes the encoded form. Requests carry the MAC by design, in the cookie and in `metrics`; the redaction criteria (AC-20, AC-21) are about errors, descriptions and messages, never about the wire.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 MAC address parsing
Given the strings `00:1A:79:12:34:56`, `00-1a-79-12-34-56`, `001a79123456`, ` 00:1A:79:12:34:56 `, `00:1A:79:12:34`, `00:1A:79:12:34:5G`, `00:1A:79:12:34:56:78` and `""`
When `MACAddress(parsing:)` runs
Then the first four yield a value whose `description` is `00:1A:79:12:34:56` and whose `cookieValue` is `00%3A1A%3A79%3A12%3A34%3A56`; the last four yield nil. Separators `:` and `-` are accepted only when all five are the same character; hex digits are case-insensitive; surrounding whitespace is trimmed. No OUI prefix is required.

### AC-2 Portal URL normalisation
Given the strings `http://p.example/c/`, `http://p.example/c`, `http://p.example:8080/stalker_portal/c/`, `HTTP://P.Example/`, `http://p.example`, `http://[::1]:8080/c/`, `p.example/c/`, `ftp://p.example/c/` and `http:///c/`
When `StalkerCredentials.normalisedPortal(_:)` runs
Then the first six yield `http://p.example`, `http://p.example`, `http://p.example:8080/stalker_portal`, `http://p.example`, `http://p.example` and `http://[::1]:8080`; the last three yield nil, so a string without a scheme is rejected, not defaulted to `http`. The rule: trim whitespace, require scheme `http` or `https` (lowercased) and a non-empty host (lowercased), drop a trailing `/c` or `/c/` path segment and any trailing slash, keep every other path segment, port and nothing else (no query, fragment or userinfo). The normalised URL is what Connect stores in `SourceRecord.url` and what `StalkerCredentials.portal` holds, so the sources list shows `p.example`; a string this rule rejects is 0004/AC-1's "Enter a valid URL."

### AC-3 Endpoint discovery
Given a normalised portal URL P and a stub session
When `handshake()` runs
Then the candidates are tried in order and the first that answers 2xx with a body `decodeHandshake` accepts becomes the endpoint for every later call of that client instance: if P's last path segment is `stalker_portal`, `P/server/load.php` only; otherwise `P/stalker_portal/server/load.php`, `P/server/load.php`, `P/portal.php`. A candidate that answers non-2xx, a body that is not JSON, or JSON without a non-empty `js.token` moves to the next; when every candidate fails, AC-3a picks the error. A `URLError` on any candidate throws `.transport(code)` at once (AC-19). A 2xx HTML page on every candidate is `portalNotFound`.

### AC-3a Discovery against a failing server
Given a stub where no candidate answers with an accepted handshake, parameterised over status sets (all 404; 404, 503, 404; 401, 404, 404; 2xx `{"js":{"token":""}}` on all; 2xx HTML on all)
When `handshake()` runs
Then the error is chosen in this order: when at least one candidate answered 5xx, `StalkerError.badStatus(n)` with the last 5xx status seen, so an outage does not read as a wrong address; else when at least one answered 401 or 403 with a body that is not HTML, or 2xx JSON with an empty or absent `js.token`, `.unauthorized`, so an unregistered MAC reads as a refused device; else `portalNotFound`.
And when every candidate answers 2xx with HTML, the result is `portalNotFound`.

### AC-4 Device identity is derived from the MAC
Given `StalkerDevice.mag250` and the MAC `00:1A:79:12:34:56`
When `sn`, `deviceID` and `signature` are read
Then `sn` is `2213785DC6113` (the first 13 characters of the uppercase hex MD5 of the MAC's `description`), `deviceID` is `667094E7E8FF0347F6EC27A8E8115BE76E2AA9CD5C8F13C6FA00BCEDFAC02B41` (the uppercase hex SHA-256 of the same), `signature` is `922F69DECA50A1E4883CDB6AF9A57D86B2C82BE460AE9AFCAF2B421C715A0D1B` (the uppercase hex SHA-256 of `description + sn + deviceID + deviceID`), and the request items `sn`, `device_id`, `device_id2` and `hw_version_2` carry `sn`, `deviceID`, `deviceID` and `sn`. The test asserts these literal values only. That they match what StbEmu and TiviMate send is an assumption recorded under Open questions, to be checked against a real portal before Accepted.

### AC-5 Handshake request shape and headers
Given credentials for portal `http://p.example` with MAC `00:1A:79:12:34:56`, `login` nil, and time zone `Europe/Stockholm` injected
When `handshake()` runs against a stub whose first candidate answers
Then exactly one GET is issued to `http://p.example/stalker_portal/server/load.php?type=stb&action=handshake&token=&JsHttpRequest=1-xml`, with `Cookie` equal to `mac=00%3A1A%3A79%3A12%3A34%3A56; stb_lang=en; timezone=Europe/Stockholm`, `User-Agent` and `X-User-Agent` equal to the Wire detail values, `Referer` equal to `http://p.example/c/`, and no `Authorization` header. Public `handshake()` is the whole session setup: discovery (AC-3), the token, and `do_auth` when `login` is non-nil (AC-8). `profile()` is a separate call. Connect calls both; other callers call neither (AC-9).

### AC-5a Session configuration
Given `StalkerClient.sessionConfiguration()`, the static factory the app uses to build the `URLSession` it passes to `init` (tests add their `protocolClasses` to the same value)
When it is read
Then `httpShouldSetCookies` is false, `httpCookieAcceptPolicy` is `.never`, `urlCache` is nil, `requestCachePolicy` is `.reloadIgnoringLocalCacheData`, `timeoutIntervalForRequest` is 30 and `timeoutIntervalForResource` is 300, so a portal's `Set-Cookie` never rewrites the AC-5 `Cookie` header on a later request and a 50 000-channel list on a slow link has five minutes. The guide body is fetched by 0014 with its own session and limits, not this one.

### AC-5b Redirects keep the host
Given a stub that answers a client call with 301, 302, 307 or 308 and a `Location`
When the call runs
Then the redirect is followed only when the target's host and port equal the request's (a scheme change from `http` to `https` is allowed), with the same headers; a redirect to any other host or port is not followed and the call throws `badStatus(n)` with the 3xx status, so the MAC cookie and the token never reach another server. During discovery (AC-3) such a refused redirect moves to the next candidate. The client enforces this with a per-task `URLSessionTaskDelegate` passed to `session.data(for:delegate:)`, so it holds for any injected session; the test stub signals the redirect with `client?.urlProtocol(_:wasRedirectedTo:redirectResponse:)`.

### AC-6 Token is held and sent
Given a handshake that answered `{"js":{"token":"tok-1","random":"r"}}`
When `genres()` runs
Then the request carries `Authorization: Bearer tok-1`, `String(reflecting:)` of the client does not contain `tok-1`, and a second `genres()` call issues no handshake. The client has nowhere to persist the token: its initialiser takes `StalkerCredentials`, a `URLSession`, a clock and a `TimeZone` only, and a new instance built from the same credentials starts with a handshake (AC-9).

### AC-7 Profile request
Given a handshake that answered `{"js":{"token":"tok-1","random":"r-42"}}`, MAC `00:1A:79:12:34:56` and an injected clock reading 1 762 300 000
When `profile()` runs
Then exactly one GET is issued to the endpoint whose decoded query items are, in order, every item of the Wire detail row for `profile()` followed by `JsHttpRequest=1-xml`, with `timestamp=1762300000`, `sn`, `device_id`, `device_id2` and `hw_version_2` per AC-4 and `ver` equal to the Wire detail literal, and with the `Authorization` header of AC-6.

### AC-7a Profile metrics
Given the AC-7 setup, and a second handshake body without `random`
When `profile()` runs for each
Then the decoded `metrics` item equals `{"mac":"00:1A:79:12:34:56","sn":"2213785DC6113","type":"STB","model":"MAG250","uid":"","random":"r-42"}` byte for byte for the first, and the same with `"random":""` for the second.

### AC-8 Login step when the portal asks for one
Given credentials with `login` "alice" and `password` "a&b/c+d"
When `handshake()` runs
Then after the token GET it issues one GET for `do_auth` before returning, with `login=alice` and `password=a%26b%2Fc%2Bd` percent-encoded per RFC 3986 (as 0016/AC-1), `device_id` and `device_id2` per AC-4; a body `{"js":true}` lets `profile()` proceed; `{"js":false}`, `{"js":0}` or `{"js":{"error":...}}` throws `StalkerError.unauthorized`; with `login` nil no `do_auth` request is issued. `StalkerCredentials.init` treats a `login` that is empty or whitespace-only as nil and a nil `password` with a non-nil `login` as `""`, so that case sends `password=`; a `password` with a nil `login` is kept but never sent.

### AC-9 Any call handshakes first
Given a fresh client that has never handshaked
When `profile()`, `genres()`, `allChannels()`, `accountInfo()`, `playableURL(for:)` or `epgRequest(period:)` runs
Then the client issues the handshake (and `do_auth` per AC-8) and `profile()` first, then the requested call, so the stub sees the requests in that order and the caller never calls `handshake()` itself; a second call reuses the token and issues only its own request. Two calls started concurrently on a client with no token share one in-flight handshake: the stub sees exactly one handshake, one `profile`, then both requests in either order. The client holds a session that is profiled once `profile()` has succeeded on the current token, and clears it with the token: `profile()` on a fresh client issues handshake, [do_auth] and `get_profile`; `handshake()` then `genres()` issues `get_profile` once, before `get_genres`; Connect's `handshake()`, `profile()`, `accountInfo()` issues `get_profile` once.

### AC-9a Cancellation during a shared handshake
Given two calls waiting on one in-flight handshake, the first of which started it
When the first caller's task is cancelled before the handshake answers
Then the first throws `CancellationError`, the handshake still completes, and the second call returns its result; a cancelled `playableURL(for:)` throws `CancellationError` and issues no `create_link` after the cancellation is seen. When the shared handshake throws, every waiting call throws the same error and the next call starts a new handshake.

### AC-10 Token rejected once: re-handshake and retry
Given a client holding token `tok-1`
When a call other than `handshake` or `do_auth` is rejected, where a rejection is exactly one of: status 401, status 403, a 2xx body that is the text `Authorization failed.` (trailing whitespace allowed), or a 2xx JSON object whose root `js` is `null`, `""` or absent
Then the client issues one new handshake at the known endpoint (plus `do_auth` and `profile()` per AC-8 and AC-9), repeats the original request once with the new token, and returns that result; the stub sees exactly: original, handshake, [do_auth], profile, original again. Discovery (AC-3) never runs again on an instance that has an endpoint. A re-handshake that answers 401, 403 or a body without a token throws `StalkerError.unauthorized`; one that answers any other non-2xx throws `badStatus(n)`. `{"js":false}` is not a rejection; the decoders treat it as empty (AC-14b, AC-18, AC-23a). This is the only definition of a rejection; AC-24 refers to it.

### AC-10a Concurrent rejections share one re-handshake
Given two calls in flight that both carried `tok-1` and are both rejected
When they retry
Then the stub sees one re-handshake (plus [do_auth] and profile) and both repeated requests carry the new token. A call whose rejected token is no longer the client's current token skips the re-handshake and repeats with the current one.

### AC-11 Token rejected twice: unauthorised
Given the AC-10 sequence where the repeated request is rejected the same way
When the call runs
Then it throws `StalkerError.unauthorized`, no third attempt is issued, and the client's next call starts with a handshake again (the rejected token is discarded).

### AC-11a Invalidate on request
Given a client holding a token
When `invalidateToken()` runs and then any call of AC-9
Then the call starts with a handshake as a fresh client would, and a request built earlier by `epgRequest(period:)` still carries the old token (requests are values; the caller asks for a new one).

### AC-12 Handshake bodies decode
Given `{"js":{"token":"tok-1","random":"r","not_valid":0}}`, `{"js":{"token":"tok-1"}}`, `{"js":{"token":""}}`, `{"js":{}}`, `{"js":false}`, `[]` and `{}`
When `decodeHandshake(_:)` runs
Then the first two yield token `tok-1` (`random` "r" and nil); the others throw `StalkerError.decoding(path:)` with path `js.token` for the third and fourth, `js` for the fifth and seventh and `""` for the sixth.

### AC-12a Profile bodies decode
Given `{"js":{"id":12,"name":"stb","status":0,"msg":"","block_msg":"","expire_billing_date":"2027-01-31"}}`, the same with `status` as `"0"`, the same without `status`, the same with `status` 1 or `"1"` and `msg` "Your device is not registered", and the same with `status` 2, `msg` "x" and `block_msg` "Blocked"
When `decodeProfile(_:)` runs
Then the first three yield `StalkerProfile` with `status` 0; the fourth throws `StalkerError.deviceRefused(status: 1, message: "Your device is not registered")`; the fifth throws `.deviceRefused(status: 2, message: "Blocked")`, so `block_msg` wins over `msg` when both are non-empty; an absent or empty message yields `message` nil; a non-empty `block_msg` with `status` 0 is not a refusal. `profile()` returns what `decodeProfile` yields and throws what it throws (AC-9).

### AC-13 Genres decode and the "All" genre is dropped
Given `{"js":[{"id":"*","title":"All","alias":"all","censored":0},{"id":"5","title":"News","alias":"news","censored":"0"},{"id":7,"title":"Sport","alias":"sport"},{"id":"9","title":"","alias":"x"},{"title":"No id"},"junk"]}`
When `decodeGenres(_:)` runs
Then `items` is [`StalkerGenre(id: "5", title: "News")`, `StalkerGenre(id: "7", title: "Sport")`], `skipped` is 3, and `StalkerClient.groupOrder(for: items)` is `["News", "Sport"]`. A genre is dropped and not counted when its `id` is `*` or its `alias` is `all` (case-insensitive); skipped and counted when it is not a JSON object, lacks `id`, or has an empty or whitespace-only `title`. `id` accepts number or string. The body `{"js":[]}` or `{"js":{}}` yields zero items and zero skipped.

### AC-14 Channel rows decode and map
Given host `p.example`, `logoBase` `http://p.example/stalker_portal/misc/logos/320/`, the genres of AC-13, and a `get_all_channels` body whose `js.data` holds the row `{"id":"123","name":"BBC One","number":"7","cmd":"ffmpeg http://s.example/ch/123_","tv_genre_id":"5","logo":"bbc.png","xmltv_id":"bbc1.uk","censored":"0","use_http_tmp_link":"1","enable_tv_archive":"1","tv_archive_duration":"72"}`
When `decodeChannels(_:host:)` runs and the row is mapped with `channel(from:genres:logoBase:)`
Then `StalkerChannel` has `id` 123, `name` "BBC One", `number` 7, `cmd` "ffmpeg http://s.example/ch/123_", `genreID` "5", `logo` "bbc.png", `xmltvID` "bbc1.uk", `archiveHours` 72; and the `Channel` has `id` `stalker#p.example#123`, `name` "BBC One", `number` 7, `group` "News", `logoURL` `http://p.example/stalker_portal/misc/logos/320/bbc.png`, `epgID` "bbc1.uk", `hasCatchup` true, `catchupDays` 3, and `streamURL` equal to `StalkerStreamReference(host: "p.example", channelID: 123, cmd: "ffmpeg http://s.example/ch/123_").url`. Rules: `id` is an `Int`; `id`, `number`, `tv_genre_id`, `enable_tv_archive` and `tv_archive_duration` accept number or string (0003/AC-2); `use_http_tmp_link` is not read (every tune calls `create_link`); `number` is nil when absent, non-numeric or less than 1; `group` is nil when `tv_genre_id` matches no genre. `Channel.id` carries the host only, so two Stalker sources on one host can produce equal ids; 0013 keys rows by `RowKey(sourceID, id, position)` and resolves favourites by `sourceID` when the snapshot has one, so the collision does not merge their rows.

### AC-14c Logo URLs
Given the three discovered endpoints `P/stalker_portal/server/load.php`, `P/server/load.php` and `P/portal.php`, and rows whose `logo` is `bbc.png`, `https://cdn.example/x.png`, `""` and absent
When `logoBase` is read and the rows are mapped
Then `logo` that parses as an `http` or `https` URL with a host is used as is, a bare file name is appended to `logoBase`, and empty or absent gives nil; `StalkerClient.logoBase` is the discovered endpoint's directory with `server/` dropped plus `misc/logos/320/`, so `P/stalker_portal/server/load.php` gives `P/stalker_portal/misc/logos/320/`, `P/server/load.php` gives `P/misc/logos/320/` and `P/portal.php` gives `P/misc/logos/320/`.

### AC-14d Catch-up fields
Given rows with (`enable_tv_archive`, `tv_archive_duration`) of (1, 72), ("1", "25"), (0, 0), (0, 48), (1, absent) and (absent, absent)
When mapped
Then `catchupDays` is `archiveHours` divided by 24 rounded up, nil when `archiveHours` is nil or 0, and `hasCatchup` is true when `enable_tv_archive` is 1 or `archiveHours` is greater than 0: the six rows give (`hasCatchup`, `catchupDays`) of (true, 3), (true, 2), (false, nil), (true, 2), (true, nil) and (false, nil).

### AC-14a Broken channel rows are skipped
Given a `js.data` array where one element is a string, one row lacks `id`, one lacks `cmd`, one has `name` `""`, one has `id` `"abc"` and one repeats an earlier `id`
When `decodeChannels(_:host:)` runs
Then `items` holds the other rows in server order and `skipped` is 6; a row is skipped only for those six reasons (not an object, no `id`, `id` not decodable to an integer, no `cmd` or empty `cmd`, empty or absent `name`, duplicate `id`); any other field failing to decode yields nil for that field and keeps the row. Decoding never traps on `"nan"`, `"inf"`, `"1e400"` or out-of-range numbers.

### AC-14b Channel list shapes
Given bodies where `js.data` is `[]`, `{}`, absent, or a dictionary keyed by index (`{"0":{…},"1":{…}}`), and where `js` is `[]` or `false`
When `decodeChannels(_:host:)` runs
Then the first three and the last two yield zero items and zero skipped; the index-keyed dictionary yields its rows ordered by numeric key, and a non-numeric key is skipped and counted; `js.total_items`, `js.max_page_items` and `js.cur_page` are ignored. A body that is not a JSON object at the root throws `StalkerError.decoding(path: "")`.

### AC-15 Guide id for a channel
Given channel rows with `xmltv_id` "bbc1.uk", `xmltv_id` `""`, and `xmltv_id` absent, all with portal `id` 123, 124, 125
When mapped
Then `epgID` is "bbc1.uk", "stalker:124" and "stalker:125": a non-empty trimmed `xmltv_id` wins, else the portal id prefixed `stalker:`; `decodeEPG(_:epgIDs:)` takes the `[Int: String]` map from portal id to `epgID` that `StalkerClient.epgIDs(for: [StalkerChannel])` builds, so the portal's own EPG joins through 0014/AC-2 and an `epgURL` the user sets still joins through `xmltv_id`.

### AC-16 Stream reference round trip
Given host `p.example`, channel id `123` and cmd `ffmpeg http://s.example/play/live.php?mac=00:1A:79:12:34:56&stream=123&extension=ts`
When `StalkerStreamReference.url` is built and parsed back with `StalkerStreamReference(parsing:)`
Then the URL has scheme `stalker`, host `p.example`, path `/123` and a single query item `cmd` whose decoded value equals the cmd; parsing gives back equal `host`, `channelID` and `cmd`; parsing `http://x/a.ts`, `stalker://p.example/`, `stalker://p.example/123` (no `cmd`) and `stalker:///123?cmd=x` yields nil. `Channel.id` is built from host and channel id only and never from `cmd` (0013 edge case, ADR-0003).

### AC-17 Tune-time link
Given a channel whose `streamURL` is the AC-16 reference and a client with a token
When `playableURL(for:)` runs and the portal answers `{"js":{"id":123,"cmd":"ffmpeg http://s.example/ch/123_?token=play-9f&play_token=abc"}}`
Then exactly one GET is issued with `cmd=ffmpeg%20http%3A%2F%2Fs.example%2Fplay%2Flive.php%3Fmac%3D00%3A1A%3A79%3A12%3A34%3A56%26stream%3D123%26extension%3Dts` and the other items of the Wire detail row, and the result is `http://s.example/ch/123_?token=play-9f&play_token=abc`. `decodeLink(_:)` takes `js.cmd`, splits on whitespace, and returns the last piece that parses as an `http` or `https` URL with a host, so `ffmpeg <url>`, `auto <url>`, `<url>` and `solutions <url>` all resolve. Bodies whose `js.cmd` has no such piece, or whose `js` is `[]`, `{}` or a string, throw `StalkerError.noLink`. A `Channel` whose `streamURL` is not a `stalker://` reference, or whose reference `host` differs from the client's portal host, throws `StalkerError.notAStalkerChannel` without a request. The host comparison is a sanity check only: two portals on one host with different ports or paths pass it, so the caller picks the client by `Channel.sourceID` (Required of other specs, playback spec), and that choice is authoritative.

### AC-17a Link with a stale token
Given a client whose token the portal has expired
When `playableURL(for:)` runs
Then AC-10 applies: the stub sees `create_link`, handshake, [do_auth], profile, `create_link`, and the result is the second answer's URL. A tune costs at most five requests, four more than the usual one.

### AC-18 Account info decodes
Given `{"js":{"mac":"00:1A:79:12:34:56","phone":"","end_date":"2027-01-31","account_balance":"0.00"}}`, and variants with `end_date` `"2027-01-31 23:59:59"`, `"Unlimited"`, `"0000-00-00"`, `""`, `null`, absent, and a numeric `1769900000`
When `decodeAccountInfo(_:)` runs
Then `StalkerAccountInfo.expiresAt` is 2027-01-31 00:00 UTC for the first form, 2027-01-31 23:59:59 UTC for the second, `Date(timeIntervalSince1970: 1769900000)` for the numeric form, and nil for the others; date-only and date-time strings are read in UTC because the portal sends no zone, and the 0006 row formats in UTC to match; `String(reflecting:)` of the value does not contain the MAC (the `mac` field is read and discarded). A `js` that is `[]`, `false` or `{}` yields every field nil.

### AC-19 Transport and status errors
Given the session throws `URLError` with code c in `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`, `.timedOut`, `.cannotFindHost`, `.secureConnectionFailed`, or answers a non-2xx status other than 401 and 403 after the endpoint is known
When any `StalkerClient` call runs, parameterised
Then it throws `StalkerError.transport(c)` or `StalkerError.badStatus(n)`; `String(reflecting:)` and `(error as NSError).userInfo` contain neither the portal URL nor any credential (no `NSURLErrorFailingURLStringErrorKey`), as 0016/AC-10. A cancelled task throws `CancellationError`, not `StalkerError` (0016/AC-10a). A response that is not `HTTPURLResponse` yields `badStatus(-1)`.

### AC-20 Errors, credentials and the client never leak secrets
Given credentials for `http://p.example:8080/stalker_portal` with MAC `00:1A:79:12:34:56`, login `alice-7f3e`, password `s3cr3t-9b2a`, a token `tok-9f3a`, and the AC-4 derived values
When, as a parameterised matrix of value by forbidden string, `String(describing:)` and `String(reflecting:)` are read for `StalkerCredentials`, `StalkerClient`, `StalkerDevice`, `StalkerStreamReference` and every `StalkerError` case (`.portalNotFound`, `.badStatus(500)`, `.unauthorized`, `.deviceRefused(status: 1, message: "Device 00:1A:79:12:34:56 is not registered")`, `.transport(.timedOut)`, `.decoding(path: "js.data[3].id")`, `.noLink`, `.notAStalkerChannel`), and `(error as NSError).userInfo` for each error
Then none contains `00:1A:79:12:34:56`, `001A79123456`, `00%3A1A`, `alice-7f3e`, `s3cr3t-9b2a`, `tok-9f3a`, the derived `sn`, `deviceID` or `signature` values of AC-4, `:8080`, `stalker_portal` or `load.php`; `String(describing:)` of `StalkerCredentials` and of `StalkerClient` equals `p.example`; `String(describing:)` of `StalkerStreamReference` equals `p.example/123`; the `deviceRefused` message reads "Device … is not registered". Every type conforms to `CustomStringConvertible` and `CustomDebugStringConvertible` (0016/AC-8).

### AC-21 Portal messages are redacted
Given the strings "Device 00:1A:79:12:34:56 is not registered", "mac 00-1a-79-12-34-56 blocked", "sn 001A79123456 expired" and "Your subscription ended"
When `StalkerClient.redactingSecrets(_:)` runs with the client's credentials
Then the results are "Device … is not registered", "mac … blocked", "sn … expired" and "Your subscription ended": any six hex pairs separated by `:` or `-` in either case, and any occurrence of the client's own MAC digits, token or derived device values, and of its login or password when that is four characters or longer, becomes "…". Shorter logins and passwords are not matched, so a password `ab` does not mangle the message "about". The client applies the credential-specific part before it throws `deviceRefused`; `StalkerError.description`, `debugDescription` and `errorUserInfo` apply the six-hex-pair rule to the `deviceRefused` message on every read, so a value constructed directly with a MAC in its message (AC-20) still reads redacted.

### AC-22 EPG request
Given a client with a token and `period` 48
When `epgRequest(period:)` runs
Then it returns a `URLRequest` for `<endpoint>?type=itv&action=get_epg_info&period=48&JsHttpRequest=1-xml` with the headers of AC-5 and the `Authorization` header of AC-6, and issues no request itself beyond the handshake AC-9 requires; `period` is clamped to 1...168 hours.

### AC-23 EPG body decodes
Given the map `[123: "bbc1.uk", 124: "stalker:124"]` and a body whose `js.data` is `{"123":[{"id":"9","ch_id":"123","name":"News","descr":"Evening news","category":"news","start_timestamp":1762282800,"stop_timestamp":"1762286400","time":"2026-11-04 20:00:00","time_to":"2026-11-04 21:00:00"}],"124":[{"ch_id":124,"name":"Film","start_timestamp":"1762282800","stop_timestamp":1762282800}],"999":[{"name":"Unknown channel","start_timestamp":1,"stop_timestamp":2}],"abc":[{"name":"Bad key","start_timestamp":1,"stop_timestamp":2}]}`
When `decodeEPG(_:epgIDs:)` runs
Then it returns a `DecodedEPG` whose `items` is one `Programme` with `channelID` "bbc1.uk", `start` `Date(timeIntervalSince1970: 1762282800)`, `stop` `Date(timeIntervalSince1970: 1762286400)`, `title` "News", `summary` "Evening news", `category` "news", `subtitle` nil, `iconURL` nil; `skipped` is 2, for the 124 row (start not before stop, 0002/AC-6) and the row under the non-integer key `abc`; `unmatched` is 1 for channel 999's single row; `unmatched` counts programme rows whose channel id is not in `epgIDs`, not channels. Timestamps are read from `start_timestamp` and `stop_timestamp` as number or numeric string; `time` and `time_to` are ignored because they are in the portal's time zone. A row lacking `name` gets `title` `""` (0002 keeps untitled programmes the same way; the screen supplies the placeholder); a row lacking either timestamp is skipped and counted; an empty `descr` or `category` is nil.

### AC-23b Dictionary key wins over ch_id
Given the AC-23 map and a body whose `js.data` is `{"123":[{"ch_id":124,"name":"Moved","start_timestamp":1762282800,"stop_timestamp":1762286400}]}`
When `decodeEPG(_:epgIDs:)` runs
Then `items` is one `Programme` titled "Moved" with `channelID` "bbc1.uk": in the dictionary form the key gives the channel id and a row's own `ch_id` is ignored.

### AC-23a EPG shapes
Given bodies where `js.data` is `[]`, `{}`, absent, or an array of rows each carrying `ch_id`, and where `js` is `false`
When `decodeEPG(_:epgIDs:)` runs
Then the first three and the last yield zero items, zero skipped and zero unmatched; the array form yields the same result as the dictionary form keyed by each row's `ch_id`.

### AC-24 Malformed bodies are errors, not crashes
Given a 2xx body that is an HTML login page, `<?xml …`, an empty body, JSON whose `js` is a non-empty string, or JSON whose `js` is `null`, `""` or absent
When any decode function runs (`decodeLink` excepted for the non-empty string case, which is AC-17's `noLink`)
Then it throws `StalkerError.decoding(path:)` with the dotted path of the failing key, `""` at the root, and `String(reflecting:)` of the error contains no substring of the body eight bytes or longer (0016/AC-4a). The decode functions are pure and never report a rejection: a `js` that is `null`, `""` or absent throws `decoding(path: "js")` from them. The client runs the AC-10 rejection test before decoding, so through the client those three are a rejection, and an HTML page, XML or a non-empty string `js` is `decoding`, not `unauthorized`.

### AC-25 Keychain mapping (app layer)
Given Keychain item JSON `{"username":"00:1A:79:12:34:56","password":"s3cr3t","login":"alice"}`, the pre-0030 shape `{"username":"00:1A:79:12:34:56","password":""}`, and `{"username":"not-a-mac","password":""}`, each decoded as `CredentialStore.Credential`
When `credential.stalkerCredentials(portal:)` runs with the normalised portal URL
Then the first yields `StalkerCredentials(portal:mac:login:password:)` with MAC `00:1A:79:12:34:56`, login "alice", password "s3cr3t"; the second decodes with `login` nil and yields the MAC with login nil and password nil, so no `do_auth` is issued (AC-8); the third yields nil. The MAC is stored in the item's existing `username` field, so the Keychain shape gains only `login`. `CredentialStore.save` writes `login` whenever it is non-nil. An item re-saved by a build older than this spec drops `login`; that source then fails with `.unauthorized` or `.deviceRefused` until the user enters the login again, and no migration step runs. The MAC is a secret (ADR-0003): it is stored only in the Keychain item, never in `SourceRecord`, `FavoriteRecord`, `Channel.id` or any log line. `Channel.streamURL` may embed it through the portal's `cmd` and is handled as the M3U credential-bearing URL is (0013 edge case): held in memory, never persisted or logged.

### AC-26 Decoding is fast
Given a `get_all_channels` body of 50 000 rows generated in the test from a 20-row template, and a `get_epg_info` body of 200 000 rows
When `decodeChannels(_:host:)` and `decodeEPG(_:epgIDs:)` run over the `Data`
Then each completes in under 10 s in a debug `swift test` run in CI, which is the assertion that can fail a build and catches a quadratic decode. A separate benchmark, enabled by `ANTENNA_BENCHMARKS=1` as 0016/AC-9 and never CI-gated, records the time against a local target of 500 ms on the reference machine named in the test.

## Edge cases and failure modes

- Offline: every call throws `.transport` (AC-19); 0006/AC-8 and 0010/AC-20 render it. A channel list loaded earlier in the process stays in the catalogue; there is no on-disk channel cache (0004 scope).
- Slow or huge portal: `get_all_channels` is one response; 50 000 rows decode under AC-26. The EPG body for such a portal can reach tens of megabytes, which is why fetching stays in 0014 with its size limits and progress.
- Credential not yet synced: the `SourceRecord` arrives through CloudKit before the Keychain item. The loader finds no credential and the source contributes nothing (0004/AC-10, 0010/AC-18). On tvOS, where the Keychain does not sync, 0006/AC-21 asks for the MAC again.
- One MAC, one session: most portals invalidate the previous token when the same MAC handshakes again. Two devices on the same source each re-handshake on their next call (AC-10) and both keep working, at the cost of one extra round trip per switch; the portal may still refuse a second concurrent stream, which surfaces in playback, not here.
- Portal that returns a token for an unknown MAC and refuses at `get_profile`: `.deviceRefused` with the portal's message (AC-12), redacted (AC-21). Nothing is saved on Connect.
- Portal that needs `do_auth` but the user left Login empty: `get_profile` answers status 1 or the channel list is empty; 0006's copy for `.deviceRefused` tells the user to check the login.
- `cmd` strings that embed the MAC (`live.php?mac=…`): they live in `Channel.streamURL` only, as M3U credential-bearing URLs already do (0013 edge case), never in `Channel.id`, logs or error text.
- Resolved links carry `token` and `play_token` query items; the app layer logs them only through 0014/AC-15's `redacted(_:)`.
- A portal whose channels all have `use_http_tmp_link` 0 still goes through `create_link`; the portal returns the same URL. Open question below.
- Genre ids on channels that match no genre: `group` nil, so 0013 lists them as Ungrouped.
- Duplicate genre titles ("Sport" twice with different ids): both map to the same `group` name; 0013/AC-2 uses the name once.
- `censored` channels decode like any other; parental control is out of scope.
- Clock skew: `timestamp` in `get_profile` comes from the injected clock; portals do not validate it strictly.
- The MAG user agent is what the portal expects from its own set-top boxes; the user is connecting to a portal they hold an account on, with their own registered MAC. Antenna ships no portal address, MAC or default (App Review 5.2.3, DR-12).
- `JsHttpRequest=1-xml` makes portals answer JSON; a few answer with a `text/javascript` content type and a leading newline. Decoding trims leading whitespace and ignores the content type.
- A valid portal answering a body with no `js` key at all is read as a rejection (AC-10), costs one re-handshake and ends in `.unauthorized`. Portals seen so far answer an empty list as `{"js":[]}` or `{"js":{"data":[]}}`; the fixture `rejection-js-absent.json` pins the chosen behaviour.
- Any twelve hex digits pass AC-1; a MAC the portal does not know fails at handshake or profile with `.unauthorized` (AC-3a) or `.deviceRefused` (AC-12a).
- `get_all_channels` arrives as one `Data` in memory with no size cap; 50 000 rows are a few tens of megabytes. The 300 s resource timeout (AC-5a) is the only guard; a cap is a 0030 follow-up if a portal exceeds it.
- Cancelling a call during discovery (AC-3) stops at the current candidate and throws `CancellationError`, as AC-9a.
- Tests run under `swift test` on macOS; the tvOS build in CI compiles the package for tvOS, where `CryptoKit` is available at 26.0.
- Cleartext HTTP: most portals, stream hosts and logo hosts are `http`. `project.yml` already sets `NSAllowsArbitraryLoads` for both the Antenna and AntennaTV targets, and the Mac runs the iPad app (`SUPPORTS_MACCATALYST: NO`), so no ATS or entitlement change is needed here.
- Token expiry during playback: the link's token can expire mid-stream. Re-resolving belongs to the playback spec (Out). The first tune after launch costs the handshake, [do_auth], profile and `create_link`; that cost is accepted.
- `TimeZone.current.identifier` goes into the cookie. It is not a secret and is not redacted.

## Test plan

Fixtures under `Tests/AntennaCoreTests/Fixtures/Stalker/`: `handshake.json`, `handshake-empty-token.json`, `profile-ok.json`, `profile-status-string.json`, `profile-refused.json`, `profile-blocked.json`, `do-auth-true.json`, `do-auth-false.json`, `main-info.json` and its `end_date` variants, `genres.json`, `channels.json`, `channels-broken-rows.json`, `channels-indexed.json`, `channels-empty-object.json`, `create-link-ffmpeg.json`, `create-link-auto.json`, `create-link-nolink.json`, `epg.json`, `epg-array.json`, `authorization-failed.txt`, `rejection-js-absent.json`, `login-page.html`. Request shape, discovery, re-handshake and cancellation use a `URLProtocol` stub that records requests in order, as 0003 and 0016 plan. No test opens a network connection. The 50 000-row and 200 000-row bodies are generated at test time.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (parameterised) | TBD |
| AC-2 | core (parameterised) | TBD |
| AC-3 | core (`URLProtocol` stub, per candidate order) | TBD |
| AC-3a | core (`URLProtocol` stub, parameterised over status sets) | TBD |
| AC-4 | core | TBD |
| AC-5 | core (`URLProtocol` stub, injected time zone) | TBD |
| AC-5a | core (configuration assertions) | TBD |
| AC-5b | core (`URLProtocol` stub answering 3xx, parameterised) | TBD |
| AC-6 | core (`URLProtocol` stub) | TBD |
| AC-7 | core (`URLProtocol` stub, injected clock) | TBD |
| AC-7a | core (`URLProtocol` stub) | TBD |
| AC-8 | core (`URLProtocol` stub, parameterised over bodies) | TBD |
| AC-9 | core (`URLProtocol` stub, parameterised over calls) | TBD |
| AC-9a | core (`URLProtocol` stub that holds the handshake answer) | TBD |
| AC-10 | core (`URLProtocol` stub, parameterised over rejection forms) | TBD |
| AC-10a | core (`URLProtocol` stub, two concurrent calls) | TBD |
| AC-11 | core (`URLProtocol` stub) | TBD |
| AC-11a | core (`URLProtocol` stub) | TBD |
| AC-12 | core (decode function, parameterised) | TBD |
| AC-12a | core (decode function, parameterised) | TBD |
| AC-13 | core (decode function) | TBD |
| AC-14 | core (decode function and mapping) | TBD |
| AC-14a | core (decode function) | TBD |
| AC-14b | core (decode function, parameterised) | TBD |
| AC-14c | core (mapping, parameterised over endpoints) | TBD |
| AC-14d | core (mapping, parameterised) | TBD |
| AC-15 | core (mapping) | TBD |
| AC-16 | core (parameterised) | TBD |
| AC-17 | core (`URLProtocol` stub and decode function) | TBD |
| AC-17a | core (`URLProtocol` stub) | TBD |
| AC-18 | core (decode function, parameterised) | TBD |
| AC-19 | core (`URLProtocol` stub throwing, parameterised) | TBD |
| AC-20 | core (parameterised) | TBD |
| AC-21 | core (parameterised) | TBD |
| AC-22 | core (`URLProtocol` stub) | TBD |
| AC-23 | core (decode function) | TBD |
| AC-23a | core (decode function, parameterised) | TBD |
| AC-23b | core (decode function) | TBD |
| AC-24 | core (decode functions, parameterised) | TBD |
| AC-25 | integration (app layer, `Credential` decoded from the three JSON shapes) | TBD |
| AC-26 | core benchmark, `ANTENNA_BENCHMARKS=1`, plus a CI ceiling test | TBD |

## Open questions

Decisions made without an interview, for the owner to overturn:

- `stalker://` reference in `Channel.streamURL` (AC-16) rather than a new optional field on `Channel`. Chosen so 0013 and every screen keep one non-optional `streamURL`; the cost is that `EngineRouter` must never see it, hence the ADR needed.
- `create_link` on every tune, with no fallback to the raw `cmd` when `use_http_tmp_link` is 0. It is predictable and costs one round trip; a portal that rejects `create_link` for direct channels would need the fallback.
- `Credential.login` added to the Keychain payload instead of packing login into `password`. Optional with a nil default, so no migration.
- Token in memory only, never persisted. Costs one handshake per process; avoids a token racing through iCloud Keychain between devices.
- `hasCatchup` is true when `tv_archive_duration` is positive even with `enable_tv_archive` 0 (AC-14d), because some portals send the duration and leave the flag unset. The catch-up spec can flip this if a portal is found that sends a duration for channels without archive.
- A portal URL typed without a scheme is rejected (AC-2) rather than defaulted to `http://`. Defaulting would save tvOS users a few keystrokes; 0006 can add the prefix in the field before calling AC-2.
- `tv_archive_duration` read as hours and divided by 24 for `catchupDays`. Portals differ; the catch-up spec should confirm against real portals.
- Logo path `<portal>/misc/logos/320/` for bare file names. Some portals serve `/misc/logos/120/`; a 404 falls back to DR-8 initials, so the wrong size only costs the logo.
- `epgID` falls back to `stalker:<id>` when `xmltv_id` is empty (AC-15). Alternative: nil, which would leave such channels without a guide even though the portal has one.
- `get_epg_info` with `period` clamped to 168 hours. Some portals cap the period lower and return less; 0014 reports whatever `days` results.
- AC-4's derivation is believed to match StbEmu and TiviMate, including `device_id2 = device_id` and `hw_version_2 = sn`. Nothing in this repo proves it; check against one real portal with device-id locking before the spec moves to Accepted.
- No override for a custom serial or device id (Out). Users whose provider bound a custom id cannot connect until the follow-up.
- `Channel.id` keeps `stalker#<host>#<id>` like Xtream and accepts collisions between two sources on one host, because 0013 separates rows and favourites by `sourceID` (AC-14). The alternative, a short hash of the full portal URL in the id, would change ids whenever the user edits the URL.
- Redirects followed only within one host and port (AC-5b). A portal that redirects to another host needs the user to enter the final address.
- Device identity pinned to the StbEmu derivation with `CryptoKit` (AC-4), which needs the ADR named in the header. The alternative is a Foundation-only derivation that portals with device-id locking would reject for a MAC first used in another client.
- `metrics` carries the MAC as MAG firmware sends it. The MAC is already in the cookie of the same request, so this adds no exposure; sending `"mac":""` is the alternative if a portal is found to reject it.
- Paged `get_ordered_list` left out. Needs a real portal that truncates `get_all_channels` to justify it.
- 0023 (sources and settings) is not in this tree yet. If the edit-source form lands under another number, the references here follow it.
