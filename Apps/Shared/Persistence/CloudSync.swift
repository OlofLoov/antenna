import Foundation

#if os(macOS)
    import Security
#endif

/// The CloudKit container this build may reach
/// (source-management/sources-stay-on-the-device-without-icloud).
/// Creating a `CKContainer` in a process without the iCloud entitlement
/// stops the app, so every CloudKit call site asks here first. The build
/// sets the Info.plist key `AntennaCloudKitContainer` only when it signs
/// the app, which is when the entitlements are embedded. On the Mac the
/// running process's own entitlements are read as well.
enum CloudSync {
    static let containerIdentifier = "iCloud.se.codecrave.antenna"
    static let infoKey = "AntennaCloudKitContainer"

    /// The container identifier, or nil when this process cannot use CloudKit.
    static let container: String? = container(
        info: Bundle.main.object(forInfoDictionaryKey: infoKey) as? String, entitled: processHasCloudKit())

    /// The container named by the Info.plist value, or nil when the value
    /// is missing, empty or not an iCloud container, or the process lacks the entitlement.
    static func container(info: String?, entitled: Bool) -> String? {
        guard entitled, let info, info.hasPrefix("iCloud.") else { return nil }
        return info
    }

    private static func processHasCloudKit() -> Bool {
        #if os(macOS)
            guard let task = SecTaskCreateFromSelf(nil),
                let services = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil)
                    as? [String]
            else { return false }
            return services.contains("CloudKit")
        #else
            return true
        #endif
    }
}
