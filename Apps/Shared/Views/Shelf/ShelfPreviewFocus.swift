import AntennaCore
import SwiftUI

extension FocusedValues {
    /// The row the Apple TV highlight is in: a row identifier, or `genres`.
    @Entry var shelfFocusedRow: String?
    /// The title under the Apple TV highlight in a row.
    @Entry var shelfFocusedTitle: ShelfTitle?
}

extension View {
    /// On Apple TV, gives a row an id and a height to scroll by, and tells
    /// the screen when the highlight is in it
    /// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
    /// On every platform, loads the start of the next row ahead.
    func shelfFocusRow(_ identifier: String) -> some View {
        #if os(tvOS)
            modifier(ShelfRowReport(identifier: identifier))
                .modifier(ShelfRowColumn(identifier: identifier))
                .id(ShelfRowAnchor.id(identifier))
                .focusedValue(\.shelfFocusedRow, identifier)
                .prefetchesTheNextRow(identifier)
        #else
            prefetchesTheNextRow(identifier)
        #endif
    }

    /// On Apple TV, tells the screen when the highlight is on this title
    /// and gives VoiceOver its plot as a hint once the details are known.
    /// On every platform, loads the next posters in its row ahead.
    func shelfPreviewFocus(_ title: ShelfTitle) -> some View {
        #if os(tvOS)
            modifier(ShelfPreviewFocus(title: title))
                .prefetchesAlongTheRow(title)
        #else
            prefetchesAlongTheRow(title)
        #endif
    }
}

enum ShelfRowAnchor {
    /// The scroll id of a row.
    static func id(_ identifier: String) -> String {
        "row.\(identifier)"
    }
}

/// Each row's height and top on screen, written as rows lay out and
/// scroll. Not observed, so a row moving never redraws the screen.
@MainActor
final class ShelfRowHeights {
    var heights: [String: CGFloat] = [:]
    var tops: [String: CGFloat] = [:]
}

extension EnvironmentValues {
    /// Set by the Apple TV Movies and Series screen around its rows.
    @Entry var shelfRowHeights: ShelfRowHeights?
}

/// The Apple TV highlight's position in its row, written by
/// `ShelfTVFocusFollower` as it moves. Each row reads it to say which of
/// its posters takes the highlight when a move up or down enters the row
/// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
@MainActor @Observable
final class ShelfColumnState {
    var column: Int?
}

extension EnvironmentValues {
    /// Set by the Apple TV Movies and Series screen around its rows.
    @Entry var shelfColumn: ShelfColumnState?
    /// The focus of the row a poster is in, set by the row on Apple TV.
    @Entry var shelfRowFocus: FocusState<String?>.Binding?
}

#if os(tvOS)
    /// Makes a row a focus section whose default, when a move up or down
    /// enters it, is the poster at the highlight's column, or the row's
    /// last when it is shorter. The focus engine alone picks the poster
    /// under the middle of the expanded card, one to the right
    /// (`ShelfColumn`). Only this modifier's body reads the column, so a
    /// move along a row redraws no poster.
    private struct ShelfRowColumn: ViewModifier {
        let identifier: String
        @Environment(\.shelfColumn) private var column
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @Environment(\.shelfPrefix) private var prefix
        @FocusState private var focus: String?

        func body(content: Content) -> some View {
            content
                .focusSection()
                .defaultFocus($focus, target, priority: .userInitiated)
                .environment(\.shelfRowFocus, $focus)
        }

        /// The id of the poster at the column in this row.
        private var target: String? {
            guard let column = column?.column else { return nil }
            let model = library.model(prefix == ShelfTitle.Kind.series.prefix ? .series : .movie)
            let titles: [ShelfTitle]
            switch identifier {
            case "continueWatching": return nil
            case "myList": titles = activity.myList(model)
            case "recentlyWatched": titles = activity.recentlyWatched(model)
            default:
                guard let row = model.rows.first(where: { $0.identifier == identifier }) else { return nil }
                titles = row.titles
            }
            return ShelfColumn.landing(column: column, count: titles.count).map { titles[$0].id }
        }
    }

    /// Ties a poster to its row's focus, so the row can name it as the one
    /// a move up or down lands on (`ShelfRowColumn`).
    struct InRowFocus: ViewModifier {
        let focus: FocusState<String?>.Binding?
        let id: String

        func body(content: Content) -> some View {
            if let focus {
                content.focused(focus, equals: id)
            } else {
                content
            }
        }
    }

    private struct ShelfRowReport: ViewModifier {
        let identifier: String
        @Environment(\.shelfRowHeights) private var rows

        func body(content: Content) -> some View {
            content
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .global)
                } action: { frame in
                    rows?.heights[identifier] = frame.height
                    rows?.tops[identifier] = frame.minY
                }
        }
    }

    private struct ShelfPreviewFocus: ViewModifier {
        let title: ShelfTitle
        @Environment(ShelfLibrary.self) private var library

        func body(content: Content) -> some View {
            // Only this title's hint, so an answer for another title does
            // not redraw this poster (movies-and-series-browsing/browsing-stays-responsive).
            let plot = library.model(title.kind).hints.value(title.id) ?? ""
            content
                .focusedValue(\.shelfFocusedTitle, title)
                .accessibilityHint(plot)
        }
    }
#endif
