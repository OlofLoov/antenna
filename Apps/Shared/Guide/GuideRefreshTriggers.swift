import SwiftData
import SwiftUI

/// The guide downloads every window root starts (spec 0014): stale guides
/// refresh at launch and on each return to the foreground, and a source
/// deleted here or through iCloud loses its guide.
struct GuideRefreshTriggers: ViewModifier {
    @Environment(\.guideStore) private var guideStore
    @Environment(\.scenePhase) private var scenePhase
    @Query private var sources: [SourceRecord]

    func body(content: Content) -> some View {
        content
            // On iPad and Mac each window runs this; both calls are idempotent.
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active, let guideStore else { return }
                Task { await guideStore.refreshIfStale(now: .now) }
            }
            .onChange(of: Set(sources.map(\.id)), initial: true) { _, ids in
                guard let guideStore else { return }
                Task { await guideStore.sourcesChanged(to: ids) }
            }
    }
}

extension View {
    func guideRefreshTriggers() -> some View {
        modifier(GuideRefreshTriggers())
    }
}
