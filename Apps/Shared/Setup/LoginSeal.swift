import AntennaCore
import CryptoKit
import Foundation

/// The private half of the key an Apple TV makes for one code
/// (apple-tv-login-from-iphone/nothing-about-a-login-is-logged-or-kept).
/// Only the TV's model holds it, in memory, and drops it when the code is
/// replaced or the card goes away. It is never written to the Keychain,
/// disk or logs, and prints as its type name only.
struct LoginReceiverKey: CustomStringConvertible, CustomDebugStringConvertible, @unchecked Sendable {
    fileprivate let privateKey: Curve25519.KeyAgreement.PrivateKey

    /// A new key from the system's random source.
    init() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
    }

    /// A fixed key, for previews and tests.
    init(rawRepresentation: Data) throws {
        privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawRepresentation)
    }

    /// The public half, which the code carries.
    var publicKey: SetupKey {
        guard let key = SetupKey(bytes: privateKey.publicKey.rawRepresentation) else {
            preconditionFailure("A Curve25519 public key is 32 bytes")
        }
        return key
    }

    var description: String { "LoginReceiverKey" }
    var debugDescription: String { description }
}

/// One delivery as it sits in iCloud: the HPKE encapsulated key, the
/// sealed payload and the format version. Prints sizes only.
struct SealedLogin: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The format this build writes and opens.
    static let currentVersion = 1

    var enc: Data
    var box: Data
    var version: Int = Self.currentVersion

    var description: String { "SealedLogin(v\(version), \(box.count) bytes)" }
    var debugDescription: String { description }
}

/// Seals logins to the key in an Apple TV's code and opens them on that TV
/// (apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login).
/// HPKE base mode with X25519, SHA-256 and ChaCha20-Poly1305. The code's
/// 22 characters are the authenticated data, so a box saved under another
/// code does not open.
enum LoginSeal {
    static let ciphersuite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
    static let info = Data("se.codecrave.antenna.login.v1".utf8)

    /// Why a delivery did not open.
    enum OpenError: Error, Equatable {
        /// Sealed to another key or code, or damaged on the way.
        case unreadable
        /// From a newer Antenna.
        case unknownVersion
    }

    /// Seals `payload` to `key` for the code `token`.
    static func seal(_ payload: LoginPayload, to key: SetupKey, token: PairingToken) throws -> SealedLogin {
        try seal(payload.encoded(), to: key, token: token)
    }

    /// Seals raw bytes, so tests can seal a payload this build would not write.
    static func seal(_ plaintext: Data, to key: SetupKey, token: PairingToken) throws -> SealedLogin {
        let recipient = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: key.bytes)
        var sender = try HPKE.Sender(recipientKey: recipient, ciphersuite: ciphersuite, info: info)
        let box = try sender.seal(plaintext, authenticating: Data(token.text.utf8))
        return SealedLogin(enc: sender.encapsulatedKey, box: box)
    }

    /// Opens a delivery for the code `token` with the TV's key.
    static func open(_ sealed: SealedLogin, with key: LoginReceiverKey, token: PairingToken) throws(OpenError) -> LoginPayload {
        guard sealed.version == SealedLogin.currentVersion else { throw .unknownVersion }
        let plaintext: Data
        do {
            var recipient = try HPKE.Recipient(
                privateKey: key.privateKey, ciphersuite: ciphersuite, info: info, encapsulatedKey: sealed.enc)
            plaintext = try recipient.open(sealed.box, authenticating: Data(token.text.utf8))
        } catch {
            throw .unreadable
        }
        do {
            return try LoginPayload(decoding: plaintext)
        } catch .unknownVersion {
            throw .unknownVersion
        } catch {
            throw .unreadable
        }
    }
}
