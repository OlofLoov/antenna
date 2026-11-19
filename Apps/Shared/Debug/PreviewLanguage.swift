import SwiftUI

/// A language a preview renders in, whatever the machine's language is.
/// German checks that the longest copy fits; Arabic checks the mirrored layout.
enum PreviewLanguage {
    case german
    case arabic

    var locale: Locale {
        switch self {
        case .german: Locale(identifier: "de_DE")
        case .arabic: Locale(identifier: "ar_SA")
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .german: .leftToRight
        case .arabic: .rightToLeft
        }
    }
}

extension View {
    /// Sets the locale and the reading direction for a preview. Text that
    /// Core builds takes the same locale through `@Environment(\.locale)`.
    func previewLanguage(_ language: PreviewLanguage) -> some View {
        environment(\.locale, language.locale).environment(\.layoutDirection, language.layoutDirection)
    }
}
