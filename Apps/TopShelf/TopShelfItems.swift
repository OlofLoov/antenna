import AntennaCore
import Foundation
import TVServices

/// The shelf the extension hands the system, built from what the app
/// wrote. It reads files only and makes no network request. Compiled into
/// the extension and into the Apple TV test bundle, since an extension
/// cannot host tests.
enum TopShelfItems {
    /// Sectioned content for the snapshot in `store` at `now`. A tile whose
    /// image is missing is dropped, a row left with no tiles is omitted, and
    /// nothing at all gives nil, a blank shelf (top-shelf capability).
    static func content(from store: any TopShelfStoring, now: Date) -> TVTopShelfSectionedContent? {
        guard let content = TopShelfContent.make(from: store.read(), now: now) else { return nil }
        let collections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>]
        switch content {
        case .sections(let sections):
            collections = sections.compactMap { section in
                let items = section.items.compactMap { item($0, in: store) }
                guard !items.isEmpty else { return nil }
                let collection = TVTopShelfItemCollection(items: items)
                collection.title = section.title
                return collection
            }
        case .empty(let empty):
            collections = item(empty, in: store).map { [TVTopShelfItemCollection(items: [$0])] } ?? []
        }
        return collections.isEmpty ? nil : TVTopShelfSectionedContent(sections: collections)
    }

    /// A 16:9 tile with its image file at 1x and 2x. A channel or title
    /// plays on select and on play; the add-favorites tile opens Antenna.
    static func item(_ item: TopShelfContent.Item, in store: any TopShelfStoring) -> TVTopShelfSectionedItem? {
        guard let image = store.tileURL(item.tileFile) else { return nil }
        let tile = TVTopShelfSectionedItem(identifier: item.id)
        tile.title = item.title
        tile.imageShape = .hdtv
        tile.setImageURL(image, for: .screenScale1x)
        tile.setImageURL(image, for: .screenScale2x)
        if let progress = item.progress { tile.playbackProgress = progress }
        let action = TVTopShelfAction(url: item.link.url)
        tile.displayAction = action
        if case .item = item.link { tile.playAction = action }
        return tile
    }
}
