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
    /// (movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv).
    func shelfFocusRow(_ identifier: String) -> some View {
        #if os(tvOS)
            modifier(ShelfRowReport(identifier: identifier))
                .id(ShelfRowAnchor.id(identifier))
                .focusedValue(\.shelfFocusedRow, identifier)
        #else
            self
        #endif
    }

    /// On Apple TV, tells the screen when the highlight is on this title
    /// and gives VoiceOver its plot as a hint once the details are known.
    func shelfPreviewFocus(_ title: ShelfTitle) -> some View {
        #if os(tvOS)
            modifier(ShelfPreviewFocus(title: title))
        #else
            self
        #endif
    }
}

enum ShelfRowAnchor {
    /// The scroll id of a row.
    static func id(_ identifier: String) -> String {
        "row.\(identifier)"
    }
}

/// Each row's height, written as rows lay out. Not observed, so a row
/// growing never redraws the screen.
@MainActor
final class ShelfRowHeights {
    var heights: [String: CGFloat] = [:]
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
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: { height in
                    rows?.heights[identifier] = height
                }
        }
    }

    private struct ShelfPreviewFocus: ViewModifier {
        let title: ShelfTitle
        @Environment(ShelfLibrary.self) private var library

        func body(content: Content) -> some View {
            let plot = library.model(title.kind).details[title.id]?.plot ?? ""
            content
                .focusedValue(\.shelfFocusedTitle, title)
                .accessibilityHint(plot)
        }
    }
#endif
