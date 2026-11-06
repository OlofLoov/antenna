# Design

## Context

Boards: none, no UI. The add-source form and the credential-missing state belong to `add-first-run-onboarding` and `add-live-tv-on-iphone-ipad-mac`.

Design-system requirements that apply: "Nothing fake and nothing bundled" (the device name sent to the server names the platform, never the user's own device name).

## Goals / Non-Goals

**Goals:**
- A Jellyfin client in AntennaCore that signs in per device, loads channels and guide, and builds stream and logo addresses, all testable without UI.

**Non-Goals:**
- The app's own store for the sign-in key. It waits for the follow-up decision on a Keychain item that stays on the device.
- Quick Connect, recordings, libraries, server discovery and self-signed certificates.

## Decisions

- The client's types and methods are under Interface sketch below. `DecodedList` is one top-level type shared with the Xtream VOD client.
- Endpoints: `GET /System/Info/Public`; `POST /Users/AuthenticateByName` with the `Authorization: MediaBrowser Client="Antenna", Device=…, DeviceId=…, Version=…[, Token=…]` header; paged `GET /LiveTv/Channels` (limit 1000, at most 100 pages); `POST /LiveTv/Programs` (50 channels per batch, `Limit` 10000, `MinEndDate` and `MaxStartDate` so programmes already on air come back).
- Stream URL `/Videos/<id>/stream?static=true&api_key=<token>`. Logo `/Items/<id>/Images/Primary?tag=<tag>`. The password is JSON-escaped in the body, never percent-encoded.
- One session store per source, keyed by `credentialKey`. Deleting the source clears this device's session. The store is read once per call, not per page or batch, and its errors pass through unchanged.
- The app makes the device id once per device and keeps it in `UserDefaults` under `jellyfin.deviceID`, never synced. Per-device state that is not a secret goes in `UserDefaults.standard`, not SwiftData or CloudKit. Header values are cleaned to one line with quotes and backslashes removed.
- Channel ids are `jellyfin#<host>#<channel id>`, using the host only. Changing that later needs a decision in a change's design.md, because favorites store the id.
- Certificate checks stay the system default. AntennaCore installs no authentication-challenge delegate.
- Cancellation throws `CancellationError` and never saves or clears the session.
- Two requests turned down at once both sign in. Jellyfin returns the same key for the same user and device, so this is not serialized.
- Channels load in pages of 1000 and stop at the reported total, at a short page, or at 100 pages. Guide requests go in batches of channels and follow each batch's pages. 30 000 channels take 30 pages and 600 guide requests.
- Hand-offs: `add-first-run-onboarding` copy for forbidden ("This account is not allowed to sign in from this device.") and untrusted certificate ("Antenna can't verify this server's certificate. Use http on your network or a trusted certificate."); the sign-in-again row in `add-live-tv-on-iphone-ipad-mac`; `guide-data` takes programmes per batch instead of downloading XMLTV, with batch progress.
- Benchmarks under `ANTENNA_BENCHMARKS=1`: 20 000 channel rows under 1 s and 100 000 programme rows under 2 s in a debug run.

## Interface sketch

Names are binding. Signatures show intent and may gain labels or `Sendable` constraints when implemented.

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

public struct DecodedList<T: Sendable & Hashable>: Sendable, Hashable {   // shared with the Xtream VOD client
    var items: [T]
    var skipped: Int
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

`liveChannels()` and `programmes(channelIDs:in:)` compose the request, the session handling (no session yet, one refresh of a stale key, a failed re-login) and the decode. The static decode functions are pure, take `Data` and are tested over fixtures. Request shape, sign-in and error tests use a `URLProtocol` stub. One `JellyfinSessionStore` instance serves one source, and the app layer creates one per `credentialKey`.

## Risks / Trade-offs

- Open question: should channel ids use the server's own fixed id instead of the host name, so a home address and an away address share favorites? This changes the channel requirement. Decide before acceptance, because favorites store the id.
- Open question: Quick Connect as a follow-up change, or folded in here before implementation? Changes scope.
- Open question: should radio channels be hidden rather than grouped as "Radio"? Changes the channel requirement.
- Open question: how a user on iPhone, iPad or Mac recovers from a changed password, through a "sign in again" row in `add-live-tv-on-iphone-ipad-mac` or by editing the source in `add-sources-and-settings`. Until then the user deletes and re-adds the source.
- Open question: which guide window suits servers with tens of thousands of channels. Decided in `guide-data`.
- [Sign-in revoked while channels are loaded] → stream addresses still hold the old key, so playback fails until the channels reload, which today means relaunching the app.
- [Until the key-store decision exists] → the key lives in memory and the app signs in once per launch.
