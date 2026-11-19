import SwiftUI

/// A language a preview renders in, whatever the machine's language is.
/// German checks that the longest copy fits; Arabic checks the mirrored layout.
enum PreviewLanguage {
    case german
    case arabic

    /// A clock time on a fixed day in UTC, written the way the app writes a
    /// programme's start and end (`time: .shortened`), so an Arabic preview
    /// shows the 12-hour "٩:٣٤ م" that `ar_SA` formats.
    func time(_ hour: Int, _ minute: Int = 0) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: .gmt)
        return Date(timeIntervalSince1970: TimeInterval(hour * 3_600 + minute * 60)).formatted(style)
    }

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
