import AntennaCore
import Foundation

/// An open title page and where it was opened from, so going back can put
/// focus or the scroll position on the starting point
/// (title-detail-and-episode-picker/back-to-where-you-were).
struct TitleRoute: Equatable {
    enum Origin: Equatable {
        /// The banner's More info button.
        case banner
        /// A poster, or the More info item in its menu, in the row or grid
        /// named by its identifier part.
        case poster(row: String)
        /// A search result; the page shows over Search, not the section.
        case search
    }

    var title: ShelfTitle
    /// The section the page shows over.
    var section: ShelfTitle.Kind
    var origin: Origin
    /// The page's details and episodes, new each time a page opens.
    let model: TitleModel

    static func == (lhs: TitleRoute, rhs: TitleRoute) -> Bool {
        lhs.title == rhs.title && lhs.section == rhs.section && lhs.origin == rhs.origin && lhs.model === rhs.model
    }
}
