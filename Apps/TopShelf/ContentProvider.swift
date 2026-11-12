import AntennaCore
import Foundation
import TVServices

/// Antenna's Top Shelf: favorites with what is on now and Continue
/// watching, read from the App Group folder the app writes.
final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        completionHandler(TopShelfFolder.shared().flatMap { TopShelfItems.content(from: $0, now: .now) })
    }
}
