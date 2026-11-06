# Design

## Context

Boards: none, no UI. The add-source form and the credential-missing state belong to `add-first-run-onboarding` and `add-live-tv-on-iphone-ipad-mac`.

Design-system requirements that apply: "Nothing fake and nothing bundled" (the device name sent to the server names the platform, never the user's own device name).

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

## Goals / Non-Goals

**Goals:**
- A Jellyfin client in AntennaCore that signs in per device, loads channels and guide, and builds stream and logo addresses, all testable without UI.

**Non-Goals:**
- The app's own store for the sign-in key. It waits for the follow-up decision on a Keychain item that stays on the device.
- Quick Connect, recordings, libraries, server discovery and self-signed certificates.

## Decisions

- The spec text before the trim (commit 19e8729) holds an interface sketch: credentials, device, session, the session store protocol, server info, channel row, client methods and the error enum. Start from it. `DecodedList` becomes one top-level type shared with the Xtream VOD client.
- Endpoints: `GET /System/Info/Public`; `POST /Users/AuthenticateByName` with the `Authorization: MediaBrowser Client="Antenna", Device=…, DeviceId=…, Version=…[, Token=…]` header; paged `GET /LiveTv/Channels` (limit 1000, at most 100 pages); `POST /LiveTv/Programs` (50 channels per batch, `Limit` 10000, `MinEndDate` and `MaxStartDate` so programmes already on air come back).
- Stream URL `/Videos/<id>/stream?static=true&api_key=<token>`. Logo `/Items/<id>/Images/Primary?tag=<tag>`. The password is JSON-escaped in the body, never percent-encoded.
- One session store per source, keyed by `credentialKey`. Deleting the source clears this device's session. The store is read once per call, not per page or batch, and its errors pass through unchanged.
- The app makes the device id once per device and keeps it in `UserDefaults` under `jellyfin.deviceID`, never synced (adr-0009, per-device state in UserDefaults). Header values are cleaned to one line with quotes and backslashes removed.
- Channel ids are `jellyfin#<host>#<channel id>`, using the host only. Changing that later needs a decision record, because favorites store the id.
- Certificate checks stay the system default. AntennaCore installs no authentication-challenge delegate.
- Cancellation throws `CancellationError` and never saves or clears the session.
- Two requests turned down at once both sign in. Jellyfin returns the same key for the same user and device, so this is not serialized.
- Channels load in pages of 1000 and stop at the reported total, at a short page, or at 100 pages. Guide requests go in batches of channels and follow each batch's pages. 30 000 channels take 30 pages and 600 guide requests.
- Hand-offs: `add-first-run-onboarding` copy for forbidden ("This account is not allowed to sign in from this device.") and untrusted certificate ("Antenna can't verify this server's certificate. Use http on your network or a trusted certificate."); the sign-in-again row in `add-live-tv-on-iphone-ipad-mac`; `guide-data` takes programmes per batch instead of downloading XMLTV, with batch progress.
- Benchmarks under `ANTENNA_BENCHMARKS=1`: 20 000 channel rows under 1 s and 100 000 programme rows under 2 s in a debug run.

## Risks / Trade-offs

- Open question: should channel ids use the server's own fixed id instead of the host name, so a home address and an away address share favorites? This changes the channel requirement. Decide before acceptance, because favorites store the id.
- Open question: Quick Connect as a follow-up change, or folded in here before implementation? Changes scope.
- Open question: should radio channels be hidden rather than grouped as "Radio"? Changes the channel requirement.
- Open question: how a user on iPhone, iPad or Mac recovers from a changed password, through a "sign in again" row in `add-live-tv-on-iphone-ipad-mac` or by editing the source in `add-sources-and-settings`. Until then the user deletes and re-adds the source.
- Open question: which guide window suits servers with tens of thousands of channels. Decided in `guide-data`.
- [Sign-in revoked while channels are loaded] → stream addresses still hold the old key, so playback fails until the channels reload, which today means relaunching the app.
- [Until the key-store decision exists] → the key lives in memory and the app signs in once per launch.
