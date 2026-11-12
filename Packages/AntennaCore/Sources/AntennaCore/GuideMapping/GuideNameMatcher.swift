import Foundation

/// Matches channels the playlist gives no guide id to guide entries with the
/// same name (guide-sources-and-channel-mapping/channels-matched-by-name).
///
/// Names are folded as Search folds them (case and accents ignored), split
/// into words at anything that is not a letter, a digit or "+", and quality
/// marks such as "HD" are dropped. A match needs every word equal, in order,
/// and exactly one entry id with those words across the guides given.
public enum GuideNameMatcher {
    /// Words that say how a channel is sent, not which channel it is.
    public static let qualityMarks: Set<String> = ["hd", "fhd", "uhd", "sd", "4k", "hevc", "h265", "1080p", "720p", "50fps", "60fps"]

    /// The words a name is compared by; empty when nothing is left.
    public static func words(_ name: String) -> [String] {
        ChannelFilter.fold(name)
            .split { !($0.isLetter || $0.isNumber || $0 == "+") }
            .map(String.init)
            .filter { !qualityMarks.contains($0) }
    }

    /// Per channel id, the entry id matched by name. Only channels without a
    /// guide id of their own and not in `excluding` qualify, and only entries
    /// with at least one programme in one of `guides`.
    static func matches(channels: [Channel], guides: [SourceGuide], excluding: Set<String>) -> [String: String] {
        guard !guides.isEmpty else { return [:] }
        let wanted = channels.filter { GuideKey(channel: $0) == nil && !excluding.contains($0.id) }
        guard !wanted.isEmpty else { return [:] }
        var entries: [[String]: Set<String>] = [:]
        for guide in guides {
            for (id, name) in guide.names where guide.schedules[id]?.isEmpty == false {
                let key = words(name)
                guard !key.isEmpty else { continue }
                entries[key, default: []].insert(id)
            }
        }
        var result: [String: String] = [:]
        for channel in wanted {
            let key = words(channel.name)
            guard !key.isEmpty, let ids = entries[key], ids.count == 1, let id = ids.first else { continue }
            result[channel.id] = id
        }
        return result
    }
}
