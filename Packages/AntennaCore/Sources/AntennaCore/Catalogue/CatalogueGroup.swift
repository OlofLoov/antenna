import Foundation

/// A group the catalogue lists. The UI supplies the labels for
/// `.favorites`, `.recents`, `.all` and `.ungrouped`; `.named` carries the provider's name, and
/// `.own` takes its name from the catalogue's group rules.
public enum CatalogueGroup: Hashable, Sendable {
    /// The resolved favorites, one row per channel.
    case favorites
    /// The channels watched lately on this device, newest first.
    case recents
    /// Every channel of every source.
    case all
    /// A source's channels whose group is this provider name.
    case named(UUID, String)
    /// A source's channels with no group, or an empty or whitespace-only one.
    case ungrouped(UUID)
    /// A group the user made from channels of any source, by its id.
    case own(UUID)
}
