import AntennaCore
import CryptoKit
import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/// This device as Play on knows it: its id, kind and name, and the key pair
/// it made at launch (play-on-apple-tv/only-the-same-account-can-send-over-the-network).
/// The private key lives in memory only, is never written to the Keychain,
/// disk or logs, and prints as its type name only.
struct PlayOnDevice: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Where the device's id is kept, a small JSON value in UserDefaults.
    static let deviceIDKey = "playOn.deviceID"

    let id: UUID
    let kind: PlayDeviceInfo.Kind
    let name: String
    let keys: PlayOnKeyPair

    /// The record this device writes about itself.
    func info(now: Date) -> PlayDeviceInfo {
        PlayDeviceInfo(id: id, kind: kind, name: name, publicKey: keys.publicKey, keyDate: keys.keyDate, lastSeen: now)
    }

    var description: String { "PlayOnDevice(\(kind.rawValue), \(id))" }
    var debugDescription: String { description }

    /// The id made on first launch and kept in `defaults`; a value that
    /// does not decode reads as absent and a new one is kept.
    static func deviceID(_ defaults: UserDefaults = .standard) -> UUID {
        if let data = defaults.data(forKey: deviceIDKey), let id = try? JSONDecoder().decode(UUID.self, from: data) { return id }
        let id = UUID()
        if let data = try? JSONEncoder().encode(id) { defaults.set(data, forKey: deviceIDKey) }
        return id
    }

    /// This device, with a key pair made now. Each launch makes one.
    @MainActor static func launching(_ defaults: UserDefaults = .standard, now: Date = .now) -> PlayOnDevice {
        PlayOnDevice(id: deviceID(defaults), kind: currentKind, name: currentName, keys: PlayOnKeyPair(now: now))
    }

    @MainActor static var currentKind: PlayDeviceInfo.Kind {
        #if os(tvOS)
            .tv
        #elseif os(macOS)
            .mac
        #else
            UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #endif
    }

    /// The name the user gave the device where the system shares it, else
    /// the model's name, as "iPhone" (design.md, how a TV is found and named).
    @MainActor static var currentName: String {
        #if os(macOS)
            Host.current().localizedName ?? "Mac"
        #else
            UIDevice.current.name
        #endif
    }
}

/// A P-256 key-agreement key pair made at launch.
struct PlayOnKeyPair: @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    fileprivate let privateKey: P256.KeyAgreement.PrivateKey  // gitleaks:allow, a type name, not a key
    /// When the pair was made, in whole seconds.
    let keyDate: Date

    init(now: Date) {
        privateKey = P256.KeyAgreement.PrivateKey()
        keyDate = PlayOnKey.keyDate(now)
    }

    /// A fixed pair, for tests and previews.
    init(rawRepresentation: Data, keyDate: Date) throws {
        privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: rawRepresentation)
        self.keyDate = PlayOnKey.keyDate(keyDate)
    }

    /// The public half, X9.63, as the device record carries it.
    var publicKey: Data { privateKey.publicKey.x963Representation }

    /// The link's pre-shared key between this pair and `peer`: HKDF-SHA256
    /// over the ECDH secret, with the salt and info `PlayOnKey` fixes. Both
    /// ends get the same bytes; any other key pair gets different ones.
    func linkKey(with peer: PlayDeviceInfo, sender: UUID, target: UUID, senderKeyDate: Date, targetKeyDate: Date) throws -> Data {
        let peerKey = try P256.KeyAgreement.PublicKey(x963Representation: peer.publicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        let info = PlayOnKey.info(sender: sender, target: target, senderKeyDate: senderKeyDate, targetKeyDate: targetKeyDate)
        let key = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: PlayOnKey.salt, sharedInfo: info, outputByteCount: PlayOnKey.length)
        return key.withUnsafeBytes { Data($0) }
    }

    var description: String { "PlayOnKeyPair" }
    var debugDescription: String { description }
}

extension PlayOnDevice {
    /// The key this phone, iPad or Mac uses to send to `tv`.
    func linkKey(sendingTo tv: PlayDeviceInfo) throws -> Data {
        try keys.linkKey(with: tv, sender: id, target: tv.id, senderKeyDate: keys.keyDate, targetKeyDate: tv.keyDate)
    }

    /// The key this Apple TV expects from `sender`.
    func linkKey(receivingFrom sender: PlayDeviceInfo) throws -> Data {
        try keys.linkKey(with: sender, sender: sender.id, target: id, senderKeyDate: sender.keyDate, targetKeyDate: keys.keyDate)
    }
}

/// The keys a request names items by
/// (play-on-apple-tv/a-request-holds-no-link-and-no-login). A provider's id
/// can hold a stream link or a host, so the request carries the first 16
/// bytes of its SHA-256 as hex, which both ends compute from the same id.
enum PlayItemKeys {
    static func key(_ id: String) -> String {
        SHA256.hash(data: Data(id.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    static func channel(_ channel: Channel) -> String { key(channel.id) }
    static func title(_ title: ShelfTitle) -> String { key(title.id) }
    static func episode(_ episode: Episode) -> String { key(episode.id) }
}
