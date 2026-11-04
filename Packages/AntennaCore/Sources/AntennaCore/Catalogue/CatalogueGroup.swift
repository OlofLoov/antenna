import Foundation

/// A group the catalogue lists. The UI supplies the labels for
/// `.favorites`, `.all` and `.ungrouped`; `.named` carries the provider's name.
public enum CatalogueGroup: Hashable, Sendable {
    /// The resolved favorites, one row per channel.
    case favorites
    /// Every channel of every source.
    case all
    /// A source's channels whose group is this provider name.
    case named(UUID, String)
    /// A source's channels with no group, or an empty or whitespace-only one.
    case ungrouped(UUID)
}
