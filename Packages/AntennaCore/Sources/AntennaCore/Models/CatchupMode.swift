import Foundation

/// How a provider wants catch-up asked for, from a playlist's `catchup`
/// attribute or an Xtream archive flag.
public enum CatchupMode: Hashable, Sendable {
    /// `catchup="default"`: the `catchup-source` template is the whole address.
    case `default`
    /// `catchup="append"`: the template is added to the stream address.
    case append
    /// `catchup="shift"`: `?utc=…&lutc=…` is added to the stream address.
    case shift
    /// `catchup="flussonic"` or `"fs"`: the start and length go into the path.
    case flussonic
    /// `catchup="xc"`, and Xtream channels with an archive: `/timeshift/…`.
    case xc
    /// `vod` and anything else. No address is built for it.
    case unsupported(String)

    /// Nil for an empty value and for "0", which turn catch-up off.
    public init?(attribute: String) {
        let value = attribute.trimmingCharacters(in: .whitespaces).lowercased()
        switch value {
        case "", "0": return nil
        case "default": self = .default
        case "append": self = .append
        case "shift": self = .shift
        case "flussonic", "fs": self = .flussonic
        case "xc": self = .xc
        default: self = .unsupported(value)
        }
    }
}
