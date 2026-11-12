import Foundation

/// What loading one source gave: its channels, or nothing yet because its
/// password has not reached this device (source-management/a-source-can-wait-for-its-credential).
/// A failure throws instead.
public enum SourceLoadResult: Sendable, Equatable {
    case loaded([Channel])
    case waitingForCredential
}

extension ChannelsDVRClient {
    /// Loads a Channels DVR source the way every load does
    /// (channels-dvr-source/a-source-waits-for-its-password-to-sync).
    ///
    /// Without `credentialKey` the Keychain is not read. A login not on this
    /// device gives `.waitingForCredential` and an unreadable one throws
    /// `.credentialUnreadable`, both before any request. Then one status
    /// request and one lineup request; a failed status check stops there.
    public static func load(
        server: URL, credentialKey: String?, credential lookup: (String) -> GuideCredentialLookup,
        session: URLSession = URLSession(configuration: .channelsDVR)
    ) async throws -> SourceLoadResult {
        var credential: HTTPBasicCredential?
        if let credentialKey {
            switch lookup(credentialKey) {
            case .missing:
                return .waitingForCredential
            case .unreadable:
                throw ChannelsDVRError.credentialUnreadable
            case .found(let username, let password):
                guard let basic = HTTPBasicCredential(username: username, password: password) else {
                    throw ChannelsDVRError.credentialUnreadable
                }
                credential = basic
            }
        }
        let client = ChannelsDVRClient(server: server, credential: credential, session: session)
        _ = try await client.status()
        return .loaded(try await client.channels())
    }
}
