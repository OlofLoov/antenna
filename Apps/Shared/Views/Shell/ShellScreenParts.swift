#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// What the overlay's catalogue is built from; it is rebuilt when either changes.
    struct CatalogueInputs: Equatable {
        let channels: [Channel]
        let favorites: [PersistentIdentifier]
        let profile: UUID
    }
#endif
