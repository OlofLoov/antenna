#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// `-ui-testing-onboarding signedIn` or `signedOut` starts the app on an
    /// empty in-memory store, so it opens on onboarding, with iCloud reported
    /// as signed in or out. `connect` is `signedIn` with Connect answered
    /// in the app: `http://onboarding.test/tv.m3u` holds News One and News
    /// Two, `http://empty.test/tv.m3u` holds nothing, `xtream.test` is an
    /// Xtream server with one News channel for any login, and every other
    /// host cannot be found. Nothing reaches the network, iCloud or the
    /// Keychain.
    enum UITestingOnboarding {
        static let argument = "-ui-testing-onboarding"

        enum Scenario: String {
            case signedIn
            case signedOut
            case connect
        }

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes signedIn, signedOut or connect")
            }
            return scenario
        }

        /// The empty store, or nil when the app was not launched for these tests.
        static func container() -> ModelContainer? {
            guard scenario() != nil else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                UITestingLoginDrops.seed(container)
                return container
            } catch {
                fatalError("Could not create the onboarding UI testing store: \(error)")
            }
        }

        static let clipboardArgument = "-ui-testing-clipboard"

        /// `-ui-testing-clipboard <text>` stands in for the pasteboard with
        /// `text` on it; an empty value is a clipboard without a link. Nil
        /// when the argument is absent.
        @MainActor static func clipboard(arguments: [String] = ProcessInfo.processInfo.arguments) -> Clipboard? {
            guard let index = arguments.firstIndex(of: clipboardArgument) else { return nil }
            let next = arguments.index(after: index)
            let text = next < arguments.endIndex ? arguments[next] : ""
            return Clipboard(hasLink: { !text.isEmpty }, read: { text })
        }

        static let playlistArgument = "-ui-testing-playlist"

        /// `-ui-testing-playlist <link>` starts the form on M3U with the
        /// playlist field filled in, since typing on the Apple TV keyboard
        /// from a UI test is slow and unreliable. Nil without the argument.
        static func prefilledFields(arguments: [String] = ProcessInfo.processInfo.arguments) -> SourceFields? {
            guard let index = arguments.firstIndex(of: playlistArgument), arguments.index(after: index) < arguments.endIndex else {
                return nil
            }
            return SourceFields(kind: .m3u, url: arguments[arguments.index(after: index)])
        }

        /// The scripted iCloud state, or nil outside these tests.
        static func signedInToICloud() -> Bool? {
            scenario().map { $0 != .signedOut }
        }

        /// A session answered by `Stub`, for the `connect` scenario only.
        static func session() -> URLSession? {
            guard scenario() == .connect else { return nil }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [Stub.self]
            return URLSession(configuration: configuration)
        }

        /// The connector Connect uses in the `connect` scenario, or nil.
        static func connector() -> SourceConnector? {
            session().map { SourceConnector(session: $0, credentials: credentials) }
        }

        /// How a connected source loads in the `connect` scenario, or nil.
        @MainActor static func setupDependencies() -> SourceSetup.Dependencies? {
            session().map { .live(session: $0, guide: nil) }
        }

        /// The loader Live and the shell use in the `connect` scenario, or nil.
        static func loader() -> SourceLoader? {
            session().map { SourceLoader(session: $0, credentials: credentials) }
        }

        /// The run's logins, shared by the connector and the loader the way
        /// the Keychain is, so a login saved in Settings lets its source load.
        static let credentials = Credentials()

        /// Logins kept in memory for the test run.
        final class Credentials: CredentialStoring, @unchecked Sendable {
            private let lock = NSLock()
            private var items: [String: CredentialStore.Credential] = [:]

            func save(_ credential: CredentialStore.Credential, for key: String) throws { lock.withLock { items[key] = credential } }
            func load(for key: String) throws -> CredentialStore.Credential? { lock.withLock { items[key] } }
            func delete(for key: String) throws { _ = lock.withLock { items.removeValue(forKey: key) } }
        }

        /// Answers the `connect` scenario's playlists.
        final class Stub: URLProtocol, @unchecked Sendable {
            static let playlists = [
                "onboarding.test": """
                #EXTM3U
                #EXTINF:-1 tvg-chno="101" group-title="News",News One
                http://onboarding.test/news-one.ts
                #EXTINF:-1 tvg-chno="102" group-title="News",News Two
                http://onboarding.test/news-two.ts
                """,
                "empty.test": "#EXTM3U\n",
                "xtream.test": #"{"user_info":{"username":"anna","status":"Active","max_connections":"1","auth":1}}"#,
            ]

            override static func canInit(with request: URLRequest) -> Bool { true }
            override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            /// What `xtream.test` answers for each action; the account check has none.
            static let xtreamActions = [
                "get_live_categories": #"[{"category_id":"1","category_name":"News"}]"#,
                "get_live_streams": #"[{"stream_id":1,"name":"Cabin News","category_id":"1"}]"#,
            ]

            override func startLoading() {
                let action = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                    .queryItems?.first { $0.name == "action" }?.value
                let xtream = request.url?.host() == "xtream.test" ? action.map { Self.xtreamActions[$0] ?? "[]" } : nil
                guard let url = request.url, let body = xtream ?? url.host().flatMap({ Self.playlists[$0] }),
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
                else {
                    client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
                    return
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }
    }
#endif
