#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI
    import TVServices
    import UIKit

    extension TopShelfInputs {
        /// The current profile's favorites from `catalogue`, which the shell
        /// builds for that profile, and its Continue watching
        /// (top-shelf/the-shelf-shows-the-current-profile).
        static func gather(
            catalogue: Catalogue<PersistentIdentifier>, sources: [ShellSource], continueWatching: [ContinueWatching.Item],
            episodes: [String: [Episode]]
        ) -> TopShelfInputs {
            let favorites = catalogue.rows(in: .favorites).compactMap(catalogue.channel(for:))
            let waiting = Set(sources.filter { !$0.state.isLoadedWithChannels }.map(\.id))
            let unresolved = catalogue.unresolvedFavorites.filter { $0.sourceID.map(waiting.contains) ?? false }.count
            let titles = continueWatching.map { item in
                let episode = episodes[item.title.id]?.first { $0.id == item.progress.titleID }
                return TopShelfSnapshot.TitleInput(item: item, detail: episode.flatMap(ShelfText.episodeCode))
            }
            return TopShelfInputs(
                favorites: favorites, unresolvedFavorites: unresolved, titles: titles, loading: sources.contains { $0.state == .loading })
        }

        /// Changes when anything the shelf shows changes: favorites, their
        /// sources loading, progress, or the guide.
        struct Key: Hashable {
            var favorites: [String]
            var unresolved: Int
            var titles: [String]
            var loading: Bool
            var guide: [Double]
        }

        func key(guide: GuideIndex?) -> Key {
            Key(
                favorites: favorites.compactMap { TopShelfItemID.channel($0)?.uuidString },
                unresolved: unresolvedFavorites,
                titles: titles.map { "\($0.item.progress.id)|\($0.item.progress.updatedAt.timeIntervalSince1970)|\($0.detail ?? "")" },
                loading: loading,
                guide: [
                    Double(guide?.programmeCount ?? 0), Double(guide?.settledSourceCount ?? 0),
                    guide?.horizon?.end.timeIntervalSince1970 ?? 0,
                ])
        }
    }

    /// Keeps the Top Shelf in step with the shell: every change to what it
    /// shows starts a batched write, leaving the app writes at once, and the
    /// guide is written again every six hours while the app is open
    /// (top-shelf/the-shelf-keeps-up-with-the-app).
    struct TopShelfSync: ViewModifier {
        let model: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfLibrary.self) private var library
        @Environment(\.guideStore) private var guideStore
        @Environment(\.scenePhase) private var scenePhase
        @State private var writer: TopShelfWriter?

        private var inputs: TopShelfInputs {
            .gather(
                catalogue: catalogue, sources: model.sources, continueWatching: activity.continueWatching(library),
                episodes: library.series.episodes)
        }

        func body(content: Content) -> some View {
            content
                .onChange(of: inputs.key(guide: guideStore?.index), initial: true) {
                    writer(guideStore).update(inputs)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .background, let writer else { return }
                    let task = UIApplication.shared.beginBackgroundTask(withName: "Top Shelf")
                    Task {
                        await writer.flush()
                        UIApplication.shared.endBackgroundTask(task)
                    }
                }
                .task { await writer(guideStore).refreshPeriodically() }
        }

        private func writer(_ guide: AppGuideStore?) -> TopShelfWriter {
            if let writer { return writer }
            let made = TopShelfWriter(.app(guide: guide))
            writer = made
            return made
        }
    }

    /// Clears the shelf summary while the app is locked, so the shelf shows
    /// only the add-favorites tile, which opens the paywall
    /// (top-shelf/an-empty-shelf-says-how-to-fill-it).
    struct TopShelfLock: ViewModifier {
        let entitlement: Entitlement

        func body(content: Content) -> some View {
            content.onChange(of: entitlement.lapse != nil, initial: true) { _, locked in
                guard locked else { return }
                Task {
                    await TopShelfWriter.clear(TopShelfFolder.shared(), now: .now) { TVTopShelfContentProvider.topShelfContentDidChange() }
                }
            }
        }
    }
#endif
