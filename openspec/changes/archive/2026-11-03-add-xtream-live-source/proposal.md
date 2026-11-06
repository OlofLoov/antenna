## Why

Xtream Codes logins (server, username, password) are the other common way users hold a subscription. Panels return JSON with inconsistent types and require the credentials in every URL. The app needs a client that lists live categories and streams, builds playable links, and maps streams onto the same channel shape as M3U, so the rest of the app does not care where a channel came from. This serves the new user who wants "to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing".

Written after the fact. It records behavior shipped in commit 082034b so later changes have a spec to revise. The `xtream-vod-client` change later tightened its errors, integer decoding, row skipping and credential encoding, and the requirements here state the behavior after that change.

## What Changes

- Call `player_api.php` with `get_live_categories`, `get_live_streams` (optionally filtered by category) and the account call with no action.
- Decode ids and counters that arrive as numbers or strings.
- Build live stream links in `.ts` or `.m3u8` form and the `xmltv.php` guide link.
- Map a live stream and its category name to a channel.
- Report non-2xx responses as typed errors.

Out of scope:
- Movie and series endpoints (added by `xtream-vod-client`).
- `get_short_epg` and `get_simple_data_table`.
- Catch-up and timeshift links.
- Retries, timeouts beyond the session defaults, rate limiting.
- Detecting an expired or disabled account from `user_info`.
- Storing credentials (`source-management`).

## Capabilities

### New Capabilities
- `xtream-live-source`: list an Xtream provider's live channels and build their links.

### Modified Capabilities

## Impact

- AntennaCore: `XtreamClient`, `XtreamCredentials`, `XtreamLiveStream`, `XtreamCategory`, `XtreamAccountInfo`.
- Credentials sit in every URL the client builds, so those URLs are never logged.
