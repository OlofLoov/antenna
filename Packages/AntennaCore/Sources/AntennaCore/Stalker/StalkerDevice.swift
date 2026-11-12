import Foundation

/// The set-top box Antenna presents itself as to a Stalker portal. Portals
/// reject requests without these headers and profile values.
public struct StalkerDevice: Sendable, Equatable {
    public var userAgent: String
    public var xUserAgent: String
    public var stbType: String
    public var version: String
    public var imageVersion: String
    public var hardwareVersion: String
    public var apiSignature: String

    /// A MAG250, the box StbEmu and TiviMate present as.
    public static let mag250 = StalkerDevice(
        userAgent: "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3",
        xUserAgent: "Model: MAG250; Link: Ethernet",
        stbType: "MAG250",
        version:
            "ImageDescription: 0.2.18-r14-pub-250; ImageDate: Fri Jan 15 15:20:44 EET 2016; PORTAL version: 5.6.1; "
            + "API Version: JS API version: 328; STB API version: 134; Player Engine version: 0x566",
        imageVersion: "218",
        hardwareVersion: "1.7-BD-00",
        apiSignature: "262"
    )
}

/// The serial number, device id and signature worked out from a MAC, the
/// way StbEmu and TiviMate work them out, so a portal that tied the MAC to
/// those ids accepts Antenna
/// (stalker-portal-source/portals-that-remember-your-device-still-let-you-in).
///
/// Every value identifies the device as well as the MAC does, so
/// `description` and `dump` show none of them.
public struct StalkerIdentity: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// First 13 characters of the uppercase hex MD5 of the MAC.
    public let serialNumber: String
    /// Uppercase hex SHA-256 of the MAC. Sent as `device_id` and `device_id2`.
    public let deviceID: String
    /// Uppercase hex SHA-256 of the MAC, serial number and device id twice.
    public let signature: String

    public init(mac: MACAddress) {
        let bytes = Array(mac.text.utf8)
        serialNumber = String(Digest.hex(Digest.md5(bytes)).prefix(13))
        deviceID = Digest.hex(Digest.sha256(bytes))
        signature = Digest.hex(Digest.sha256(Array((mac.text + serialNumber + deviceID + deviceID).utf8)))
    }

    public var description: String { "…" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }
}
