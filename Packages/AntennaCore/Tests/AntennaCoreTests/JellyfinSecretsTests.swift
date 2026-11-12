import Foundation
import Testing

@testable import AntennaCore

@Suite struct JellyfinSecretsTests {
    private static let secrets = ["alice", "hunter2-pw", "device-77", "KEY-123", "8920", "jellyfin-path"]

    private static func printed(_ value: Any) -> [String] {
        var dumped = ""
        dump(value, to: &dumped)
        return ["\(value)", String(reflecting: value), dumped]
    }

    private static func expectClean(_ value: Any, sourceLocation: SourceLocation = #_sourceLocation) {
        for text in printed(value) {
            for secret in secrets {
                #expect(!text.contains(secret), "printed \(secret)", sourceLocation: sourceLocation)
            }
        }
    }

    @Test("jellyfin-live-tv-source/secrets-never-show-up-in-messages-or-logs prints the source, sign-in details and errors without secrets")
    func printing() throws {
        let server = try #require(URL(string: "https://jf.local:8920/jellyfin-path/"))
        let credentials = JellyfinCredentials(server: server, username: "alice", password: "hunter2-pw")
        let device = JellyfinDevice(id: "device-77", name: "iPhone", appVersion: "1.0")
        let session = JellyfinSession(token: "KEY-123", userID: "u", serverID: "s")
        let client = JellyfinClient(credentials: credentials, device: device, sessionStore: JellyfinMemorySessionStore(session))
        #expect("\(credentials)" == "jf.local")
        #expect("\(client)" == "jf.local")
        for value: Any in [credentials, device, session, client] { Self.expectClean(value) }
        let errors: [JellyfinClient.JellyfinError] = [
            .badStatus(500), .unauthorized, .forbidden, .transport(.timedOut), .decoding(path: "Items"), .untrustedCertificate,
        ]
        for error in errors { Self.expectClean(error) }
    }

    @Test("jellyfin-live-tv-source/secrets-never-show-up-in-messages-or-logs network errors carry no address or key")
    func networkErrors() async throws {
        let host = "jf-secret-net.local"
        let fake = FakeJellyfin()
        fake.password = "hunter2-pw"
        fake.on("LiveTv/Channels") { _, _ in .failure(.timedOut) }
        let store = CountingSessionStore(JellyfinSession(token: "KEY-123", userID: "u", serverID: "s"))
        let client = try fake.client(host: host, server: "http://\(host):8920/jellyfin-path", store: store)
        do {
            _ = try await client.liveChannels()
            Issue.record("expected a failure")
        } catch {
            Self.expectClean(error)
            #expect(!"\(error)".contains(host))
            #expect(error as? JellyfinClient.JellyfinError == .transport(.timedOut))
        }
    }
}
