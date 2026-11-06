## Context

Network client in AntennaCore with no UI, so no board or design-system requirement applies. Follows decision adr-0003 (credentials in iCloud Keychain) and decision adr-0005 (AntennaCore is UI-free). Runs on iOS, iPadOS, macOS and tvOS.

## Goals / Non-Goals

**Goals:**
- Live channels from an Xtream panel in the same `Channel` shape M3U produces.
- No URL or credential in any error value.

**Non-Goals:**
- Account status handling, retries and catch-up links.

## Decisions

- Channel ids are `xtream#<host>#<stream_id>`, host only. Two panels on one host with different ports, or one panel over http and https, collide. A server URL without a host gives `xtream##42`.
- A server URL with a path keeps it: `http://host/xtream` and `http://host/xtream/` both reach `http://host/xtream/player_api.php`.
- A response that is not `HTTPURLResponse` is `badStatus(-1)`.
- Categories missing `category_name` fail the whole category list. Duplicate `category_id` values decode to equal strings and are not deduplicated; `source-management` records the consequence.
- Superseded by `xtream-vod-client`: 401 and 403 now throw `XtreamError.unauthorized`, as does a 200 body with `user_info.auth` 0; a malformed body throws `XtreamError.decoding(path:)` instead of `DecodingError`; integers decode only from whole numbers, so "7.5" is not 7; a broken live row is skipped instead of failing the list; credentials are percent-encoded in every query and path. The tests for this capability assert the newer behavior.

## Risks / Trade-offs

- Host-only ids collide across ports and schemes. Accepted.
- Resolved by `xtream-vod-client`: bad credentials (`auth: 0`) throw `unauthorized`, and an undecodable live row is skipped instead of failing the whole list.
