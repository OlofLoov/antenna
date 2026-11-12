import Foundation

/// The Xtream panels' time zones, by source, in memory only
/// (xtream-live-source/server-time-zone).
///
/// Each source load records the zone its `accountInfo()` named, or nil
/// when the call failed or named none. When catch-up first needs a zone
/// that is missing, `timeZone(for:fetch:)` asks the panel once more; later
/// needs wait for the next load, so a panel without a zone is not asked
/// over and over.
public actor XtreamTimeZones {
    private var names: [UUID: String] = [:]
    private var askedSinceLoad: Set<UUID> = []

    public init() {}

    /// A load of `sourceID` read `name` from the account information.
    public func loaded(_ sourceID: UUID, timeZoneName name: String?) {
        names[sourceID] = name
        askedSinceLoad.remove(sourceID)
    }

    /// The zone name known for `sourceID`, without asking.
    public func knownName(for sourceID: UUID) -> String? {
        names[sourceID]
    }

    /// The panel's zone. When none is known, `fetch` asks the panel for its
    /// zone name, once after each load. Nil for an unknown identifier.
    public func timeZone(for sourceID: UUID, fetch: @Sendable () async -> String?) async -> TimeZone? {
        if names[sourceID] == nil, askedSinceLoad.insert(sourceID).inserted {
            let fetched = await fetch()
            if names[sourceID] == nil { names[sourceID] = fetched }
        }
        return names[sourceID].flatMap(TimeZone.init(identifier:))
    }
}
