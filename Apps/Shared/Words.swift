import Foundation

/// Resolves the app's own catalog entries in one language, for app code
/// that needs a `String` rather than a `Text`: sentences a model builds,
/// VoiceOver labels, text that is matched or measured. Views hand a
/// `LocalizedStringResource` to `Text` instead, which follows the
/// environment's locale on its own.
///
/// Pass the view's `@Environment(\.locale)`, so a preview or a per-app
/// language picks the table. Tests pass `Locale(identifier: "en_US")`.
struct Words: Sendable {
    let locale: Locale

    init(_ locale: Locale) {
        self.locale = locale
    }

    /// The entry for `resource` in this locale's language, falling back to
    /// the English key when the language has no translation.
    func callAsFunction(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}

extension LocalizedStringResource {
    /// Text that is already final, such as a channel name or a sentence
    /// AntennaCore built, handed to a parameter that also takes app copy.
    /// It resolves to `text` unchanged in every language.
    static func verbatim(_ text: String) -> LocalizedStringResource {
        "\(text)"
    }
}
