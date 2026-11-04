# 0031. Jellyfin Live TV source

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001 (the channel stream is MPEG-TS over HTTP and goes through the demuxer route), 0003, 0005
- ADR needed: where the per-device Jellyfin access token lives. ADR-0003 makes every Keychain item synchronizable, but a Jellyfin token is bound to the device id that requested it, so it must not sync. The criteria assume a second, non-synchronizable Keychain item on the same service, written through the `JellyfinSessionStore` seam below. They hold unchanged if the ADR instead picks "log in at every launch and keep the token in memory", because the store is injected and the criteria never read it directly.
- Channel ids are `jellyfin#<host>#<channelId>`, host only, as 0003/AC-10. A server reached under two hostnames yields two id sets; accepted, same as Xtream. Changing this later requires an ADR because the id is persisted in `FavoriteRecord.channelID` (0013/AC-10) and a change orphans every favorite on every device.
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- Builds on specs 0003 (client shape, host-based ids), 0013 (channels are tagged and grouped by the catalogue), 0014 (the guide joins on `GuideKey`), 0016 (error taxonomy, `DecodedList`, benchmark mechanism). Specs 0006 to 0016 are in open PRs and not yet in this tree.
- Type names: `JellyfinClient.JellyfinError` and `JellyfinClient.DecodedList` are nested in `JellyfinClient` as 0016 nests the Xtream ones; this spec writes them without the prefix. `JellyfinCredentials`, `JellyfinDevice`, `JellyfinSession`, `JellyfinSessionStore`, `JellyfinServerInfo` and `JellyfinChannel` are top-level types in AntennaCore like `XtreamCredentials`.

## Design

Boards: none, no UI. The add-source form and the credential-missing state are 0006 and 0010; channels and the guide render through 0007 to 0012 and 0015.
Design rules that apply: DR-12 (the `Device` header names the platform, never the user's device name).

### Interface

Every criterion reads its result through one of these. Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR.

```swift
public struct JellyfinCredentials: Sendable, Hashable {
    var server: URL          // base URL, scheme and host required, path allowed
    var username: String
    var password: String
}

public struct JellyfinDevice: Sendable, Hashable {
    var id: String           // stable per device, generated once by the app layer
    var name: String         // "Apple TV", "iPhone", "iPad", "Mac"
    var appVersion: String   // CFBundleShortVersionString
}

public struct JellyfinSession: Sendable, Hashable, Codable {
    var token: String
    var userID: String
    var serverID: String
}

public protocol JellyfinSessionStore: Sendable {
    func load() async throws -> JellyfinSession?
    func save(_ session: JellyfinSession) async throws
    func clear() async throws
}

public struct JellyfinServerInfo: Sendable, Hashable {
    var id: String
    var name: String?
    var version: String
}

public struct JellyfinChannel: Sendable, Hashable {   // one decoded row of /LiveTv/Channels
    var id: String
    var name: String
    var number: Int?
    var isRadio: Bool
    var primaryImageTag: String?
}

public struct JellyfinClient: Sendable {
    init(credentials: JellyfinCredentials, device: JellyfinDevice,
         sessionStore: any JellyfinSessionStore, session: URLSession = .shared)

    func serverInfo() async throws -> JellyfinServerInfo
    func authenticate() async throws -> JellyfinSession
    func liveChannels() async throws -> DecodedList<Channel>
    func programmes(channelIDs: [String], in window: DateInterval) async throws -> DecodedList<Programme>

    func streamURL(channelID: String, token: String) -> URL
    func logoURL(channelID: String, tag: String) -> URL
    func channel(from row: JellyfinChannel, token: String) -> Channel

    static func decodeServerInfo(_ data: Data) throws -> JellyfinServerInfo
    static func decodeSession(_ data: Data) throws -> JellyfinSession
    static func decodeChannels(_ data: Data) throws -> (DecodedList<JellyfinChannel>, total: Int?)
    static func decodeProgrammes(_ data: Data, server: URL) throws -> DecodedList<Programme>

    struct DecodedList<T: Sendable & Hashable>: Sendable, Hashable { var items: [T]; var skipped: Int }   // 0016's constraints

    enum JellyfinError: Error, Sendable {
        case badStatus(Int)
        case unauthorized            // 401
        case forbidden               // 403
        case transport(URLError.Code)
        case decoding(path: String)
        case untrustedCertificate
    }
}
```

`liveChannels()` and `programmes(channelIDs:in:)` compose the request, the session handling of AC-6 to AC-8 and the decode. The static decode functions are pure and take `Data`; AC-1a and AC-10 to AC-18 test them over fixtures, AC-1 to AC-9 and AC-19 to AC-22 use a `URLProtocol` stub. One `JellyfinSessionStore` instance is one source; the app layer creates one per `credentialKey`.

## Problem

Users who run Jellyfin already have a tuner, an M3U or an HDHomeRun configured there, with a guide the server keeps fresh. Today they would have to copy the same playlist into Antenna and lose the server's guide. The roadmap and the App Review note (CLAUDE.md) position Antenna as a player for the user's own servers, and Jellyfin is the one named first after Xtream. Nothing in AntennaCore can talk to it.

## Scope

In:
- `SourceKind.jellyfin`. `SourceDescriptor.url` is the server base URL; `credentialKey` points at a Keychain item with username and password exactly as for Xtream (0004/AC-4). No `SourceRecord` field is added.
- Connect check through `GET /System/Info/Public`.
- Sign-in through `POST /Users/AuthenticateByName` with the `Authorization: MediaBrowser` header; the resulting session (token, user id, server id) saved through `JellyfinSessionStore`.
- Re-login once on 401, then surface `unauthorized`.
- Live TV channels through paged `GET /LiveTv/Channels`, mapped to `Channel` with `sourceID` and `position` left for 0013/AC-1 to set.
- Programme guide through `POST /LiveTv/Programs` in channel batches, mapped to `Programme`, handed to 0014 for the join.
- Stream URL per channel carrying the token as `api_key`.
- Logo URLs without the token.
- Tolerant decoding with row skipping, the 0016 error taxonomy plus `forbidden` and `untrustedCertificate`, and no credentials or URLs in any error or description.
- Fixture-based tests, no network.

Out (explicitly):
- Recordings, timers, series timers and the `/LiveTv/Recordings` endpoints. Whether Antenna shows a DVR at all is a decision the owner has not made (research note, "Recording, or an explicit decision not to ship it in v1"). Nothing here depends on it.
- Quick Connect (`/QuickConnect/*`). Open question below; a follow-up spec if the owner wants it.
- Server discovery on the local network (UDP broadcast "who is JellyfinServer?" on port 7359). Owner: a 0006 revision, because the result is a list the add-source form shows; the probe itself would be a `JellyfinDiscovery` type in AntennaCore in that spec.
- Jellyfin movie, series and music libraries (`/Items`, `/Shows`). A later Jellyfin library spec; 0011 renders it.
- `PlaybackInfo` negotiation, device profiles and server-side transcoding. The stream URL here asks for the tuner's bytes unchanged; a playback spec owns anything else.
- Trusting self-signed certificates (trust on first use, pinning, a per-source toggle). This spec rejects them with `untrustedCertificate`; see the decision under Edge cases.
- Emby servers. They answer the same public endpoint and are not tested.
- Seeding Antenna favorites from Jellyfin's `UserData.IsFavorite`.
- Saving the token in the app layer. The store is a protocol here; the Sources spec implements it once the ADR above exists.
- Any UI. The add-source form is 0006, the credential-missing state is 0010/AC-18 and 0006/AC-21.

Required of other specs:
- 0004 (or the Sources spec that supersedes it): the add form offers Jellyfin with Server, Username and Password; 0004/AC-4 and AC-10 hold for the kind; a `kindRaw` of `jellyfin` synced to an older build falls back to `.m3u` per 0004's edge case and yields zero channels without crashing. A `JellyfinSessionStore` is instantiated per source, keyed by `credentialKey`; deleting the source (0004/AC-6) calls `clear()` on this device. Session items on the user's other devices are orphaned until each of them deletes the source; accepted.
- 0006: a "Jellyfin server" card in the type step (AC-3), the Xtream form fields for it (AC-4b), Connect calling `serverInfo()` then `authenticate()`, and copy for `forbidden` ("This account is not allowed to sign in from this device.") and `untrustedCertificate` ("Antenna can't verify this server's certificate. Use http on your network or a trusted certificate."). `unauthorized` and `decoding` reuse 0006/AC-7 and AC-33. The checklist has no movies row for Jellyfin. 0006/AC-21 applies to `.jellyfin` records as to `.xtream`: Server prefilled from `url`, Connect runs `serverInfo()` then `authenticate()`, and the per-device session is written alongside the Keychain item.
- 0010: AC-20 gains a row for `JellyfinError.unauthorized` and `.forbidden` reading "Sign in again to <name>" with `browse.retry` leading to the 0006 details form for that record, or the Sources spec adds credential editing. Until one lands, a changed Jellyfin password means deleting and re-adding the source on iPhone, iPad and Mac. Which of the two is an open question.
- 0013: nothing new. Channels arrive with `group` nil or "Radio", so a Jellyfin source lists as `.ungrouped(S)` plus at most one named group, and has no `groupOrder` entry. Duplicate ids across pages (AC-9) reach the catalogue and 0013/AC-11a lists both.
- 0014: a guide path that takes `[Programme]` from `programmes(channelIDs:in:)` instead of downloading an XMLTV URL. AC-1 gains a row "Jellyfin: no URL; programmes from the client, keys `.loading` until the first batch joins"; AC-9's download phase becomes a per-batch phase (`.downloading(sourceID:, bytesReceived: batchesDone, expectedBytes: batchesTotal)` or a new case); AC-1a and AC-1b apply to the Jellyfin Keychain item; AC-12's `unauthorized` row applies when the client throws it and `transport(.timedOut)` maps to `.timeout`; the Jellyfin guide path builds its `JellyfinClient` with the AC-12a session so the same timeouts and no-cache rules apply; AC-20's byte limits do not apply to batched JSON and no per-batch cap replaces them, because `Limit` 10 000 bounds each response; AC-13's window is the caller's choice and this spec recommends now to now plus 7 days (AC-14 returns every programme overlapping the window, so no lead time is needed).
- 0016: `DecodedList` is defined by whichever of 0016 and 0031 lands second as one top-level type both clients use; until then each nests its own with the constraints above.

## User flow

1. The user adds a Jellyfin source (0006 after its revision): server address, username, password. Connect calls `serverInfo()`, then `authenticate()`. On success the record and the Keychain item are saved as for Xtream and the session is saved for this device.
2. The loader calls `liveChannels()`; channels appear through 0013 as one source group, and 0014 asks for programmes in batches and joins them.
3. The user plays a channel. The stream URL carries the token; the engine router sends it to the demuxer (ADR-0001).
4. On another device the source arrives through CloudKit; on iPhone, iPad and Mac the password arrives through iCloud Keychain, on Apple TV the user signs in once (0006/AC-21). The device has no session, so the first `liveChannels()` logs in with its own device id and saves its own session.
5. When the server revokes the token (admin signs the device out, password change), the next call gets 401, the client logs in once and retries. If the password changed, the loader records `unauthorized` and the user signs in again through the 0010/AC-20 row listed under "Required of other specs", or deletes and re-adds the source until that row exists.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Server info
Given server `http://jf.local:8096/jellyfin` answering `GET /jellyfin/System/Info/Public` with `{"Id":"6f1a2b3c","ServerName":"Living room","Version":"10.9.11","ProductName":"Jellyfin Server"}`
When `serverInfo()` runs
Then exactly one GET is issued to that path with `Accept: application/json` and no `Authorization` header, and the result has `id` "6f1a2b3c", `name` "Living room", `version` "10.9.11". A trailing slash on the server URL yields the same request path.

### AC-1a Server info decode failures
Given bodies where `ServerName` is absent or null, `Id` is absent, `Version` is absent, and a body that is an HTML page
When `decodeServerInfo` runs, parameterised
Then the first yields `name` nil with the other fields intact, and the rest throw `decoding(path:)` with path "Id", "Version" and "".

### AC-2 Authentication request
Given credentials with username `alice-7f3e` and password `a"b\c&d/e+f ö` on server H, device id `0F2C-9A1B`, device name "Apple TV", app version "1.0.0"
When `authenticate()` runs
Then exactly one POST is issued to `<H>/Users/AuthenticateByName` with `Content-Type: application/json`, header `Authorization: MediaBrowser Client="Antenna", Device="Apple TV", DeviceId="0F2C-9A1B", Version="1.0.0"` and no `Token` item, and a body that decodes as JSON to exactly `{"Username":"alice-7f3e","Pw":"a\"b\\c&d/e+f ö"}`; the password is JSON-escaped only, never percent-encoded.

### AC-3 Authentication success
Given the server answers 200 with `{"AccessToken":"t0k","User":{"Id":"u1","Name":"alice-7f3e"},"ServerId":"6f1a2b3c"}`
When `authenticate()` runs
Then it returns `JellyfinSession(token: "t0k", userID: "u1", serverID: "6f1a2b3c")`, `sessionStore.save` was called exactly once with that value and `clear` not at all; `ServerId` absent yields `serverID` ""; `AccessToken` or `User.Id` absent throws `decoding(path: "AccessToken")` or `decoding(path: "User.Id")` and `save` is not called. When `save` throws, its error propagates unwrapped from `authenticate()`, and from `liveChannels()` or `programmes(channelIDs:in:)` before any data request is issued.

### AC-4 Authentication rejected
Given the server answers 401, or 403
When `authenticate()` runs
Then it throws `unauthorized` for 401 and `forbidden` for 403, `save` is not called, and `clear` is not called either, because a wrong password on this attempt does not invalidate a session another call may still hold.

### AC-5 Authenticated request header
Given a stored session with token "t0k", at least one channel id and a non-empty window
When `liveChannels()` or `programmes(channelIDs:in:)` runs
Then every request carries `Authorization: MediaBrowser Client="Antenna", Device="<name>", DeviceId="<id>", Version="<version>", Token="t0k"` and no `api_key` query item, and no request carries the password.

### AC-6 No session yet
Given `sessionStore.load()` returns nil
When `liveChannels()` runs
Then the first request is `POST /Users/AuthenticateByName`, the session is saved, and the channel request follows with that token; `load()` is called once per `liveChannels()` or `programmes(channelIDs:in:)` call, never per page or batch, and a session obtained by re-login during the call is used for the rest of that call without another `load()`; when `load()` throws, that error propagates unwrapped and no request is issued (the app layer maps it as 0014/AC-1b maps `credentialUnreadable`).

### AC-7 Stale token is refreshed once
Given a stored session with token "old", three pages of channels, and a server that answers 200 to page `startIndex` 0 with "old", 401 to any later request with `Token="old"` and 200 to `Token="new"`, issuing "new" on authentication
When `liveChannels()` runs
Then the sequence is: page 0 with "old" (200), page 1000 with "old" (401), `POST /Users/AuthenticateByName`, `save` with "new", page 1000 with "new" (200), page 2000 with "new" (200); page 0 is requested once and kept, only the 401'd page is re-requested, and the result holds all three pages. The same holds per batch and page in `programmes(channelIDs:in:)`.

### AC-8 Re-login fails
Given a stored session whose token the server answers 401 to, and authentication that also answers 401
When `liveChannels()` runs
Then it throws `unauthorized`, `clear()` was called exactly once, and no third request was made; authentication answering 403 throws `forbidden` with `clear()` called once as well; a 401 on the retried request after a successful re-login throws `unauthorized` without a second login and with `clear()` called once, because the token the server just issued is already invalid.

### AC-9 Channel paging
Given a server with 2 345 channels
When `liveChannels()` runs
Then the requests are `GET /LiveTv/Channels` with query items `userId=<session.userID>`, `startIndex`, `limit=1000`, `enableImages=true`, `imageTypeLimit=1`, `enableImageTypes=Primary`, `enableUserData=false` in that order, with `startIndex` 0, 1000, 2000; paging stops when `startIndex + Items.count >= TotalRecordCount`, when a page returns fewer than `limit` elements regardless of `TotalRecordCount`, or after 100 pages (`startIndex` 100 000), after which `liveChannels()` returns what it has; `items` holds 2 345 channels in server order; `startIndex` advances by the raw element count of `Items`, skipped elements included; a test asserts the short-page stop against a server whose `TotalRecordCount` is 1 000 000 000 and the page cap against a server that always returns 1 000 elements. Duplicate ids across pages are not skipped, because `decodeChannels` sees one page at a time.

### AC-10 Channel mapping
Given a row `{"Id":"c1","Name":"SVT1 HD","ChannelNumber":"1","ChannelType":"TV","ImageTags":{"Primary":"abc"},"Type":"TvChannel"}` on server `http://jf.local:8096` with token "t0k"
When `channel(from:token:)` runs
Then `Channel` has `id` "jellyfin#jf.local#c1", `name` "SVT1 HD", `number` 1, `group` nil, `epgID` "c1", `logoURL` `http://jf.local:8096/Items/c1/Images/Primary?tag=abc`, `streamURL` per AC-12, `hasCatchup` false, `catchupDays` nil, `sourceID` nil and `position` nil (0013/AC-1 sets them).

### AC-10a Loose and missing fields
Given rows where `ChannelNumber` is "12", " 7 ", "12.1", "S1-01", "", absent, or absent with `Number` "9"; `ChannelType` is "Radio", "TV", "Unknown", absent or a number; `ImageTags` is absent, `{}` or lacks `Primary`
When `decodeChannels` then `channel(from:token:)` run, parameterised
Then `JellyfinChannel.number` is 12, 7, nil, nil, nil, nil and 9 (`ChannelNumber` first, then `Number`, each trimmed and parsed as a whole decimal integer); `isRadio` is true for "Radio" and false for every other value, absence included; `primaryImageTag` is nil whenever no `Primary` tag exists; `Channel.group` is "Radio" when `isRadio` and nil otherwise, `Channel.logoURL` is nil when `primaryImageTag` is nil; decoding never traps.

### AC-11 Broken rows are skipped
Given a channel page where one element is not a JSON object, one lacks `Id`, one lacks `Name`, one has `Id` "", one has `Name` "" and one repeats an earlier `Id`
When decoded
Then `items` holds the other rows in server order and `skipped` is 6; any other field failing to decode yields nil for that field (false for `isRadio`) and keeps the row.

### AC-11a Non-list body fails whole
Given a channel body whose `Items` is an object, a string or `true`, or a body that is a JSON array, string or `true`
When decoded
Then `decoding(path:)` is thrown with path "Items" for the first three and "" for the rest, and `String(reflecting:)` of the error contains no byte of the body. A body with no `Items` key decodes as AC-17 describes.

### AC-12 Stream URL
Given channel id "c1" and token "t0k" on server `http://jf.local:8096`, and on `https://h/jellyfin`
When `streamURL(channelID:token:)` runs
Then it is `http://jf.local:8096/Videos/c1/stream?static=true&api_key=t0k` and `https://h/jellyfin/Videos/c1/stream?static=true&api_key=t0k`; a token with reserved characters is percent-encoded so that the decoded query value equals the token; `EngineRouter.route(for:)` of the URL is `.demuxer` (ADR-0001; the demuxer hands back to `AVPlayer` when the first bytes are HLS).

### AC-13 Logo URL carries no token
Given channel id "c1" and tag "abc"
When `logoURL(channelID:tag:)` runs
Then the URL has path `/Items/c1/Images/Primary`, query `tag=abc` only, and contains neither `api_key` nor the token.

### AC-14 Programme request and batching
Given 120 channel ids and a window from 2026-11-04T17:00:00Z to 2026-11-11T17:00:00Z, and a stored session with `userID` "u1"
When `programmes(channelIDs:in:)` runs
Then three POSTs go to `/LiveTv/Programs` with `Content-Type: application/json`, each body decoding to an object with `ChannelIds` of at most 50 ids in input order, `UserId` "u1", `MinEndDate` "2026-11-04T17:00:00Z", `MaxStartDate` "2026-11-11T17:00:00Z", no `MinStartDate` and no `MaxEndDate` (so every programme that overlaps the window is returned, including one that started before it and is still airing), `SortBy` ["StartDate"], `SortOrder` "Ascending", `Fields` ["Overview","Genres"], `EnableImages` true, `ImageTypeLimit` 1, `EnableImageTypes` ["Primary"], `EnableUserData` false, `EnableTotalRecordCount` true, `Limit` 10000, `StartIndex` 0; a batch whose response has `TotalRecordCount` greater than `StartIndex + Items.count` is requested again with `StartIndex` advanced by the raw element count of `Items`, skipped elements included, until it is not, and a page with zero items ends that batch; `items` is the concatenation in batch then page order and `skipped` the sum; an empty `channelIDs` issues no request and returns an empty list.

### AC-15 Programme mapping
Given a row `{"Id":"p1","ChannelId":"c1","Name":"Rapport","EpisodeTitle":"Kväll","Overview":"Nyheter.","Genres":["News","Local"],"StartDate":"2026-11-04T18:30:00.0000000Z","EndDate":"2026-11-04T19:00:00.0000000Z","ImageTags":{"Primary":"img1"}}` on server `http://jf.local:8096`
When decoded
Then `Programme` has `channelID` "c1", `start` 2026-11-04T18:30:00Z, `stop` 2026-11-04T19:00:00Z, `title` "Rapport", `subtitle` "Kväll", `summary` "Nyheter.", `category` "News" (first genre), `iconURL` `http://jf.local:8096/Items/p1/Images/Primary?tag=img1`; absent `EpisodeTitle`, `Overview`, `Genres` or `ImageTags.Primary` yield nil; `Name` absent yields `title` "" (0002's edge case) and keeps the row.

### AC-15a Date forms
Given `StartDate` values "2026-11-04T18:30:00Z", "2026-11-04T18:30:00.0000000Z", "2026-11-04T18:30:00.5Z", "2026-11-04T19:30:00+01:00", "2026-11-04T18:30:00" and "yesterday"
When decoded, parameterised
Then the first, second and fourth parse to 2026-11-04T18:30:00Z, the third to 2026-11-04T18:30:00.500Z (a fractional part of 1 to 9 digits is kept to the millisecond), the fifth to 2026-11-04T18:30:00Z (a missing zone means UTC), and the last drops the row per AC-16; whether the parser is `Date.ISO8601FormatStyle` or hand-rolled is not asserted.

### AC-16 Programme rows dropped
Given a programme page where one element is not a JSON object, one lacks `ChannelId`, one lacks `StartDate`, one lacks `EndDate`, one has `EndDate` equal to `StartDate`, one has `EndDate` before `StartDate` and one has an unparseable `StartDate`
When decoded
Then none of the seven is in `items`, `skipped` is 7, and the remaining rows are returned in server order; a programme whose `Id` is absent is kept with `iconURL` nil, because 0014 keys on `channelID` and `start`.

### AC-17 Empty shapes
Given a channel or programme body `{"Items":[],"TotalRecordCount":0}`, `{"Items":[]}` or `{}`
When decoded
Then `items` is empty, `skipped` is 0, and for channels `total` is 0, nil and nil.

### AC-18 Ids are stable
Given the same channel row decoded from two responses, and the same row on `http://jf.local:8096`, `https://jf.local:8920` and `http://jf.local`
When ids are compared
Then equal rows give equal ids, and the three servers give the same `id` "jellyfin#jf.local#c1" (host only, as 0003/AC-10 and the header decision); a different host gives a different id.

### AC-19 Errors and values carry no secrets
Given a client for `http://jf.local:8096` with username `alice-7f3e`, password `s3cr3t-9b2a`, device id `0F2C-9A1B` and a stored token `t0k-4e9f`
When `String(describing:)` and `String(reflecting:)` are read for `JellyfinCredentials`, `JellyfinClient`, `JellyfinSession`, every `JellyfinError` case, and `(error as NSError).userInfo` for each error
Then none of them contains `alice-7f3e`, `s3cr3t-9b2a`, `t0k-4e9f`, `:8096`, `api_key`, `/Videos/`, `/LiveTv/` or `/Users/`; `String(describing:)` of `JellyfinCredentials` and of `JellyfinClient` equals `jf.local` and of `JellyfinSession` equals `userID`; the three types conform to `CustomStringConvertible` and `CustomDebugStringConvertible`.

### AC-20 Transport failures carry no URL
Given the session throws `URLError` with code c, for c in `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`, `.timedOut`, `.cannotFindHost`, `.cannotConnectToHost`, with at least one channel id and a non-empty window for `programmes(channelIDs:in:)`
When any `JellyfinClient` call runs, parameterised over the four calls and the codes
Then it throws `transport(c)`, no re-login is attempted, and `String(reflecting:)` and `(error as NSError).userInfo` of the thrown error contain neither the server URL nor the token (no `NSURLErrorFailingURLStringErrorKey`); a response that is not `HTTPURLResponse` yields `badStatus(-1)`.

### AC-20a Cancellation
Given the calling task is cancelled while a request is in flight, with at least one channel id and a non-empty window for `programmes(channelIDs:in:)`
When any `JellyfinClient` call runs
Then it throws `CancellationError`, not `JellyfinError`, and `save` and `clear` are not called.

### AC-21 Untrusted certificate
Given the session throws `URLError` with code `.serverCertificateUntrusted`, `.serverCertificateHasUnknownRoot`, `.serverCertificateHasBadDate` or `.serverCertificateNotYetValid`, with at least one channel id and a non-empty window for `programmes(channelIDs:in:)`
When any call runs
Then it throws `untrustedCertificate`, no re-login is attempted, and `save` and `clear` are not called.

### AC-22 Other statuses
Given the server answers 403 to an authenticated channel or programme request, or 404, 429, 500, 503 to any request, with at least one channel id and a non-empty window for `programmes(channelIDs:in:)`
When the call runs
Then 403 throws `forbidden` without re-login and without `clear()` (unlike AC-8: the token was accepted, the user lacks Live TV access), and the others throw `badStatus(n)` with `clear()` not called; a 401 on `serverInfo()` throws `badStatus(401)`, since that endpoint takes no credentials.

### AC-23 Decoding is fast
Given a channel body of 20 000 rows and a programme body of 100 000 rows, each generated in the test from a template row
When `decodeChannels(_:)` and `decodeProgrammes(_:server:)` run
Then they complete in under 1 s and 2 s in a debug `swift test` run on the reference machine recorded in a comment on the test (same baseline as 0013/AC-14), gated by `ANTENNA_BENCHMARKS=1` as 0016/AC-9 defines.

### AC-24 Header values are sanitised
Given a `JellyfinDevice` whose `name` is `Olof's "TV"`, whose `id` contains a space and whose `appVersion` contains a newline
When any request is built
Then the `Authorization` header value is a single line, every `"` and `\` inside a value is removed, the `id` value is reduced to characters in `A-Z`, `a-z`, `0-9` and `-`, and an `id` that becomes empty is replaced by "unknown". The app layer passes a platform name per DR-12; the rule guards against a bad caller.

## Edge cases and failure modes

- Self-signed certificates, decided: not trusted. Most Jellyfin servers on a LAN run plain http on 8096 and `NSAllowsArbitraryLoads` is already on for Xtream; remote servers sit behind a reverse proxy with a public certificate. AC-21 names the failure and 0006 tells the user what to do. Trust on first use would need a pinned fingerprint stored per source (a `SourceRecord` field, so an ADR) and a tvOS flow for confirming it; a follow-up spec if users ask.
- Logo URLs carry no token (AC-13) so image caches and request logs never hold it. Jellyfin serves item images anonymously; a server configured otherwise fails the logo load and DR-8 draws initials.
- Trust evaluation stays the system default: the client uses the injected `URLSession` as given and installs no delegate. The `impl-reviewer` checks that AntennaCore contains no `urlSession(_:didReceive:completionHandler:)`.
- Token lifetime: Jellyfin tokens do not expire on a timer. They die when an admin signs the device out, the user changes their password, or the server database is reset. AC-7 and AC-8 cover each case with one round trip.
- Concurrent 401s: two calls in flight with the same stale token both log in. Jellyfin returns the same token for the same user, device id and client name, so both saves write the same value. This spec does not serialise them.
- Stream URLs embed the token (AC-12). `Channel.streamURL` is therefore stale after a re-login; the loader rebuilds channels after a session change, which 0004 does not do today (its reload gap). Until a Sources spec closes it, a revoked token means a relaunch. Stream URLs are redacted by 0014/AC-15's rule (`api_key` is a query value) whenever the app layer logs one, and `Channel.id` never embeds the URL.
- Device id: generated once per device by the app layer and kept in `UserDefaults` under `jellyfin.deviceID`. It is not a secret and must not sync, because two devices sharing an id appear as one session on the server. Changing it orphans the server-side device entry and nothing else.
- Credential not yet synced: the `SourceRecord` arrives before the Keychain item. The loader never builds a `JellyfinClient` without a password (0004/AC-10), so the source contributes zero channels and 0010/AC-18 or 0006/AC-21 show the state. A session item without a password is ignored.
- Offline: `transport(.notConnectedToInternet)` from the first request, no re-login, no retry. 0014/AC-11a keeps the previous guide.
- Huge sources: an M3U tuner with 30 000 channels pages in 30 requests (AC-9) and its guide in 600 batches of 50 channels (AC-14). 0014 loads one source at a time and reports batch progress; the time is dominated by the server. AC-9's page cap of 100 means a source above 100 000 channels is truncated. The guide window is the caller's; a 7-day window over 30 000 channels is tens of millions of rows and the open question on windows addresses it.
- Programme rows carry `ChannelId` for channels the request did not ask about when the server merges channels; 0014/AC-2 drops them as `unmatched`.
- Server URL with a base path (`/jellyfin`) keeps it on every request (AC-1, AC-12). A URL without a scheme is rejected by 0004/AC-1 before the client exists. A redirect to another host is followed by `URLSession` and the `Authorization` header is dropped on cross-host redirects, so the user should enter the final address; not tested.
- Servers older than 10.8 read `X-Emby-Authorization` instead of `Authorization` and answer 401 to every authenticated call; AC-8 surfaces `unauthorized`. 10.8 shipped in 2022 and this spec does not support older servers or send the legacy header.
- An Emby server answers AC-1 with `ProductName` "Emby Server" and the same channel shape, and is not tested. `ProductName` is decoded and ignored.
- `ChannelType` "Radio" becomes the only named group of the source; a user with no radio channels sees one Ungrouped group (0013/AC-2). Jellyfin exposes no `group-title`.
- `UserData.IsFavorite` and `CurrentProgram` on channel rows are ignored. 0005 owns favorites and 0014 owns now and next.
- Jellyfin returns 200 with an HTML page from a misconfigured reverse proxy: AC-1 and AC-11a throw `decoding`; 0006/AC-33 renders it.

## Test plan

Fixtures under `Tests/AntennaCoreTests/Fixtures/Jellyfin/`: `system-info-public.json`, `authenticate-by-name.json`, `livetv-channels-page.json` (two pages), `livetv-channels-broken-rows.json`, `livetv-channels-loose-fields.json`, `livetv-programs.json`, `livetv-programs-dates.json`, `livetv-programs-broken-rows.json`, `empty-items.json`, `login-page.html`. Requests go through a `URLProtocol` stub that records method, path, query, headers and body and answers from a fixture or a status; the session store is an in-memory actor that records `load`, `save` and `clear` calls. The 20 000 and 100 000 row bodies are generated at test time. No test opens a network connection.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (`URLProtocol` stub) | TBD |
| AC-1a | core (decode function, parameterised) | TBD |
| AC-2 | core (`URLProtocol` stub) | TBD |
| AC-3 | core (stub, recording session store) | TBD |
| AC-4 | core (stub: 401, 403) | TBD |
| AC-5 | core (stub) | TBD |
| AC-6 | core (stub, store returning nil) | TBD |
| AC-7 | core (stub keyed on `Token` and `startIndex`) | TBD |
| AC-8 | core (stub, parameterised over 401 and 403) | TBD |
| AC-9 | core (stub: three pages, huge total, endless pages) | TBD |
| AC-10 | core (decode function plus `channel(from:token:)`) | TBD |
| AC-10a | core (decode function plus `channel(from:token:)`, parameterised) | TBD |
| AC-11 | core (decode function) | TBD |
| AC-11a | core (decode function, parameterised) | TBD |
| AC-12 | core | TBD |
| AC-13 | core | TBD |
| AC-14 | core (stub, recorded bodies) | TBD |
| AC-15 | core (decode function) | TBD |
| AC-15a | core (decode function, parameterised) | TBD |
| AC-16 | core (decode function) | TBD |
| AC-17 | core (decode function, parameterised) | TBD |
| AC-18 | core (decode function) | TBD |
| AC-19 | core (parameterised) | TBD |
| AC-20 | core (stub throwing, parameterised) | TBD |
| AC-20a | core (stub, task cancelled) | TBD |
| AC-21 | core (stub throwing, parameterised) | TBD |
| AC-22 | core (stub, parameterised) | TBD |
| AC-23 | core benchmark, `ANTENNA_BENCHMARKS=1` | TBD |
| AC-24 | core (stub) | TBD |

## Open questions

Decisions made without the owner, each overturnable at review:

- Token storage (the ADR above): a non-synchronizable Keychain item per device, or log in at every launch and hold the token in memory. The second needs no ADR and costs one request per source per launch.
- Quick Connect: Jellyfin lets a user type a six-digit code on a device that is already signed in instead of a password on the TV. It suits tvOS well (0006's continuity keyboard is the alternative) and needs `GET /QuickConnect/Enabled`, `POST /QuickConnect/Initiate`, polling `GET /QuickConnect/Connect` and `POST /Users/AuthenticateWithQuickConnect`, plus a 0006 screen. Follow-up spec, or fold into this one before implementation?
- Channel ids use the host (header decision, AC-18) as Xtream does, so a server reached as `jf.local` at home and `jf.example.org` away yields two sets of ids and splits favorites. Jellyfin gives a stable server `Id` (AC-1, AC-3); using it would make AC-10's id "jellyfin#6f1a2b3c#c1", give `channel(from:token:)` a `serverID:` parameter and make AC-18 assert equality by server id. This must be overturned before acceptance or not at all, because the id persists in `FavoriteRecord`.
- Recovery from a changed password on iPhone, iPad and Mac: a 0010/AC-20 row with `browse.retry`, or credential editing in the Sources spec (see Required of other specs).
- Self-signed certificates: trust on first use with a pinned fingerprint, as a later spec, or leave AC-21 as the permanent answer.
- The stream URL asks for the tuner's bytes unchanged (`static=true`). Tuners whose source is HLS may need `PlaybackInfo` negotiation and a transcoding URL; that belongs to a playback spec, but if it turns out to be common the stream URL here changes shape.
- Guide window: 0014 picks it. Seven days over tens of thousands of channels is too much; a shorter window for large sources, or fetching only visible channels (research note, "EPG refresh only for active channels"), needs a 0014 decision.
- Should Jellyfin's own favorites (`UserData.IsFavorite`) seed Antenna favorites on first load? 0005 owns the records.
- Should a server older than 10.8 be detected from AC-1's `version` and reported with its own error, instead of failing as `unauthorized` later?
- Should radio channels be hidden rather than grouped as "Radio"?

## Dropped

- AC-1 is split into AC-1 and AC-1a after review round 1; the request shape and the decode failures fail for different reasons and sit at different layers.
