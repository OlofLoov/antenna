# Design

## Context

Boards: none, no UI. The add-source form belongs to `add-first-run-onboarding` and `add-sources-and-settings`.

Design-system requirements that apply: none here. "Channels without a logo show initials", "Accessibility identifiers follow the board" and "Loading shows real progress per step" apply to the changes that render Stalker channels and the form.

## Goals / Non-Goals

**Goals:**
- A Stalker client in AntennaCore with the same shape as the Xtream client, tested against a recorded request stub.
- One client per source shared by the loader, the guide and playback.

**Non-Goals:**
- Paged channel lists, VOD, radio, catch-up, recording and portal messages.
- A per-source custom serial number or device id.

## Decisions

- The client speaks the portal protocol as a MAG250 set-top box. Headers, query items per call, endpoint discovery and the device identity are under Wire detail below.
- The session key is never written to disk.
- Hand-offs to other changes: a portal channel never falls back to the normal stream route and shows the playback failure state when it cannot be resolved. Zapping away cancels the address request. A `Channel`'s printed form hides its stream address, which can hold the MAC. The MAC is a secret and lives only in the Keychain item, never in a synced record, an identifier or a log.
- Tests use a `URLProtocol` stub that records requests in order, as `xtream-live-source` and `xtream-vod-client` do. No test opens a network connection.
- A rejection is exactly 401, 403, a body of `Authorization failed.`, or JSON whose `js` is null, `""` or absent. `{"js":false}` is an empty answer, not a rejection.
- `Channel.streamURL` holds a `stalker://<host>/<id>?cmd=…` reference. `Channel.id` is `stalker#<host>#<id>` and never uses `cmd`. Playback picks the client by `Channel.sourceID`. The resolved URL is held for one tune and never stored or logged.
- The app keeps one client per source for the life of the process and shares it between loader, guide and playback, so two instances never cancel each other's session.
- The URL session stores no cookies and no cache, and follows redirects only to the same host and port, so the MAC cookie and session key never reach another server.
- `guide-data` downloads the guide with its own session, so on a rejection it calls the client's `invalidateToken()` and asks for a new request once.
- The Keychain item keeps the MAC in `username` and gains an optional `login`. Items saved before this change decode unchanged and no migration runs.
- Account info's `end_date` is read in UTC, date-only strings included, for onboarding's "Account active until" row.
- Owner's numbers: 50,000 channels and 200,000 guide rows decode in under 10 s in a debug CI run. Bare logo file names go under `misc/logos/320/`. The guide period is clamped to 1 to 168 hours.
- Whether to ask the portal for a link on every tune, even when it marks a channel as not needing one, or to play the stored command directly, is settled in the implementation.
- Whether the portal's archive duration is always in hours is settled in the implementation, and `add-timeshift-catch-up-and-start-over` confirms it against real portals.

## Wire detail

Portals speak one GET endpoint. Every request has `type` and `action` query items, ends with `JsHttpRequest=1-xml`, and answers JSON with the payload under the key `js`. Decoding trims leading whitespace and ignores the content type, because some portals answer `text/javascript` with a leading newline. Every MAG box sends the headers below, and portals reject requests without them.

| Header | Value |
|--------|-------|
| `Cookie` | `mac=<MAC with ":" as %3A>; stb_lang=en; timezone=<TimeZone identifier>` |
| `User-Agent` | `Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3` |
| `X-User-Agent` | `Model: MAG250; Link: Ethernet` |
| `Referer` | `<normalized portal URL>/c/` |
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

- The fixed values are constants on `StalkerDevice.mag250`.
- `ver` is the literal `ImageDescription: 0.2.18-r14-pub-250; ImageDate: Fri Jan 15 15:20:44 EET 2016; PORTAL version: 5.6.1; API Version: JS API version: 328; STB API version: 134; Player Engine version: 0x566`.
- `metrics` is the JSON string `{"mac":"<MAC>","sn":"<sn>","type":"STB","model":"MAG250","uid":"","random":"<random from the handshake, or "" when absent>"}` with no whitespace. For a handshake that sent `random` `r-42` and the MAC `00:1A:79:12:34:56` it is `{"mac":"00:1A:79:12:34:56","sn":"2213785DC6113","type":"STB","model":"MAG250","uid":"","random":"r-42"}` byte for byte.
- `timestamp` comes from an injected clock, in whole seconds since 1970.
- Every query value is percent-encoded with the RFC 3986 unreserved set as the only characters left bare, as the Xtream VOD client does, so `ver`, `metrics` and `cmd` arrive with their spaces, quotes, braces, `;`, `&` and `/` encoded. A password `a&b/c+d` goes out as `password=a%26b%2Fc%2Bd`. Request-shape tests compare the decoded query items in order.
- Requests carry the MAC by design, in the cookie and in `metrics`. Redaction covers errors, printed values and messages, never the wire.

### Portal address

Trim whitespace, require scheme `http` or `https` (lowercased) and a non-empty host (lowercased), drop a trailing `/c` or `/c/` and any trailing slash, and keep every other path segment and the port. Query, fragment and userinfo are dropped. A string without a scheme is rejected, not defaulted to `http`.

| Typed | Normalized |
|-------|------------|
| `http://p.example/c/`, `http://p.example/c`, `HTTP://P.Example/`, `http://p.example` | `http://p.example` |
| `http://p.example:8080/stalker_portal/c/` | `http://p.example:8080/stalker_portal` |
| `http://[::1]:8080/c/` | `http://[::1]:8080` |
| `p.example/c/`, `ftp://p.example/c/`, `http:///c/` | rejected |

### Endpoint discovery

`handshake()` tries candidates in order and keeps the first that answers 2xx with a non-empty `js.token` as the endpoint for every later call on that client instance. Discovery never runs again on an instance that has an endpoint.

1. When the normalized address P ends in `stalker_portal`: `P/server/load.php` only.
2. Otherwise: `P/stalker_portal/server/load.php`, then `P/server/load.php`, then `P/portal.php`.

A non-2xx answer, a body that is not JSON, JSON without a non-empty `js.token`, or a refused cross-host redirect moves to the next candidate. A `URLError` on any candidate stops discovery with a transport error. When every candidate fails, the error is picked in this order:

1. Any candidate answered 5xx: server error with the last 5xx status seen, so an outage never reads as a wrong address.
2. Any candidate answered 401 or 403 with a body that is not HTML, or 2xx JSON with an empty or absent token: not authorized, so an unregistered MAC reads as a refused device.
3. Otherwise, including 2xx HTML on every candidate: no portal found.

Logos: a `logo` that parses as an `http` or `https` URL with a host is used as is. A bare file name goes under the endpoint's directory with `server/` dropped plus `misc/logos/320/`, so `P/stalker_portal/server/load.php` gives `P/stalker_portal/misc/logos/320/`, and `P/server/load.php` and `P/portal.php` both give `P/misc/logos/320/`.

### Device identity

`sn`, `device_id`, `device_id2`, `hw_version_2` and `signature` come from the MAC's colon form in uppercase. For `00:1A:79:12:34:56`:

| Value | Rule | Expected |
|-------|------|----------|
| `sn` | first 13 characters of the uppercase hex MD5 of the MAC | `2213785DC6113` |
| `deviceID` | uppercase hex SHA-256 of the MAC | `667094E7E8FF0347F6EC27A8E8115BE76E2AA9CD5C8F13C6FA00BCEDFAC02B41` |
| `signature` | uppercase hex SHA-256 of MAC + `sn` + `deviceID` + `deviceID` | `922F69DECA50A1E4883CDB6AF9A57D86B2C82BE460AE9AFCAF2B421C715A0D1B` |

The request items `sn`, `device_id`, `device_id2` and `hw_version_2` carry `sn`, `deviceID`, `deviceID` and `sn`. The MAC cookie value for this MAC is `00%3A1A%3A79%3A12%3A34%3A56`.

### Tune-time link

`decodeLink` takes `js.cmd`, splits it on whitespace, and returns the last piece that parses as an `http` or `https` URL with a host, so `ffmpeg <url>`, `auto <url>`, `<url>` and `solutions <url>` all resolve. No such piece, or a `js` that is `[]`, `{}` or a string, is "no link". A `Channel` whose stream address is not a `stalker://` reference, or whose reference host differs from the client's portal host, fails as "not a Stalker channel" without a request. A tune with an expired session costs at most five requests: `create_link`, handshake, `do_auth` when there is a login, profile, `create_link`.

## Risks / Trade-offs

- Open question: does the StbEmu derivation (MD5 and SHA-256 of the MAC, `device_id2` equal to `device_id`, `hw_version_2` equal to the serial) match a real portal that locks device ids? It changes the device-identity requirement. Check before the change is accepted.
- [Two devices on one MAC cancel each other's session] → each renews on its next request at the cost of one round trip. The portal may still refuse a second stream at the same time, which shows up in playback.
- [The first tune after launch signs in first] → it takes a few more round trips, and a tune after the session expired takes one more round of those.
