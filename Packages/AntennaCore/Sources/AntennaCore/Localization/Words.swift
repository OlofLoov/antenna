import Foundation

/// Resolves AntennaCore's own catalog entries in one language. Every text
/// helper builds its sentences through this, so a sentence is one entry
/// with its arguments and the caller's locale picks the table.
///
/// An `Int` argument becomes `%lld`, formatted with the locale's digits and
/// grouping, and picks the entry's plural form. Text from a source (a
/// channel name, a programme title) goes in through `source(_:)`.
struct Words: Sendable {
    let locale: Locale

    init(_ locale: Locale) {
        self.locale = locale
    }

    /// The entry for `value` in this locale's language, or the English
    /// text when the language has none.
    func callAsFunction(_ value: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(value, locale: locale, bundle: Self.bundle))
    }

    /// Core's catalog, for the few entries built with an explicit key where
    /// two meanings share the same English.
    static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    /// Wraps text from a source in first-strong isolates, so a Latin name
    /// inside an Arabic sentence, or an Arabic name inside an English one,
    /// keeps its own direction (localization/mixed-scripts-keep-their-own-direction).
    /// Only where directions can mix: a right-to-left language, or text
    /// with a right-to-left letter. Latin text in a left-to-right sentence
    /// stays as it is, so labels that tests and VoiceOver match keep their
    /// characters.
    func source(_ text: String) -> String {
        guard locale.language.characterDirection == .rightToLeft || text.unicodeScalars.contains(where: Self.isRightToLeft)
        else { return text }
        return "\u{2068}\(text)\u{2069}"
    }

    /// A line joined in code from parts, as in "104 Sport One · 20:00 – 22:00
    /// · Next: Match of the Day". Each part is a catalog sentence, a time, or
    /// source text passed through `source(_:)`. In a right-to-left language
    /// the line starts with a right-to-left mark, so it reads from the right
    /// even when its first part is a Latin name
    /// (localization/mixed-scripts-keep-their-own-direction).
    func line(_ parts: [String]) -> String {
        let joined = parts.joinedAsDetail(locale)
        return locale.language.characterDirection == .rightToLeft ? "\u{200F}\(joined)" : joined
    }

    /// Hebrew, Arabic, Syriac, Thaana, N'Ko and the Arabic presentation forms.
    private static func isRightToLeft(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF, 0x1_0800...0x1_0FFF, 0x1_E800...0x1_EFFF: true
        default: false
        }
    }
}

extension String {
    /// The text without the first-strong isolates `Words` puts around
    /// source text, for code that compares or measures it.
    public var withoutIsolates: String {
        replacing("\u{2068}", with: "").replacing("\u{2069}", with: "")
    }
}

/// The mark between the parts of a detail line ("412 channels · Guide 7
/// days"): " · ", and " • " in Arabic, where a middle dot beside
/// Arabic-Indic digits reads as the digit zero.
public enum DetailSeparator {
    public static func text(_ locale: Locale = .autoupdatingCurrent) -> String {
        String(localized: LocalizedStringResource("separator.detail", defaultValue: " · ", locale: locale, bundle: Words.bundle))
    }
}

extension Sequence<String> {
    /// The parts joined with the language's `DetailSeparator`.
    public func joinedAsDetail(_ locale: Locale = .autoupdatingCurrent) -> String {
        joined(separator: DetailSeparator.text(locale))
    }
}
