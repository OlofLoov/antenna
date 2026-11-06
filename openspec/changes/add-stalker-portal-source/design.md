# Design

## Context

Boards: none, no UI. The add-source form belongs to `add-first-run-onboarding` and `add-sources-and-settings`.

Design-system requirements that apply: none here. "Channels without a logo show initials", "Accessibility identifiers follow the board" and "Loading shows real progress per step" apply to the changes that render Stalker channels and the form.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

## Goals / Non-Goals

**Goals:**
- A Stalker client in AntennaCore with the same shape as the Xtream client, tested against a recorded request stub.
- One client per source shared by the loader, the guide and playback.

**Non-Goals:**
- Paged channel lists, VOD, radio, catch-up, recording and portal messages.
- A per-source custom serial number or device id.

## Decisions

- The text of the old spec before the trim (commit 19e8729) holds the wire detail: headers, the MAG250 user agent, query items per call, the `ver` and `metrics` literals, endpoint discovery order, and the expected device-identity values for `00:1A:79:12:34:56`. Start from it.
- The session key is never written to disk.
- Hand-offs to other changes: a portal channel never falls back to the normal stream route and shows the playback failure state when it cannot be resolved. Zapping away cancels the address request. A `Channel`'s printed form hides its stream address, which can hold the MAC (adr-0003).
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

## Risks / Trade-offs

- Open question: does the StbEmu derivation (MD5 and SHA-256 of the MAC, `device_id2` equal to `device_id`, `hw_version_2` equal to the serial) match a real portal that locks device ids? It changes the device-identity requirement. Check before the change is accepted.
- [Two devices on one MAC cancel each other's session] → each renews on its next request at the cost of one round trip. The portal may still refuse a second stream at the same time, which shows up in playback.
- [The first tune after launch signs in first] → it takes a few more round trips, and a tune after the session expired takes one more round of those.
