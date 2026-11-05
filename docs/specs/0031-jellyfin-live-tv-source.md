# 0031. Jellyfin Live TV source

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0005
- Follow-up ADR: where the per-device Jellyfin sign-in key lives. ADR-0003 syncs every Keychain item, but Jellyfin ties its key to the device that asked for it, so it must not sync. Meanwhile this spec assumes a Keychain item that stays on the device, behind a store the app hands in; until then the app keeps the key in memory and signs in once per launch. The criteria hold either way.
- Builds on specs: 0003, 0004, 0013, 0014, 0016
- Needs from other specs: 0006, a revision adding the Jellyfin card, wording for forbidden and untrusted certificate, and Jellyfin sources in its Apple TV sign-in step; 0010, a "Sign in again" row; 0014, a revision that takes programmes from the client.
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- User stories: US-6, US-7

## Summary

Jellyfin is a media server people run at home; many already have a TV tuner or a playlist set up in it, with a guide the server keeps fresh. This spec lets Antenna sign in to a Jellyfin server with the user's username and password, show its Live TV channels and guide, and play them. Each device signs in on its own, so revoking one device on the server leaves the others working. It does not bring in Jellyfin's movie, series or music libraries, recordings, Quick Connect codes or self-signed certificates, and it draws no screens.

## Design

Boards: none, no UI. The add-source form and the credential-missing state are 0006 and 0010.
Design rules that apply: DR-12 (the device name sent to the server names the platform, never the user's own device name).
Not drawn: nothing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

A Jellyfin user who wants their live channels in Antenna today has to copy the same playlist in by hand and loses the guide the server already keeps. Jellyfin is the first home server after Xtream that the roadmap names. Nothing in Antenna can talk to it.

## Scope

In:
- A Jellyfin source: the server address, plus a username and password kept in the Keychain as for Xtream. No new field on the synced source.
- Checking the address points at a Jellyfin server before signing in.
- Signing in, and keeping this device's sign-in key in a store the app provides.
- Signing in again once when the server stops accepting the key.
- Live TV channels, loaded page by page, shown in the catalogue.
- The programme guide, fetched for groups of channels and handed to 0014.
- Stream addresses that carry the key, and logo addresses that do not.
- Errors that say what went wrong and never contain the username, password, key or server address.

Out (explicitly):
- Recordings and timers.
- Quick Connect (signing in with a code shown on another device).
- Finding servers on the home network automatically: a 0006 revision.
- Jellyfin's movie, series and music libraries.
- Asking the server to convert streams to another format.
- Trusting self-signed certificates.
- Emby servers.
- Copying Jellyfin's favorites into Antenna.
- The app's own implementation of the key store: the Sources spec, once the ADR above exists.
- Any screen.

## User flow

1. The user adds a Jellyfin source with the server address, username and password. Connect checks the server and signs in. On success the source and Keychain item are saved as for Xtream, and this device keeps its own sign-in key.
2. Channels appear in the catalogue as one source; 0014 fetches the guide and lines it up with them.
3. The user plays a channel. It plays through the route ADR-0001 sets for MPEG-TS streams.
4. On another device the source arrives through iCloud and the password through iCloud Keychain (on Apple TV the user signs in once). That device signs in with its own device id.
5. If the server signs a device out, that device signs in again on its next request. If the password changed, the source shows as not authorized until the user signs in again.

## Acceptance criteria

### AC-1 Connect checks it is really a Jellyfin server
Given a user who typed a server address, with or without a path such as `/jellyfin` or a trailing slash
When the user taps Connect
Then Antenna checks the server without sending the password and learns its id, name and version.

### AC-3 Signing in remembers this device
Given a user with a username and password, and a device that has not signed in to this server before
When the app first needs the server (Connect or a channel load)
Then Antenna sends the username and password once, keeps the key the server returns for this device, and every later request carries that key and never the password.

### AC-4 Different failures get different errors
Given a server that turns down the password, blocks this account on this device, cannot be reached, has a server error, or refuses Live TV to an account it accepted
When the app asks for anything
Then it gets not authorized, forbidden, no connection or a server error respectively; only a turned-down key leads to a new sign-in, and this device's saved key is kept in every one of these cases.

### AC-7 A revoked sign-in renews itself once
Given a device whose key the server has revoked while a long channel list is loading
When the server turns down a request
Then Antenna signs in again once, keeps the new key, repeats only that request and finishes the list with nothing missing.

### AC-9 Every channel loads, however many there are
Given a server with 2 345 channels
When the source loads
Then all 2 345 channels arrive in the server's order; a server with more than 100 000 channels is cut off there.

### AC-10 Channels show their name, number and logo
Given a channel on a server reached as `jf.local`
When it is shown in the catalogue
Then it has its name, its number when the server gives a whole number, the group "Radio" if it is a radio channel and no group otherwise, a logo when the server has one, no catch-up, and an identity that stays the same whatever port or `http`/`https` the user typed for that host, so favorites keep working.

### AC-11 A broken answer is an error, not a crash
Given a server-info, channel or guide answer with some broken rows, an empty answer, a web page, or an answer that is not a list at all
When Antenna reads it
Then broken rows (no id, name or channel, a programme that ends before it starts, an unreadable date, a channel listed twice) are skipped and counted while the rest load in order, an empty answer gives an empty list, a server answer without an id or version fails, and a web page or an answer that is not a list fails as a reading error that quotes nothing from the answer.

### AC-12 Streams play and logos stay key-free
Given a channel and this device's key, on a server with and without a path in its address
When Antenna builds the channel's stream and logo addresses
Then the stream address asks for the channel unchanged with the key in it and plays through the route for MPEG-TS, the raw stream format most IPTV uses (ADR-0001), and the logo address carries no key, so image caches never hold it.

### AC-14 The guide covers the coming week
Given 120 channels and a seven-day window starting now
When 0014 asks for the guide
Then every programme that overlaps the window comes back, including one already on air, with its title, episode title, description, genre, picture and times; asking for no channels sends nothing to the server.

### AC-19 Secrets never show up in messages or logs
Given a source with a username, password, device id and saved key
When the source, its sign-in details or any error is printed or logged, network errors included
Then none shows the username, password, the key in any form, the port or any server path, and the source prints as the server's host name only.

### AC-21 Self-signed certificates are turned down
Given a server whose certificate is self-signed, from an unknown authority, expired or not yet valid
When the app asks for anything
Then the request fails as an untrusted certificate, with no new sign-in and the saved key untouched, so the add-source form can tell the user to use `http` at home or a trusted certificate.

## Edge cases

- A new sign-in or repeated request turned down after a revoked key: the request fails as not authorized, the saved key is discarded, and there is no third try.
- Password changed on the server: until 0010 or 0023 offers "sign in again", the user deletes and re-adds the source on iPhone, iPad and Mac.
- Offline: the first request fails as no connection, with no retry; 0014 keeps the previous guide.
- Sign-in revoked while channels are loaded: stream addresses still hold the old key, so playback fails until the channels reload. Until a Sources spec reloads channels after a new sign-in, that means relaunching the app.
- Credential not yet synced: the source shows no channels and 0010 or 0006 explain why; a saved key without a password is ignored.
- Very large servers: 30 000 channels take 30 pages and 600 guide requests; servers over 100 000 channels are cut off there.
- A badly set up reverse proxy that answers with a web page fails as a reading error, which 0006 shows.
- Servers older than Jellyfin 10.8 fail every request after sign-in as not authorized.
- A server reached under two host names gives two sets of channel ids and splits favorites, as Xtream does.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core |
| AC-3 | core |
| AC-4 | core |
| AC-7 | core |
| AC-9 | core |
| AC-10 | core |
| AC-11 | core |
| AC-12 | core |
| AC-14 | core |
| AC-19 | core |
| AC-21 | core |

## Open questions

- Should channel ids use the server's own fixed id instead of the host name, so a home address and an away address share favorites? Changes AC-10; decide before Accepted, because favorites store the id.
- Quick Connect (a six-digit code instead of typing a password on the TV): a follow-up spec, or folded in here before implementation? Changes scope.
- Should radio channels be hidden rather than grouped as "Radio"? Changes AC-10.
- How does a user on iPhone, iPad or Mac recover from a changed password: a "sign in again" row in 0010, or editing the source in 0023? Decided in those specs.
- Which guide window suits servers with tens of thousands of channels? Decided in 0014.

## Notes for the plan

- The text of this spec before the trim (commit 19e8729) holds an interface sketch: credentials, device, session, the session store protocol, server info, channel row, client methods and the error enum. Start from it; `DecodedList` becomes one top-level type shared with 0016.
- Endpoints: `GET /System/Info/Public`, `POST /Users/AuthenticateByName` with the `Authorization: MediaBrowser Client="Antenna", Device=…, DeviceId=…, Version=…[, Token=…]` header, paged `GET /LiveTv/Channels` (limit 1000, at most 100 pages), `POST /LiveTv/Programs` (50 channels per batch, `Limit` 10000, `MinEndDate` and `MaxStartDate` so programmes already on air come back).
- Stream URL `/Videos/<id>/stream?static=true&api_key=<token>`; logo `/Items/<id>/Images/Primary?tag=<tag>`. The password is JSON-escaped in the body, never percent-encoded.
- One session store per source, keyed by `credentialKey`; deleting the source clears this device's session. The store is read once per call, not per page or batch, and its errors pass through unchanged.
- The device id is made once per device by the app, kept in `UserDefaults` under `jellyfin.deviceID`, never synced. Header values are cleaned to one line with quotes and backslashes removed.
- Channel ids use the host only; changing that later needs an ADR, because favorites store the id.
- Certificate checks stay the system default: AntennaCore installs no authentication-challenge delegate.
- Cancellation throws `CancellationError` and never saves or clears the session.
- Two requests turned down at once both sign in; Jellyfin returns the same key for the same user and device, so this is not serialized.
- Channels load in pages of 1000 and stop at the reported total, at a short page, or at 100 pages; guide requests go in batches of channels and follow each batch's pages. Channel ids are `jellyfin#<host>#<channel id>`.
- Hand-offs: 0006 copy for forbidden ("This account is not allowed to sign in from this device.") and untrusted certificate ("Antenna can't verify this server's certificate. Use http on your network or a trusted certificate."); 0010's sign-in-again row; 0014 takes `[Programme]` per batch instead of downloading XMLTV, with batch progress.
- Benchmarks under `ANTENNA_BENCHMARKS=1`: 20 000 channel rows under 1 s and 100 000 programme rows under 2 s in a debug run.

## Dropped

- Moved to the implementation plan: AC-15a, AC-20a, AC-23, AC-24.
- Merged into AC-3: AC-2, AC-5, AC-6.
- Merged into AC-4 and AC-19: AC-20.
- Merged into AC-4: AC-22.
- Merged into AC-7: AC-8.
- Merged into AC-10: AC-10a, AC-18.
- Merged into AC-11: AC-1a, AC-11a, AC-16, AC-17.
- Merged into AC-12: AC-13.
- Merged into AC-14: AC-15.
- Required of other specs: moved to the Needs from other specs line and Notes for the plan.
