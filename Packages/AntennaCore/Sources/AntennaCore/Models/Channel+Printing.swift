import Foundation

/// A channel prints as its name. The id and stream address, which can hold
/// a login, a MAC or a stream key, and the catch-up template are left out
/// of `description`, `debugDescription` and `dump`
/// (stalker-portal-source/secrets-never-show-up-in-messages-or-logs).
extension Channel: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "Channel(\(name))" }
    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "name": name, "group": group as Any, "epgID": epgID as Any, "number": number as Any, "hasCatchup": hasCatchup,
                "catchupDays": catchupDays as Any, "sourceID": sourceID as Any, "position": position as Any,
            ], displayStyle: .struct)
    }
}
