import AntennaCore
import SwiftData
import SwiftUI

/// Feeds the Movies and Series library from the store and the system: the
/// sources, and returns to the foreground. Applied once at the window root,
/// above every layout.
struct ShelfSync: ViewModifier {
    let library: ShelfLibrary
    @Query(sort: SourceRecord.displayOrder) private var records: [SourceRecord]
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environment(library)
            .environment(\.posterLoader, ShelfView.PosterLoader { await PosterCache.shared.poster(for: $0) })
            .task(id: records.compactMap(\.descriptor)) {
                library.sourcesChanged(records.compactMap(\.descriptor))
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { library.becameActive() }
            }
    }
}

extension ShelfLibrary {
    /// The library for the app: scripted in a Debug build launched for UI
    /// tests, otherwise reading through `loader`'s session and Keychain.
    static func app(_ loader: SourceLoader) -> ShelfLibrary {
        #if DEBUG
            if let scripted = UITestingShelf.library() { return scripted }
        #endif
        return .live(ShelfLoader(session: loader.session, credentials: loader.credentials))
    }
}
