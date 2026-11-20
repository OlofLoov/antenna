import Foundation

extension Locale {
    /// The language most text tests expect. Tests pass it, or the locale
    /// they test, so the suite reads the same on a Mac set to any language.
    static let english = Locale(identifier: "en_US")
}
