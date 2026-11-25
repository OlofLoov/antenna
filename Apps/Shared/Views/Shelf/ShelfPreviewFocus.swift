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

#if os(tvOS)
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
