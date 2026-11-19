import Foundation

/// A group the catalogue lists. The UI supplies the labels for
/// `.favorites`, `.recents`, `.new`, `.all` and `.ungrouped`; `.named` carries the provider's name, and
/// `.own` takes its name from the catalogue's group rules.
public enum CatalogueGroup: Hashable, Sendable {
    /// The resolved favorites, one row per channel.
    case favorites
    /// The channels watched lately on this device, newest first.
    case recents
    /// The channels this device first saw in the last seven days, newest
    /// first (new-channels).
    case new
    /// Every channel of every source.
    case all
    /// A source's channels whose group is this provider name.
    case named(UUID, String)
    /// A source's channels with no group, or an empty or whitespace-only one.
    case ungrouped(UUID)
    /// A group the user made from channels of any source, by its id.
    case own(UUID)
}

extension CatalogueGroup {
    /// The name the group column, the chips and the list heading show. A
    /// built-in group's name comes from the catalog each time it is shown,
    /// so nothing stores it and a language change renames it
    /// (localization/built-in-names-follow-the-language). A provider group
    /// keeps its own name.
    public func label(_ locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return switch self {
        case .favorites: words("Favorites")
        case .recents: words("Recents")
        case .new: words("New")
        case .all: words("All channels")
        case .named(_, let name): name
        case .ungrouped: words("Ungrouped")
        case .own: words("Group")
        }
    }
}
