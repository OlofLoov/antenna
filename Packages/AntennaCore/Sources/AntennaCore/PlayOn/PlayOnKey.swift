import Foundation

/// The inputs both ends feed HKDF-SHA256 to make the link's pre-shared key
/// (play-on-apple-tv/only-the-same-account-can-send-over-the-network). The
/// input key is the ECDH secret of one device's private key and the other's
/// public key, which only devices on the account can read from iCloud. The
/// app runs ECDH and HKDF; these bytes are fixed here so both ends agree.
public enum PlayOnKey {
    /// HKDF's salt.
    public static let salt = Data("antenna-play-v1".utf8)
    /// The key's length in bytes.
    public static let length = 32
    /// The Bonjour service type the Apple TV advertises.
    public static let serviceType = "_antenna-play._tcp"

    /// HKDF's info: the sender's id and the TV's id as 16 bytes each, then
    /// the sender's and the TV's key dates as big-endian 64-bit whole seconds
    /// since 1970. A key made at another time gives another key.
    public static func info(sender: UUID, target: UUID, senderKeyDate: Date, targetKeyDate: Date) -> Data {
        var data = Data()
        data.append(contentsOf: bytes(sender))
        data.append(contentsOf: bytes(target))
        data.append(contentsOf: seconds(senderKeyDate))
        data.append(contentsOf: seconds(targetKeyDate))
        return data
    }

    /// The pre-shared key's identity: the sender's id as text.
    public static func identity(sender: UUID) -> Data {
        Data(sender.uuidString.lowercased().utf8)
    }

    /// The sender id an identity names, nil for anything else.
    public static func sender(identity: Data) -> UUID? {
        UUID(uuidString: String(decoding: identity, as: UTF8.self))
    }

    /// A key date rounded down to whole seconds, as records keep it.
    public static func keyDate(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    private static func bytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid) { Array($0) }
    }

    private static func seconds(_ date: Date) -> [UInt8] {
        withUnsafeBytes(of: Int64(date.timeIntervalSince1970.rounded(.down)).bigEndian) { Array($0) }
    }
}
