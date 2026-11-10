import Foundation

/// Which channels to keep open next to the one playing, so zapping to them
/// starts without a new connection (playback-engine/channel-switching-is-fast).
///
/// Every channel opened ahead holds one of the account's connections, and a
/// provider that allows one at a time cuts the playing stream or refuses the
/// next when a second opens. So nothing is opened ahead at one allowed
/// connection or an unknown limit.
public enum ZapAhead {
    /// Which way the user last zapped.
    public enum Direction: Sendable, Equatable {
        /// Toward the next channel in the lineup.
        case up
        /// Toward the previous channel.
        case down
    }

    /// The addresses to keep open around `current` in `lineup`: none for one
    /// allowed connection or an unknown limit, the neighbor in `direction`
    /// for two, both neighbors from three. While the user is `scanning`, the
    /// next two in `direction` instead of one each way, since the scan goes
    /// on that way. The lineup wraps at its ends; the current address and
    /// repeats are never returned.
    public static func addresses(
        around current: Int, in lineup: [URL], allowedConnections: Int?, direction: Direction = .up, scanning: Bool = false
    ) -> [URL] {
        guard lineup.indices.contains(current), let allowed = allowedConnections, allowed > 1 else { return [] }
        let count = lineup.count
        let step = direction == .up ? 1 : -1
        let ahead = { (distance: Int) in lineup[((current + step * distance) % count + count) % count] }
        let up = lineup[(current + 1) % count]
        let down = lineup[(current - 1 + count) % count]
        let wanted =
            allowed == 2
            ? [direction == .up ? up : down]
            : scanning ? [ahead(1), ahead(2)] : [up, down]
        var seen: Set<URL> = [lineup[current]]
        return wanted.filter { seen.insert($0).inserted }
    }

    /// The connection limit an Xtream account reports, nil when it gives
    /// none or not a number.
    public static func allowedConnections(xtream maxConnections: String?) -> Int? {
        maxConnections.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }.flatMap { $0 > 0 ? $0 : nil }
    }
}
